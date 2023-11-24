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
#include once "shuffleplay.bas"
#cmdline "app.rc"

' setup playback
Mix_OpenAudio(44100,MIX_DEFAULT_FORMAT,2,4096)
dim music           as Mix_Music ptr
dim filename        as string = "test.mp3"
dim fileext         as string = ""
Dim secondsPosition As Double
dim tracklength     as double
Dim musicstate      As boolean
Dim currentvolume   as integer
dim sourcevolume    as integer = 128
dim drcvolume       as single  = 0
dim drc             as string  = "true"

' setup parsing pls and m3u
dim chkcontenttype  as boolean = false
dim itemnr          as integer = 1
dim listitem        as string
dim maxitems        as integer
dim listduration    as integer
dim lengthm3u       as integer
common shared currentitem as integer

' setup list of soundfiles
dim itemlist    as string = appname
dim imagefolder as string
dim filetypes   as string = ".flac, .mp3, .m4a, .mp4, .ogg, .wav" 
' options shuffle, linear
dim playtype    as string = "linear"

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
        if instr(1, itm, "=") > 1 then
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

' parse commandline for options overides conf.ini settings
select case command(1)
    case "/?", "-man", ""
        displayhelp(locale)
        ' cleanup listplay files
        delfile(exepath + "\" + "music" + ".tmp")
        delfile(exepath + "\" + "music" + ".lst")
        delfile(exepath + "\" + "music" + ".swp")
        logentry("terminate", "normal termination " + appname)
end select

' get media
imagefolder = command(1)
if imagefolder = "" then
    imagefolder = exepath
end if
if instr(command(1), ".") <> 0 then
    fileext = lcase(mid(command(1), instrrev(command(1), ".")))
    if instr(1, filetypes, fileext) = 0 and instr(1, ".m3u, .pls", fileext) = 0 then
        logentry("fatal", command(1) + " file type not supported")
    end if
    if FileExists(exepath + "\" + command(1)) = false then
        if FileExists(imagefolder) then
            'nop
        else
            logentry("fatal", imagefolder + " does not excist or is incorrect")
        end if
    else
        imagefolder = exepath + "\" + command(1)
    end if
else
    if checkpath(imagefolder) = false then
        logentry("fatal", imagefolder + " does not excist or is incorrect")
    end if
end if
if instr(command(1), ".m3u") = 0 and instr(command(1), ".pls") = 0 then
    maxitems = createlist(imagefolder, filetypes, "music")
    filename = listplay(playtype, "music")
end if

if instr(command(1), ".") <> 0 and instr(command(1), ".m3u") = 0 and instr(command(1), ".pls") = 0 then
    filename = imagefolder
    imagefolder = left(command(1), instrrev(command(1), "\") - 1)
    maxitems = createlist(imagefolder, filetypes, "music")
    currentsong = setcurrentlistitem("music", command(1))
end if

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

if instr(command(1), ".pls") <> 0 then
    filename = command(1)
    Open filename For input As 1
    open "music.tmp" for output as 2
    itemnr = 0
    Do Until EOF(1)
        Line Input #1, listitem
        ' ghetto parsing pls
        if instr(listitem, "=") > 0 then
            select case true
                case instr(listitem, "numberofentries") > 0
                    maxitems = val(mid(listitem, instr(listitem, "=") + 1, len(listitem)))
                case instr(listitem, "file" + str(itemnr)) > 0
                    print #2, mid(listitem, instr(listitem, "=") + 1, len(listitem))
                case instr(listitem, "title" + str(itemnr)) > 0
                case instr(listitem, "length" + str(itemnr)) > 0
                    listduration = listduration + val(mid(listitem, instr(listitem, "=") + 1, len(listitem)))
                    itemnr += 1
                case len(listitem) = 0
                    'nop
                case else
                    'msg64 = msg64 + listitem
            end select
        end if
    Loop
    close
end if

if instr(command(1), ".m3u") <> 0 then
    filename = command(1)
    Open filename For input As 1
    open "music.tmp" for output as 2
    itemnr = 0
    Do Until EOF(1)
        Line Input #1, listitem
        ' ghetto parsing m3u
        if len(listitem) > 0 then
            select case true
                case instr(listitem, "EXTINF:") > 0
                    listduration = listduration + val(mid(listitem, instr(listitem, ":") + 1, len(instr(listitem, ","))- 1))
                    itemnr += 1
                case instr(listitem, ".") > 0
                    print #2, listitem
                case len(listitem) = 0
                    'nop
                case else
                    'msg64 = msg64 + listitem
            end select
        end if
    Loop
    maxitems = itemnr
    close
end if

' listduration for recursive scan dir
if maxitems > 1 and instr(command(1), ".m3u") = 0 and instr(command(1), ".pls") = 0 then
    dim tmp as long
    dim cnt as integer = 1
    ' count items in list
    itemlist = exepath + "\music.tmp"
    tmp = readfromfile(itemlist)
    cls
    Do Until EOF(tmp)
        Locate 1, 1
        print "scanning folder for audiofiles and creating playlist..."
        Line Input #tmp, listitem
        music = Mix_LoadMUS(listitem)
        tracklength = Mix_MusicDuration(music)
        itemnr += 1
        listduration = listduration + tracklength
        print cnt
        cnt += 1
        Mix_FreeMusic(music)
    Loop
    close(tmp)
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

' init playback
dim refreshinfo     as boolean = true
dim taginfo(1 to 5) as string
dim firstmp3        as integer = 1
dim musiclevel      as single
dim maxlevel        as single
dim sleeplength     as integer = 1000

readuilabel(exepath + "\conf\" + locale + "\menu.ini")
getmp3cover(filename)
Mix_VolumeMusic(sourcevolume)
currentvolume = getvolumeosmixer() 
cls

Do
	Dim As String key = UCase(Inkey)
    sleeplength = 25

    ' ghetto attempt of dynamic range compression audio
    if drc = "true" then
        ' bass method    
        'maxlevel = min(loWORD(musiclevel), HIWORD(musiclevel)) / 32768.0f
        'drcvolume = ((1.0f + (4.75f - maxlevel)) - maxlevel) * sourcevolume
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
            Mix_FreeMusic(music)
            filename = listplay(playtype, "music")
            getmp3cover(filename)
            music = Mix_LoadMUS(filename)
            Mix_PlayMusic(music,0)
            erase taginfo 
            refreshinfo = true
            cls
        Case ","
            ' play previous mp3
            Mix_FreeMusic(music)
            filename = listplay("linearmin", "music")
            getmp3cover(filename)
            music = Mix_LoadMUS(filename)
            Mix_PlayMusic(music,0)
            erase taginfo 
            refreshinfo = true
            cls
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
    if Mix_PlayingMusic() = 0 and maxitems > 1 and firstmp3 = 0 then
        Mix_FreeMusic(music)
        filename = listplay(playtype, "music")
        getmp3cover(filename)
        music = Mix_LoadMUS(filename)
        Mix_PlayMusic(music,0)
        refreshinfo = true
        cls
    end if

    ' play with first song
    if firstmp3 = 1 then
        music = Mix_LoadMUS(filename)
        Mix_PlayMusic(music,0)
        firstmp3 = 0
        musicstate = true
    end if

    ' mp3 play time elapsed
    secondsPosition = Mix_GetMusicPosition(music)
    tracklength = Mix_MusicDuration(music)
    ' ascii interface
    Locate 1, 1
    ' basic interaction
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
    if refreshinfo = true and instr(filename, ".mp3") <> 0 then
        taginfo(1) = getmp3tag("artist",filename)
        taginfo(2) = getmp3tag("title", filename)
        taginfo(3) = getmp3tag("album", filename)
        taginfo(4) = getmp3tag("year",  filename)
        taginfo(5) = getmp3tag("genre", filename)
        refreshinfo = false
    end if    
    getuilabelvalue("artist", taginfo(1))
    getuilabelvalue("title" , taginfo(2))
    getuilabelvalue("album" , taginfo(3))
    getuilabelvalue("year"  , taginfo(4))
    getuilabelvalue("genre" , taginfo(5))
    Print
    if taginfo(1) <> "----" and taginfo(2) <> "----" then
        getuilabelvalue("current", currentsong & ". " & taginfo(1) + " - " + taginfo(2))
    else    
        getuilabelvalue("current", currentsong & ". " & mid(left(filename, len(filename) - instr(filename, "\") -1), InStrRev(filename, "\") + 1, len(filename)))
    end if
    getuilabelvalue("duration", compoundtime(tracklength) & " / " & compoundtime(CInt(secondsPosition)) & "           ")
    ' song list info
    getuilabelvalue("list", maxitems & " / " & compoundtime(listduration) & " " & playtype + "  ")
    getuilabelvalue("file", filename)
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
delfile(exepath + "\" + "music" + ".tmp")
delfile(exepath + "\" + "music" + ".lst")
delfile(exepath + "\" + "music" + ".swp")
delfile(exepath + "\thumb.jpg")
delfile(exepath + "\thumb.png")

' Free all resources allocated by SDL
Mix_FreeMusic(music)
Mix_CloseAudio()
SDL_Quit()
close
logentry("terminate", "normal termination " + appname)
