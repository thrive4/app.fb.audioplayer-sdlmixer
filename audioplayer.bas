' based on FreeBASIC-1.07.2-gcc-5.2\examples\sound\BASS\demo.bas
' compound time code https://rosettacode.org/wiki/Convert_seconds_to_compound_duration#FreeBASIC
' tweaked for fb and sdl2 jan 2023 by thrive4
' requirements
' https://github.com/libsdl-org/SDL_mixer
' sdl2.dll at https://www.libsdl.org/
' supports FLAC, MP3, Ogg, VOC, and WAV format audio
' info https://en.wikipedia.org/wiki/ID3

#include once "SDL2/SDL.bi"
#include once "SDL2/SDL_mixer.bi"
#include once "windows.bi"
#Include once "win/mmsystem.bi"
#include once "utilfile.bas"
#include once "listplay.bas"
#include once "utilaudio.bas"
#cmdline "app.rc"

' setup playback
Mix_OpenAudio(44100,MIX_DEFAULT_FORMAT,2,4096)
dim fileext         as string = ""
Dim secondsPosition As Double
dim tracklength     as double
Dim musicstate      As boolean
Dim currentvolume   as integer
dim sourcevolume    as integer = 128
dim drcvolume       as single  = 0
dim drc             as string  = "true"
dim locale          as string  = "en"
dim dummy           as string  = ""
dim shared as string filename
filename            = ""
dim shared as Mix_Music ptr music = 0

' setup parsing pls and m3u
dim chkcontenttype  as boolean = false
dim listduration    as integer

' setup list of soundfiles
dim mediafolder  as string
dim filetypes    as string = ".flac, .mp3, .m4a, .mp4, .ogg, .wav"
' options shuffle, linear
dim playtype     as string = "linear"
dim currentitem  as integer
dim maxitemslist as integer
dim listtype     as string = "music"

' init app with config file if present conf.ini
dim itm     as string
dim inikey  as string
dim inival  as string
dim inifile as string = exepath + "\conf\conf.ini"
dim f       as long
if FileExists(inifile) = false then
    logentry("error", inifile + " file does not excist")
else 
    f = readfromfile(inifile)
    Do Until EOF(f)
        Line Input #f, itm
        if instr(1, itm, "=") > 1 and Left(itm, 1) <> "'" then
            inikey = trim(mid(itm, 1, instr(1, itm, "=") - 2))
            inival = trim(mid(itm, instr(1, itm, "=") + 2, len(itm)))
            if inival <> "" then
                select case inikey
                    case "defaultvolume"
                        sourcevolume = val(inival)
                    case "locale"
                        locale = inival
                    case "usecons"
                        usecons = inival
                    case "logtype"
                        logtype = inival
                    case "mediafolder"
                        mediafolder = inival
                    case "playtype"
                        playtype = inival
                    case "drc"
                        drc = inival
                end select
            end if
            'print inikey + " - " + inival
        end if    
    loop
    close(f)    
end if    
drcvolume = sourcevolume    

' verify locale otherwise set default
select case locale
    case "en", "es", "de", "fr", "nl"
        ' nop
    case else
        logentry("error", "unsupported locale " + locale + " applying default setting")
        locale = "en"
