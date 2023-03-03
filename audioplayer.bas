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
#include once "utilfile.bas"
#include once "shuffleplay.bas"
#cmdline "app.rc"

' setup playback
Mix_OpenAudio(44100,MIX_DEFAULT_FORMAT,2,4096)
dim music           as Mix_Music ptr
dim filename        as string = "test.mp3"
Dim secondsPosition As Double
dim tracklength     as double
Dim musicstate      As boolean
Dim currentvolume   as integer = 128
dim locale          as string = "en"

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
dim inifile as string = exepath + "\conf.ini"
dim f       as integer
if FileExists(inifile) = false then
    logentry("error", inifile + "file does not excist")
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
                        currentvolume = val(inival)
                    case "locale"
                        locale = inival
                    case "usecons"
                        usecons = inival
                    case "logtype"
                        logtype = inival
                    case "playtype"
                        playtype = inival
                end select
            end if
            'print inikey + " - " + inival
        end if    
    loop
    close(f)    
end if    

' get media
imagefolder = command(1)
if imagefolder = "" then
    imagefolder = exepath
end if
maxitems = createlist(imagefolder, filetypes, "music")
filename = listplay(playtype, "music")

' parse commandline for options overides conf.ini settings
select case command(1)
    case "/?", "-man", ""
        displayhelp(locale)
        ' cleanup listplay files
        delfile(exepath + "\" + "music" + ".tmp")
        delfile(exepath + "\" + "music" + ".lst")
        logentry("terminate", "normal termination " + appname)
end select
if instr(command(1), ".") <> 0 then
    filename = imagefolder    
    imagefolder = left(command(1), instrrev(command(1), "\") - 1)
    chk = createlist(imagefolder, filetypes, "music")
end if    

initsdl:
' init window and render
If (SDL_Init(SDL_INIT_VIDEO) = not NULL) Then 
    logentry("error", "sdl2 video could not be initlized error: " + *SDL_GetError())
    SDL_Quit()
else
    ' render scale quality: 0 point, 1 linear, 2 anisotropic
    SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "1")
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

' code by squall4226
' see https://www.freebasic.net/forum/viewtopic.php?p=149207&hilit=user+need+TALB+for+album#p149207
Function getmp3tag(searchtag As String, fn As String) As String
   'so we can avoid having the user need TALB for album, TIT2 for title etc, although they are accepted
   Dim As Integer skip, offset' in order to read certain things right
   Dim As UInteger sig_to_find, count, fnum, maxcheck = 100000
   dim as UShort tag_length
   Dim As UShort unitest, mp3frametest
   Dim As String tagdata

   Select Case UCase(searchtag)
        Case "HEADER", "ID3"
            searchtag = "ID3" & Chr(&h03)
        Case "TITLE", "TIT2"
            searchtag = "TIT2"
        Case "ARTIST", "TPE1"
            searchtag = "TPE1"
        Case "ALBUM", "TALB"
            searchtag = "TALB"
        Case "COMMENT", "COMM"
            searchtag = "COMM"
        Case "COPYRIGHT", "TCOP"
            searchtag = "TCOP"
        Case "COMPOSER", "TCOM"
            searchtag = "TCOM"
        Case "BEATS PER MINUTE", "BPM", "TPBM"
            searchtag = "TBPM"
        Case "PUBLISHER", "TPUB"
            searchtag = "TPUB"
        Case "URL", "WXXX"
            searchtag = "WXXX"
        Case "PLAY COUNT" "PCNT"
            searchtag = "PCNT"
        Case "GENRE", "TCON"
            searchtag = "TCON"
        Case "ENCODER", "TENC"
            searchtag = "TENC"
        Case "TRACK", "TRACK NUMBER", "TRCK"
            searchtag = "TRCK"
        Case "YEAR", "TYER"
            searchtag = "TYER"      
        'Special, in this case we will return the datasize if present, or "-1" if no art
        Case "PICTURE", "APIC"
            searchtag = "APIC"
            'Not implemented yet!
        Case Else
            'Tag may be invalid, but search anyway, there are MANY tags, and we have error checking
   End Select

   fnum = FreeFile
   Open fn For Binary Access Read As #fnum
   If Lof(fnum) < maxcheck Then maxcheck = Lof(fnum)
   For count = 0 to maxcheck Step 1
        Get #fnum, count, sig_to_find
        If sig_to_find = Cvi(searchtag) Then
             If searchtag = "ID3" & Chr(&h03) Then
                Close #fnum
                Return "1" 'Because there is no data here, we were just checking for the ID3 header
             EndIf
             'test for unicode
             Get #fnum, count+11, unitest         
             If unitest = &hFEFF Then 'unicode string
                skip = 4
                offset = 13           
             Else 'not unicode string
                skip = 0
                offset = 10            
             EndIf
             
             Get #fnum, count +7, tag_length 'XXXXYYYZZ Where XXXX is the TAG, YYY is flags or something, ZZ is size

             If tag_length-skip < 1 Then
                Close #fnum
                Return "ERROR" 'In case of bad things
             EndIf
             
             Dim As Byte dataget(1 To tag_length-skip)
             Get #fnum, count+offset, dataget()
             
             For i As Integer = 1 To tag_length - skip
                if dataget(i) < 4 then dataget(i) = 0 ' remove odd characters
                If dataget(i) <> 0 Then tagdata + = Chr(dataget(i)) 'remove null spaces from ASCII data in UNICODE string
             Next
        End If
        If tagdata <> "" then exit For ' stop searching!
   Next
   Close #fnum
   
   If Len(tagdata) = 0 Then
        'If the tag was just not found or had no data then "----"
        tagdata = "----"
   EndIf

   Return tagdata

End Function

' attempt to extract and write cover art of mp3 to temp thumb file
Function getmp3cover(filename As String) As boolean
    Dim buffer  As String
    dim chunk   as string
    dim length  as string
    dim bend    as integer
    dim ext     as string = ""
    dim thumb   as string
    ' remove old thumb if present
    delfile(exepath + "\thumb.jpg")
    delfile(exepath + "\thumb.png")
    Open filename For Binary Access Read As #1
        If LOF(1) > 0 Then
            buffer = String(LOF(1), 0)
            Get #1, , buffer
        End If
    Close #1
    if instr(1, buffer, "APIC") > 0 then
        length = mid(buffer, instr(buffer, "APIC") + 4, 4)
        ' ghetto check funky first 4 bytes signifying length image
        ' not sure how reliable this info is
        ' see comment codecaster https://stackoverflow.com/questions/47882569/id3v2-tag-issue-with-apic-in-c-net
        if val(asc(length, 1) & asc(length, 2)) = 0 then
            bend = (asc(length, 3) shl 8) or asc(length, 4)
        else
            bend = (asc(length, 1) shl 24 + asc(length, 2) shl 16 + asc(length, 3) shl 8 or asc(length, 4))
        end if
        if instr(1, buffer, "JFIF") > 0 then
            ' override end jpg if marker FFD9 is present
            if instr(buffer, CHR(&hFF, &hD9)) > 0 then
                bend = instr(1, mid(buffer, instr(1, buffer, "JFIF")), CHR(&hFF, &hD9)) + 7
            end if
            chunk = mid(buffer, instr(buffer, "JFIF") - 6, bend)
            ext = ".jpg"
        end if
        ' use ext to catch false png
        if instr(1, buffer, "‰PNG") > 0 and ext = "" then
            ' override end png if tag is present
            if instr(1, buffer, "IEND") > 0 then
                bend = instr(1, mid(buffer, instr(1, buffer, "‰PNG")), "IEND") + 7
            end if
            chunk = mid(buffer, instr(buffer, "‰PNG"), bend)
            ext = ".png"
        end if
        ' funky variant for non jfif and jpegs video encoding?
        if (instr(1, buffer, "Lavc58") > 0 or instr(1, buffer, "Exif") > 0) and ext = "" then
            ' override end jpg if marker FFD9 is present
            if instr(buffer, CHR(&hFF, &hD9)) > 0 then
                bend = instr(1, mid(buffer, instr(1, buffer, "Exif")), CHR(&hFF, &hD9)) + 7
            end if
            if instr(1, buffer, "Exif") > 0 then
                chunk = mid(buffer, instr(buffer, "Exif") - 6, bend)
            else
                chunk = mid(buffer, instr(buffer, "Lavc58") - 6, bend)
            end if
            ext = ".jpg"
        end if
        buffer = ""
        Close #1
        ' attempt to write thumbnail to temp file
        if ext <> "" then
            thumb = exepath + "\thumb" + ext
            open thumb for Binary Access Write as #1
                put #1, , chunk
            close #1
        else
            ' no cover art in mp3 optional use folder.jpg if present as thumb
        end if
        return true
    else
        ' no cover art in mp3 optional use folder.jpg if present as thumb
        logentry("notice", "no cover art found in: " + filename)
        return false
    end if
end function

if instr(command(1), ".pls") <> 0 then
    filename = command(1)
    Open filename For input As 1
    open "music.tmp" for output as 2
    Do Until EOF(1)
        Line Input #1, listitem
        ' ghetto parsing pls
        if instr(listitem, "=") > 0 then
            'listitem = mid(listitem, instr(listitem, "=") + 1, len(listitem))
            select case true
                case instr(listitem, "numberofentries") > 0
                    maxitems = val(mid(listitem, instr(listitem, "=") + 1, len(listitem)))
                    'print maxitems
                case instr(listitem, "file" + str(itemnr)) > 0
                    'print "-file-" + mid(listitem, instr(listitem, "=") + 1, len(listitem))
                    print #2, mid(listitem, instr(listitem, "=") + 1, len(listitem))
                case instr(listitem, "title" + str(itemnr)) > 0
                    'print "-title-" + mid(listitem, instr(listitem, "=") + 1, len(listitem))
                case instr(listitem, "length" + str(itemnr)) > 0
                    'print "-length-" + mid(listitem, instr(listitem, "=") + 1, len(listitem))
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
                    'print listduration
                    itemnr += 1
                case instr(listitem, ".") > 0
                    'print "-file-" + listitem
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
    print "scanning folder for audiofiles and creating playlist..."
    dim tmp as integer
    ' count items in list
    itemlist = "music.tmp"
    tmp = readfromfile(itemlist)
    Do Until EOF(tmp)
        Line Input #tmp, listitem
        music = Mix_LoadMUS(listitem)
        tracklength = Mix_MusicDuration(music)
        itemnr += 1
        listduration = listduration + tracklength
        Mix_FreeMusic(music)
    Loop
    close(tmp)
end if

' used for ascii interface
Dim currentLine     As Integer = CsrLin
' init playback
dim refreshinfo     as boolean = true
dim taginfo(1 to 5) as string
dim firstmp3        as integer = 1
getmp3cover(filename)
Mix_VolumeMusic(currentvolume)
cls

Do
	Dim As String key = UCase(Inkey)

	Select Case key
        Case "P"
            ' play mp3
            Mix_PlayMusic(music,0)
            tracklength = Mix_MusicDuration(music)
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
            tracklength = Mix_MusicDuration(music)
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
            tracklength = Mix_MusicDuration(music)
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
        Case "-"
            ' decrease mp3 volume (in range [0.0, 128.0])
            if currentvolume > 1 and currentvolume < 129 then
                currentvolume = currentvolume - 1
                Mix_VolumeMusic(currentvolume)
            end if
        Case "+"
            ' increase mp3 volume (in range [0.0, 128.0])
            if currentvolume > 0 and currentvolume < 128 then
                currentvolume = currentvolume + 1
                Mix_VolumeMusic(currentvolume)
            end if
        Case Chr(27)
            Exit Do
	End Select

    ' auto play next mp3 from list if applicable
	if Mix_PlayingMusic() = 0 and maxitems > 1 and firstmp3 = 0 then
            ' play next mp3
            Mix_FreeMusic(music)
            filename = listplay(playtype, "music")
            getmp3cover(filename)
            music = Mix_LoadMUS(filename)
            Mix_PlayMusic(music,0)
            tracklength = Mix_MusicDuration(music)
            refreshinfo = true
            cls
    end if

    ' play with first song
    if firstmp3 = 1 then
        music = Mix_LoadMUS(filename)
        Mix_PlayMusic(music,0)
        tracklength = Mix_MusicDuration(music)
        firstmp3 = 0
        musicstate = true
    end if

    ' mp3 play time elapsed
	secondsPosition = Mix_GetMusicPosition(music)

    ' ascii interface
	Locate currentLine, 1
    ' basic interaction
    Print "===== > SDL2 mixer library demonstration < ====="
    Print "press p     play"
    Print "press .     play next"
    Print "press ,     play previous"
    Print "press ]     skip forward   10 secs"
    Print "press [     skip backwards 10 secs"
    Print "press space pause / play or mute / unmute"
    Print "press r     restart"
    Print "press -     increase volume"
    Print "press +     decrease volume"
    Print "press esc   quit"
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
    print "artist: " + taginfo(1)
    print "title:  " + taginfo(2)
    print "album:  " + taginfo(3)
    print "year:   " + taginfo(4)
    print "genre:  " + taginfo(5)
    Print
    if taginfo(1) <> "----" and taginfo(2) <> "----" and instr(filename, ".mp3") <> 0 then
        print "current:  " + taginfo(1) + " - " + taginfo(2)       
    else    
        print "current:  " + mid(left(filename, len(filename) - instr(filename, "\") -1), InStrRev(filename, "\") + 1, len(filename))
    end if
    print "duration: " & compoundtime(tracklength) & " / " & compoundtime(CInt(secondsPosition)) 
    ' song list info
    print "list:     " & maxitems & " / " & compoundtime(listduration)
    print "file:     " + filename
    if musicstate = false then
        print using "volume:   mute";
    else
        print using "volume:   ### "; currentvolume
    end if
    Sleep(30)
Loop

cleanup:
' cleanup listplay files
delfile(exepath + "\" + "music" + ".tmp")
delfile(exepath + "\" + "music" + ".lst")
delfile(exepath + "\thumb.jpg")
delfile(exepath + "\thumb.png")

' cleanup libs
Mix_FreeMusic(music)
Mix_CloseAudio()
SDL_Quit()
close
logentry("terminate", "normal termination " + appname)