end select
readuilabel(exepath + "\conf\" + locale + "\menu.ini")

' parse commandline
select case command(1)
    case "/?", "-h", "-help", "--help", "-man"
        displayhelp(locale)
        goto cleanup
    case "-v", "-ver"
        print appname + " version " & exeversion
        goto cleanup
end select

' get media
dummy = resolvepath(command(1))
if instr(dummy, ".m3u") = 0 and instr(dummy, ".pls") = 0 and instr(dummy, "http") = 0 then
    if instr(dummy, ".") <> 0 and instr(dummy, "..") = 0  then
        fileext = lcase(mid(dummy, instrrev(dummy, ".")))
        if instr(1, filetypes, fileext) = 0 then
            logentry("fatal", dummy + " file type not supported")
        end if
        mediafolder = left(dummy, instrrev(dummy, "\"))
        createlist(mediafolder, filetypes, listtype)
    else
        ' specific path
        if instr(dummy, "\") <> 0  then
            mediafolder = dummy
            if checkpath(mediafolder) = false then
                logentry("fatal",  "error: path not found " + mediafolder)
            else
                if createlist(mediafolder, filetypes, listtype) = 0 then
                    logentry("fatal", "error: no playable files found")
                end if
            end if
        ELSE
            ' fall back to path mediafolder specified in conf.ini
            if checkpath(mediafolder) = false then
                logentry("error", "error: mediafolder path " + mediafolder + " not found in conf.ini ")
                ' try scanning exe path
                mediafolder = exepath
            end if
            if createlist(mediafolder, filetypes, listtype) = 0 then
                logentry("fatal", "error: no playable files found")
            end if
        end if
    end if
end if

' check for stream in command line
if instr(dummy, "http") <> 0 then
    filename = dummy
end if

' use .m3u or .pls
if instr(dummy, ".m3u") <> 0 or instr(dummy, ".pls") <> 0 then
    if FileExists(dummy) then
        'nop
    else
        logentry("fatal", dummy + " file does not excist or possibly use full path to file")
    end if
    listnr = getmp3playlist(dummy, listtype)
    logentry("notice", "parsing and playing playlist " + filename)
end if

' search with query and export .m3u 
if instr(dummy, ":") <> 0 and len(command(2)) <> 0  then
    select case command(2)
        case "artist"
        case "title"
        case "album"
        case "year"
        case "genre"
        case else
            logentry("fatal", "unknown tag '" & command(2) & "' valid tags artist, title, album, genre and year")
    end select
    ' scan and search nr results overwritten by getmp3playlist
    listnr = exportm3u(dummy, "*.mp3", "m3u", "exif", command(2), command(3))
    if listnr < 2 then
        logentry("fatal", "no matches found for " + command(3) + " in " + command(2))
    else
        listnr = getmp3playlist(exepath + "\" + command(3) + ".m3u", listtype)
    end if
end if
dummy = ""

initsdl:
' init audio
' note normaly init video is used but sdl blocks display timeout via powerplan of the os
' to respond to power plan settings for blank display on windows set hint before sdl init video
' use SDL_SetHint(SDL_HINT_VIDEO_ALLOW_SCREENSAVER, "1")
If (SDL_Init(SDL_INIT_AUDIO) = not NULL) Then
    logentry("error", "sdl2 audio could not be initlized error: " + *SDL_GetError())
    SDL_Quit()
else
    ' render scale quality: 0 point, 1 linear, 2 anisotropic
    'SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "1")
    ' note this still blocks the screen blank dictated by os power plan
    'SDL_SetHint(SDL_HINT_VIDEO_ALLOW_SCREENSAVER, "1")
End If

' compound seconds to hours, minutes, etc 
function compoundtime(m As Long) as string
    dim dummy as string
    Dim As Long c(1 To 5)={604800,86400,3600,60,1}
    Dim As String g(1 To 5)={" Wk "," d "," hr "," min "," sec"},comma
    Dim As Long b(1 To 5),flag,m2=m
    Redim As Long s(0)
    For n As Long=1 To 5
        If m>=c(n) Then
            Do
                Redim Preserve s(Ubound(s)+1)
                s(Ubound(s))=c(n)
                m=m-c(n)
            Loop Until m<c(n)
        End If
    Next n 
    For n As Long=1 To Ubound(s)
        For m As Long=1 To 5
            If s(n)=c(m) Then b(m)+=1
        Next m
    Next n
    'Print m2;" seconds = ";
    For n As Long=1 To 5
        If b(n) Then: comma=Iif(n<5 Andalso b(n+1),","," and"):flag+=1 
        If flag=1 Then comma=""
            'Print comma;b(n);g(n);
            dummy = dummy + str(b(n)) + str(g(n))
        End If
    Next
    return dummy
End function

' listduration for recursive scan dir
if listnr > 1 then
    'Dim scanhandle As HSTREAM
    cls
    getuilabelvalue("listcalc")
    ' count items in list and tally duration songs
    for i as integer = 0 to listnr
        with listrec
            if listrec.listtype(i) = listtype then
                music = Mix_LoadMUS(listrec.listfile(i))
                'scanhandle      = BASS_StreamCreateFile(0, StrPtr(listrec.listfile(i)), 0, 0, BASS_STREAM_DECODE)
                ' length in bytes
                'chanlengthbytes = BASS_ChannelGetLength(scanhandle, BASS_POS_BYTE)
                ' convert bytes to seconds
                'tracklength     = BASS_ChannelBytes2Seconds(scanhandle, chanlengthbytes)
                tracklength = Mix_MusicDuration(music)
                listduration    = listduration + tracklength
                'BASS_StreamFree(scanhandle)
                Mix_FreeMusic(music)
                locate 1,30
                print i;
            end if
        end with
    next i
end if

' set os fader volume app channel
function setvolumeosmixer(volume as ulong) as boolean

    Dim hMixer      As HMIXER
    Dim mxlc        As MIXERLINECONTROLS
    Dim mxcd        As MIXERCONTROLDETAILS
    Dim mxcd_vol    As MIXERCONTROLDETAILS_UNSIGNED
    Dim mxl         As MIXERLINE
    Dim mxlc_vol    As MIXERCONTROL

    ' Open the mixer
    mixerOpen(@hMixer, 0, 0, 0, 0)

    '  get volume control for app channel
    mxlc.cbStruct       = SizeOf(MIXERLINECONTROLS)
    mxlc.dwControlType  = MIXERCONTROL_CONTROLTYPE_VOLUME
    mxlc.cControls      = 1
    mxlc.cbmxctrl       = SizeOf(MIXERCONTROL)
    mxlc.pamxctrl       = @mxlc_vol
    mixerGetLineControls(hMixer, @mxlc, MIXER_GETLINECONTROLSF_ONEBYTYPE)

    ' get fader volume app channel
    mxcd.cbStruct = SizeOf(MIXERCONTROLDETAILS)
    mxcd.dwControlID    = mxlc_vol.dwControlID
    mxcd.cChannels      = 1
    mxcd.cMultipleItems = 0
    mxcd.cbDetails      = SizeOf(MIXERCONTROLDETAILS_UNSIGNED)
    mxcd.paDetails      = @mxcd_vol
    mixerGetControlDetails(hMixer, @mxcd, MIXER_GETCONTROLDETAILSF_VALUE)

    ' set fader volume app channel
    mxcd_vol.dwValue = volume
    mxcd.hwndOwner = 0
    mixerSetControlDetails(hMixer, @mxcd, MIXER_SETCONTROLDETAILSF_VALUE)

    ' close the mixer
    mixerClose(hMixer)
    return true

end function

' get os fader volume app channel
function getvolumeosmixer() as ulong

    Dim hMixer      As HMIXER
    Dim mxlc        As MIXERLINECONTROLS
    Dim mxcd        As MIXERCONTROLDETAILS
    Dim mxcd_vol    As MIXERCONTROLDETAILS_UNSIGNED
    Dim mxl         As MIXERLINE
    Dim mxlc_vol    As MIXERCONTROL

    ' Open the mixer
    mixerOpen(@hMixer, 0, 0, 0, 0)

    '  get volume control for app channel
    mxlc.cbStruct       = SizeOf(MIXERLINECONTROLS)
    mxlc.dwControlType  = MIXERCONTROL_CONTROLTYPE_VOLUME
    mxlc.cControls      = 1
    mxlc.cbmxctrl       = SizeOf(MIXERCONTROL)
    mxlc.pamxctrl       = @mxlc_vol
    mixerGetLineControls(hMixer, @mxlc, MIXER_GETLINECONTROLSF_ONEBYTYPE)

    ' get fader volume app channel
    mxcd.cbStruct       = SizeOf(MIXERCONTROLDETAILS)
    mxcd.dwControlID    = mxlc_vol.dwControlID
    mxcd.cChannels      = 1
    mxcd.cMultipleItems = 0
    mxcd.cbDetails      = SizeOf(MIXERCONTROLDETAILS_UNSIGNED)
    mxcd.paDetails      = @mxcd_vol
    mixerGetControlDetails(hMixer, @mxcd, MIXER_GETCONTROLDETAILSF_VALUE)

    ' close the mixer
    mixerClose(hMixer)
    
    ' return volume app channel
    return mxcd_vol.dwValue

end function

' convert os fader volume app channel
' scale from 0 ~ 65535 to 0 ~ 100 (windows mixer)
function displayvolumeosmixer(volume as ulong) as integer
    volume = volume / (65535 * 0.01)
    return int(volume)
end function

function isstream(byref s as string) as integer
    dim as string u = lcase(trim(s))
    if left(u, 7) = "http://" then return  -1
    if left(u, 8) = "https://" then return -1
    return 0
end function

sub checkstream(url as string)
/'
    err = BASS_ErrorGetCode()
    select case err
        case BASS_ERROR_NONET
            logentry("error", "error: no internet connection")
        case BASS_ERROR_ILLPARAM
            logentry("error", "error: invalid url/file " + url)
        case BASS_ERROR_SSL
            logentry("error", "error: ssl/tls error with " + url)
        case BASS_ERROR_TIMEOUT
            logentry("error", "error: connection timed out on " + url)
        case BASS_ERROR_UNKNOWN
            logentry("error", "error: unknown error check " + url)
        case else
            logentry("warning", "error: unhandled error code " + url)
    end select
'/
end sub

sub playmedia(byval index as integer)
    ' clean
    if music <> 0 then
        Mix_HaltMusic()
        Mix_FreeMusic(music)
        music = 0
    end if

    dim as string entry = listrec.listfile(index)
    if isstream(entry) then
        dim as string url = entry
        if url = "" then
            url = "http://uk3.internet-radio.com:8082/live"  ' fallback
        end if
        'fx1Handle = BASS_StreamCreateURL(url, 0, 0, 0, 0)
        'if fx1Handle = 0 then
        '    checkstream(url)
            'goto cleanup
        'end if
        filename = url
    else
        filename = entry
        music = Mix_LoadMUS(filename)
        if music = 0 then
            'err = Mix_GetError()
            ' log error if you like, then exit
            exit sub
        end if
        getmp3cover(filename)
    end if

    Mix_PlayMusic(music,0)
    erase taginfo
    cls
end sub

' init playback
dim refreshinfo     as boolean = true
dim musiclevel      as single
dim maxlevel        as single
dim minlevel        as single
dim sleeplength     as long    = 1000
Mix_VolumeMusic(sourcevolume)
currentvolume = getvolumeosmixer()

' set active media item
if isstream(filename) = false then
    if instr(command(1), ".") > 0 and instr(command(1), ".m3u") = 0 and instr(command(1), ".pls") = 0 then
        currentitem = getcurrentlistitem(listtype, command(1))
    else
        currentitem = listnext(listtype, playtype, 0)
    end if
    maxitemslist = getmaxitemslist(listtype)
    setsequence(currentitem)
    if lcase(playtype) = "linear" then
        clearseq(listtype)
    end if
end if

' play first item
musicstate  = true
refreshinfo = true
music       = 0
playmedia(currentitem)

If isstream(command(1)) Then
    ' default = 5000 or 5 seconds
    'BASS_SetConfigPtr(BASS_CONFIG_NET_AGENT, @"Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:146.0) Gecko/20100101 Firefox/146.0")
    'BASS_SetConfig(BASS_CONFIG_NET_TIMEOUT, 20000)
    'BASS_SetConfig(BASS_CONFIG_NET_BUFFER,  20000)  ' Buffer more data
    'fx1Handle = BASS_StreamCreateURL(command(1), 0, 0, 0, 0)
    'If fx1Handle = 0 Then
    '    checkstream(command(1))
    '    goto cleanup
    'Else
        ' nop
    'End If
End If

Dim timerstart As Double
If isstream(command(1)) Then
    Sleep 500, 1
    'gethttpstreaminfo(fx1Handle)
    timerstart = timer
End If

cls
Do
	Dim As String key = UCase(Inkey)
    sleeplength = 25

    ' ghetto attempt of dynamic range compression audio
    if drc = "true" then
        ' bass method    
        'musiclevel      = BASS_ChannelGetLevel(fx1Handle)
        'minlevel        = min(loWORD(musiclevel), HIWORD(musiclevel)) / 32768.0f
        'maxlevel        = max(loWORD(musiclevel), HIWORD(musiclevel)) / 32768.0f
        'drcvolume       = min(1.75f + (7.0f - maxlevel), max(0.0f, (1.55f - minlevel)) * (7.0f - maxlevel))
        'drcvolume       = drcvolume * sourcevolume
        drcvolume = 128
        Mix_VolumeMusic(drcvolume)
    else
        Mix_VolumeMusic(sourcevolume)
    end if

	Select Case key
        Case Chr$(32)
            ' toggle mp3 mute status
            If musicstate Then
                Mix_PauseMusic()
                musicstate = false
            Else
                Mix_ResumeMusic()
                musicstate = true
            End If
        Case "."
            ' play next mp3
            currentitem = listnext(listtype, playtype, currentitem)
            if playtype = "shuffle" then
                setsequence(currentitem)
            end if
            playmedia(currentitem)
            refreshinfo = true
            cls
        Case ","
            ' play previous mp3
            currentitem = listprevious(listtype, playtype, currentitem)
            playmedia(currentitem)
            refreshinfo = true
        Case "]"
            ' fast foward 10 sec
            if secondsPosition < tracklength then
                Mix_SetMusicPosition(secondsPosition + 10)
            end if
            cls
        Case "["
            ' rewind 10 sec
            if secondsPosition > 20 then
                Mix_SetMusicPosition(secondsPosition - 10)
            end if
            cls
        Case "R"
            ' restart mp3
            Mix_RewindMusic()
        Case "L"
            ' change list playtype
            select case playtype
                case "linear"
                    playtype = "shuffle"
                case "shuffle"
                    playtype = "linear"
            end select
        Case "D"
            ' toggle drc
            select case drc
                case "true"
                    drc = "false"
                    drcvolume = sourcevolume
                case "false"
                    drc = "true"
            end select
        Case "-"
            ' decrease fader mixer os volume (in range 0 - 65535)
            currentvolume = currentvolume - 1000
            if currentvolume < 1001 then currentvolume = 0 end if
            setvolumeosmixer(currentvolume)
        Case "+"
            ' increase fader mixer os volume (in range 0 - 65535)
            currentvolume = currentvolume + 1000
            if currentvolume > 65535 then currentvolume = 65535 end if
            setvolumeosmixer(currentvolume)
        Case Chr(27)
            Exit Do
        case else
            ' detect volume change via os mixer
            currentvolume = getvolumeosmixer()
            sleeplength = 1000
	End Select

    ' auto play next mp3 from list if applicable
    if Mix_PlayingMusic() = 0 and maxitemslist > 1 then
        currentitem = listnext(listtype, playtype, currentitem)
        if playtype = "shuffle" then
            setsequence(currentitem)
        end if
        playmedia(currentitem)
        refreshinfo = true
    end if

    ' mp3 play time elapsed
    secondsPosition = Mix_GetMusicPosition(music)
    tracklength = Mix_MusicDuration(music)
    ' ascii interface
    Locate 1, 1
    Print "| SDL2 mixer library demonstration v" + exeversion
    print
    getuilabelvalue("next")
    getuilabelvalue("previous")
    getuilabelvalue("forward")
    getuilabelvalue("back")
    getuilabelvalue("pause")
    getuilabelvalue("restart")
    getuilabelvalue("togglelist")
    getuilabelvalue("drc")
    getuilabelvalue("volumedown")
    getuilabelvalue("volumeup")
    getuilabelvalue("quit")
    Print
    ' tag info
    if refreshinfo = true and instr(filename, ".mp3") <> 0 and isstream(filename) = false then
        getmp3baseinfo(filename)
        refreshinfo = false
    end if

    if isstream(filename) and (timer - timerstart) > 5 then
        'gethttpstreaminfo(fx1Handle)
        timerstart = timer
        refreshinfo = false
    end if

    getuilabelvalue("artist", taginfo(1))
    getuilabelvalue("title" , taginfo(2))
    getuilabelvalue("album" , taginfo(3))
    getuilabelvalue("year"  , taginfo(4))
    getuilabelvalue("genre" , taginfo(5))
    Print

    if isstream(filename) = false then
        if taginfo(1) <> "----" and taginfo(2) <> "----" then
            getuilabelvalue("current", currentitem & ". " & taginfo(1) + " - " + taginfo(2))
        else
            getuilabelvalue("current", currentitem & ". " & mid(left(filename, len(filename) - instr(filename, "\") -1), InStrRev(filename, "\") + 1, len(filename)))
        end if
    end if
    if isstream(filename) then
        getuilabelvalue("current", "internet radio - " + listrec.listname(currentitem))
    end if

    getuilabelvalue("duration", compoundtime(tracklength) & " / " & compoundtime(CInt(secondsPosition)) & "           ")
    ' song list info
    getuilabelvalue("list", maxitemslist & " / " & compoundtime(listduration) & " " & playtype + "  ")
    if isstream(filename) then
        getuilabelvalue("url",  filename)
    else
        getuilabelvalue("file", filename)
    end if
    if musicstate = false then
        getuilabelvalue("volume",  "mute  ")
    else
        getuilabelvalue("volume", format(displayvolumeosmixer(currentvolume), "###-       "))
    end if
    print using "drc:      &###-"; drcvolume;
    print " " & drc & "     "

    Sleep(sleeplength)

Loop

cleanup:
' cleanup listplay files
delfile(exepath + "\thumb.jpg")
delfile(exepath + "\thumb.png")

' Free all resources allocated by SDL
Mix_FreeMusic(music)
Mix_CloseAudio()
SDL_Quit()
close
logentry("terminate", "normal termination " + appname)
