' used for app launcher
#include once "crt/process.bi"

' dir function and provides constants to use for the attrib_mask parameter
#include once "vbcompat.bi"
#include once "dir.bi"

' disable filename globbing otherwise g:\* list files
' when using command how ever conflicts with dir()
' also odd this is used for 64bits but works with 32bits
' Extern _dowildcard Alias "_dowildcard" As Long
'Dim Shared _dowildcard As Long = 0

' setup log
dim shared logfile as string
dim shared logtype as string
dim shared appname as string
dim shared appfile as string
dim shared usecons as string
dim shared exeversion as string

' note command(0) can arbitraly add the path so strip it
appname = mid(command(0), instrrev(command(0), "\") + 1)
' without file extension
appname = left(appname, len(appname) - 4)
' options logtype verbose, full
logtype = "verbose"
' options usecons true, false
usecons = "false"
' generic check for true or false
dim chk as boolean

' get version exe for log
declare function getfileversion(versinfo() as string, versdesc() as string) as integer
declare function replace(byref haystack as string, byref needle as string, byref substitute as string) as string
dim as integer c, resp
dim as string versinfo(8)
dim as string versdesc(7) =>_
    {"CompanyName",_
    "FileDescription",_
    "FileVersion",_
    "InternalName",_
    "LegalCopyright",_
    "OriginalFilename",_
    "ProductName",_
    "ProductVersion"}
versinfo(8) = appname + ".exe"
resp = getfileversion(versinfo(),versdesc())
exeversion = replace(trim(versinfo(2)), ", ", ".")

' get metric os
dim shared os as string
os = "unknown"
#ifdef __FB_WIN32__
    os = "windows"
#endif
#ifdef __FB_UNIX__
    os = "unix"
#endif

' used for logging
Function logentry(entrytype As String, logmsg As String) As Boolean

    ' validate logentry
    If InStr(logmsg, "|") > 0 Then
        logmsg = "entry contained delimeter -> | <-"
    End If

    ' output to console
    if usecons = "true" then
        print time & " " + entrytype + " | " + logmsg
    end if

    ' setup logfile
    dim f as integer
    f = FreeFile
    logfile = exepath + "\" + appname + ".log"
    if FileExists(logfile) = false then
        Open logfile For output As #f
        logmsg = logfile + " created"
        print #f, format(now, "dd/mm/yyyy") + " - " + time + "|" + "notice" + "|" + appname + "|" + logmsg
        logmsg = "version " + exeversion
        print #f, format(now, "dd/mm/yyyy") + " - " + time + "|" + "notice" + "|" + appname + "|" + logmsg
        logmsg = "platform " + os
        print #f, format(now, "dd/mm/yyyy") + " - " + time + "|" + "notice" + "|" + appname + "|" + logmsg
        close #f
        exit function
    end if

    if entrytype <> "error" and entrytype <> "terminate" and logtype = "verbose" then
        exit function
    end if

    ' write to logfile
    Open logfile For append As #f
    print #f, format(now, "dd/mm/yyyy") + " - " + time + "|" + entrytype + "|" + appname + "|" + logmsg
    close #f

    ' normal termination or fatal error
    if entrytype = "terminate" then
        end
    end if

    return true
End function

' list files in folder
function getfilesfromfolder (filespec As String) as boolean
    Dim As String filename = Dir(filespec, 1)
    if len(filename) = 0 then print "path not found..." end if
    Do While Len(filename) > 0
        filename = Dir()
    Loop
    return true
end function

' list folders
function getfolders (filespec As String) as boolean
    Dim As String filename = Dir(filespec, fbDirectory)
    if len(filename) = 0 then print "path not found..." end if
    Do While Len(filename) > 0
        filename = Dir()
    Loop
    return true
end function

' create a new file
Function newfile(filename As String) As boolean
    Dim f As integer

    if FileExists(filename) then
        logentry("warning", "creating " + filename + " file excists")
        return false
    end if    

    f = FreeFile
    Open filename For output As #f
    logentry("notice", filename + " created")
    close(f)
    return true

End Function

' create a temp file
Function tmpfile(filename As String) As boolean
    Dim f As integer

    if FileExists(filename) = true then
      If Kill(filename) <> 0 Then
          logentry("warning", "could not delete " + filename )
      end if
    end if

    f = FreeFile
    Open filename For output As #f
    logentry("notice", filename + " created")
    close(f)
    return true

End Function

' append to an excisiting file
Function appendfile(filename As String, msg as string) As boolean
    Dim f As integer

    if FileExists(filename) = false then
        logentry("error", "appending " + filename + " file does not excist")
        return false
    end if

    f = FreeFile
    Open filename For append As #f
    print #f, msg
    close(f)
    return true

End Function

' read a file
Function readfromfile(filename As String) As long
    Dim f As integer

    if FileExists(filename) = false then
        logentry("error", "reading " + filename + " file does not excist")
    end if

    f = FreeFile
    Open filename For input As #f
    return f

End Function

' delete a file
Function delfile(filename As String) As boolean

    if FileExists(filename) = true then
        If Kill(filename) <> 0 Then
            logentry("warning", "could not delete " + filename)
            return false
        end if
    end if
    return true

End Function

' check path
Function checkpath(chkpath As String) As boolean

    dim dummy as string
    dummy = curdir

    if chdir(chkpath) <> 0 then
        logentry("warning", "path " + chkpath + " not found")
        chdir(dummy)
        return false
    end if

    return true

End Function

' cheap xml reading
Function readxmlfile(filename as string, element as string) As boolean

    Dim f As integer
    dim as boolean chk = false

    if FileExists(filename) = false then
        logentry("error", "reading " + filename + " file does not excist")
    end if

    f = FreeFile
    Open filename For input As #f
    logentry("notice", filename + " reading")

    Do Until EOF( f )
       Dim As String text
       Line Input #f, text
       if instr(text, "<" + element + ">") > 0 then
            Print text
            chk = true
       end if     
    Loop

    if chk = false then 
        logentry("warning", filename + " searching for " + element + " element not found")
    end if
    
    return true
    
end function

' cheap xml query by node
Function queryxmlbynode(filename as string, queryelement as string, needle as string, returnelement as string) As boolean

    Dim f As integer
    dim as boolean chk = false
    dim dummy as string
    
    if FileExists(filename) = false then
        logentry("error", "reading " + filename + " file does not excist")
    end if    

    f = FreeFile
    Open filename For input As #f
    logentry("notice", filename + " reading")
  
    Do Until EOF( f )
       Dim As String text
       Line Input #f, text
       if instr(text, "<" + queryelement + ">") > 0 then
            'print mid(text, instr(text, ">") + 1)
            dummy = mid(left(text, len(text) - len("</" + queryelement + ">")), instr(text, ">")+1)
            if dummy = needle then
                print "found needle " + needle
                logentry("notice", filename + " searching for " + needle + " found")
                'exit do
                chk = true
            end if    
       end if
       if instr(text, "<" + returnelement + ">") > 0 then
            dummy = mid(left(text, len(text) - len("</" + returnelement + ">")), instr(text, ">")+1)
            if chk = true then
                print dummy
                'launchapp (dummy, "wah")
                exit do
            end if
        end if    
    Loop

    if chk = false then
        print filename + " searching " + queryelement + " for " + needle + " needle not found"
        logentry("warning", filename + " searching " + queryelement + " for " + needle + " needle not found")
    end if
    
    return true
    
end function

' cheap xml to sqlite
Function xml2sql(filename as string, dbname as string, tbname as string) As boolean

    Dim f As integer
    dim as boolean chk = false
    dim as long recnr = 0
    
    if FileExists(filename) = false then
        logentry("error", "reading " + filename + " file does not excist")
    end if    

    f = FreeFile
    Open filename For input As #f
    logentry("notice", filename + " reading")
  
    Do Until EOF( f )
       Dim As String text
       Line Input #f, text
       if instr(text, "<" + dbname + ">") > 0 then
            chk = true
            do until eof(f)
                Line Input #f, text
                if instr(text, "<" + tbname + ">") > 0 then
                    do until eof(f)
                        Line Input #f, text
                        if instr(text, "</" + tbname + ">") = 0 then
                            print text
                        else
                            print "----"
                            recnr = recnr+1
                            exit do                                
                        end if
                    loop
                end if    
            loop
       end if     
    Loop

    if chk = false then 
        logentry("warning", filename + " not found " + dbname + " and / or " + tbname)
    else
        Print "db " + dbname
        print "tb " + tbname
        print "records " & recnr    
    end if
    
    return true
    
end function

' cheap ini file searcher
Function readinikeyvalue( filename as string, section as string, inikey as string ) as boolean

    if FileExists(filename) = false then
        logentry("error", "reading " + filename + " file does not excist")
    end if    

    Dim f As integer
    Dim text As String

    f = FreeFile
    Open filename For input As #f
    logentry("notice", filename + " searching" + " with section " + section + " for key " + inikey)

    Do Until EOF(f)
        Line Input #f, text
        ' check if section is found in the current line
        If LCase( text ) = "[" & LCase( section ) & "]" Then
            ' parse lines until the next section is reached
            Do until eof(f)
                Line Input #f, text
                if instr(text, inikey + "=") > 0 then
                    if mid(text, instr(text, "=") + 1, 1) = "" then
                        logentry("warning", filename + " searching" + " with section " + section + " with key " + inikey + " key value is blank")
                    else                      
                        print text
                    end if    
                end if
                if Left( text, 1 ) = "[" then
                    exit do
                end if    
            'logentry("warning", filename + " searching" + " with section " + section + "key not found")
            Loop
        end if
    Loop
    'logentry("notice", filename + " searching" + " with section " + section + " not found")

    return true
End Function

' cheap ini file reader
Function readini(filename as string) as boolean
    dim itm as string
    dim inikey as string
    dim inival as string
    dim f as integer
    f = readfromfile(filename)
    Do Until EOF(f)
        Line Input #f, itm
        if instr(1, itm, "=") > 1 then
            inikey = trim(mid(itm, 1, instr(1, itm, "=") - 2))
            inival = trim(mid(itm, instr(1, itm, "=") + 2, len(itm)))
            'print inikey + " - " + inival
        end if    
    loop    
    close f
return true
end function

' split or explode by delimiter return elements in array
' based on https://www.freebasic.net/forum/viewtopic.php?t=31691 code by grindstone
Function explode(haystack As String = "", delimiter as string, ordinance() As String) As UInteger
    Dim As String text = haystack  'remind explode as working copy
    Dim As UInteger b = 1, e = 1   'pointer to text, begin and end
    Dim As UInteger x              'counter
    ReDim ordinance(0)             'reset array

    Do Until e = 0
      x += 1
      ReDim Preserve ordinance(x)         'create new array element
      e = InStr(e + 1, text, delimiter)   'set end pointer to next space
      ordinance(x) = Mid(text, b, e - b)  'cut text between the pointers and write it to the array
      b = e + 1                           'set begin pointer behind end pointer for the next word
    Loop

    Return x 'nr of elements returned

    ' sample code for calling the function explode
    'ReDim As String ordinance(0)
    'explode("The big brown fox jumped over; the lazy; dog", ";", ordinance())
    'print UBound(ordinance)
    'For x As Integer = 1 To UBound(ordinance)
    '    Print ordinance(x)
    'Next

End Function

' get fileversion executable or dll windows only
function getfileversion(versinfo() as string, versdesc() as string) as integer

    dim as integer bytesread,c,dwHandle,res,verSize
    dim as string buffer,ls,qs,tfn
    dim as ushort ptr b1,b2
    dim as ubyte ptr bptr

    tfn=versinfo(8)
    if dir(tfn)="" then return -1
    verSize=GetFileVersionInfoSize(tfn,@dwHandle)
    if verSize=0 then return -2
    dim as any ptr verdat=callocate(verSize*2)

    res=GetFileVersionInfo(strptr(tfn),dwHandle,verSize*2,verdat)
    res=_
        VerQueryValue(_
            verdat,_
            "\VarFileInfo\Translation",_
            @bptr,_
            @bytesread)

    if bytesread=0 then deallocate(verdat):return -3

    b1=cast(ushort ptr,bptr)
    b2=cast(ushort ptr,bptr+2)
    ls=hex(*b1,4)& hex(*b2,4)

    for c=0 to 7
        qs="\StringFileInfo\" & ls & "\" & versdesc(c)
        res=_
            VerQueryValue(_
                verdat,_
                strptr(qs),_
                @bptr,_
                @bytesread)
        if bytesread>0 then
            buffer=space(bytesread)
            CopyMemory(strptr(buffer),bptr,bytesread)
            versinfo(c)=buffer
        else
            versinfo(c)="N/A"
        end if
    next c
    deallocate(verdat)

    return 1

end function

' get fileversion executable via .rc #cmdline
function getfileversionraw(filename as string) as string
    dim itm as string
    dim inikey as string
    dim inival as string
    dim f as integer
    f = readfromfile(filename)
    Do Until EOF(f)
        Line Input #f, itm
        if instr(1, itm, "FILEVERSION") > 0 then
            'inikey = trim(mid(itm, 1, instr(1, itm, "=") - 2))
            inival = trim(mid(itm, instr(1, itm, "FILEVERSION") + 11, len(itm)))
            inival = replace(inival, " ", "")
            inival = replace(inival, ",", ".")
            'print inikey + " - " + inival
            exit do
        else
            inival = "unknown"
        end if
    loop
    close f
    return inival

end function

' localiztion can be applied by getting a locale or other method
sub displayhelp(locale as string)
    dim dummy as string
    dim f as integer
    f = freefile
    
    ' get / set locale
    select case locale
        case "de"
            locale = "de"
        case "en"
        ' default locale
        case else
            locale = "en"
    end select    
    ' get text
    Open exepath + "\help-" + locale + ".ini" For input As #f
    Do Until EOF(f)
        Line Input #f, dummy
        print dummy    
    Loop
    close f

end sub

' text related functions
' ______________________________________________________________________________'

' setup word wrap string
type stringwrap
    as integer  linecnt     ' current line
    as integer  linemax     ' max viewable lines
    as integer  linelength  ' max line length
    as integer  wrapcharpos ' position to wrap on with wrapchar
    as string   wrapchar    ' wrap character , . etc
    as string   lineitem    ' line content
    as string   linetemp    ' temp line when wraping
end type

dim swp as stringwrap
swp.linecnt = 1
swp.linemax = 10
swp.linelength = 70
swp.wrapchar = " ,.?;-"

function replace(byref haystack as string, byref needle as string, byref substitute as string) as string
'found at https://freebasic.net/forum/viewtopic.php?f=2&t=9971&p=86259&hilit=replace+character+in+string#p86259
    dim as string temphaystack = haystack
    dim as integer fndlen = len(needle), replen = len(substitute)
    dim as integer i = instr(temphaystack, needle)

    while i
        temphaystack = left(temphaystack, i - 1) & substitute & mid(temphaystack, i + fndlen)
        i = instr(i + replen, temphaystack, needle)
    wend

    return temphaystack

end function

function wordwrap2file(filename as string, swp as stringwrap) as boolean
    dim dummy as string
    dim j as integer = 0
    dim i as integer = 1
    dim f as integer
    dim g as integer
    f = freefile

    open filename for input as #f
    open exepath + "\text.tmp" for output as #20
    do until eof(f)
        line input #f, swp.lineitem
        j = 0
        swp.linetemp = ""
        'cleanup string tab, etc
        swp.lineitem = replace(swp.lineitem, chr$(9), "")
        swp.lineitem = replace(swp.lineitem, "  ", " ")

        ' ghetto latin-1 support
        swp.lineitem = replace(swp.lineitem, chr$(130), ",")
        swp.lineitem = replace(swp.lineitem, chr$(132), chr$(34))
        swp.lineitem = replace(swp.lineitem, chr$(139), "<")
        swp.lineitem = replace(swp.lineitem, chr$(145), "'")
        swp.lineitem = replace(swp.lineitem, chr$(146), "'")
        swp.lineitem = replace(swp.lineitem, chr$(147), chr$(34))
        swp.lineitem = replace(swp.lineitem, chr$(148), chr$(34))
        swp.lineitem = replace(swp.lineitem, chr$(150), "-")
        swp.lineitem = replace(swp.lineitem, chr$(152), "~")

        if len(swp.lineitem) > swp.linelength then
            do while j <= fix(len(swp.lineitem) / swp.linelength)
                i = 1
                dummy = mid(swp.lineitem, j * swp.linelength + 1, swp.linelength)
                ' move wrappos to pos wrapchar instead of linelength if possible
                do while i <= len(swp.wrapchar)
                    swp.wrapcharpos = instrrev (mid(dummy, 1, swp.linelength), mid(swp.wrapchar, i, 1))
                    if  swp.linelength <= swp.wrapcharpos + len(mid(dummy, swp.wrapcharpos, len(dummy))) then
                        exit do
                    end if
                    i += 1
                loop
                ' special case no wrapchar
                if swp.wrapcharpos > 0 then
                    swp.linetemp = swp.linetemp + mid(dummy, 1, swp.wrapcharpos) + chr$(13) + chr$(10)_
                                    + trim(mid(dummy, swp.wrapcharpos, len(dummy)))
                else
                    ' note just chr$(13) truncates linetemp
                    swp.linetemp = swp.linetemp + dummy + chr$(13) + chr$(10)
                end if
                j += 1
                ' brute force paragraphs
                'if swp.linecnt > swp.linemax then
                '    swp.linetemp = swp.linetemp + chr$(13) + chr$(10) + chr$(13) + chr$(10)
                '    swp.linecnt = 1
                'end if        
                swp.linecnt += 1
            loop
            swp.lineitem = swp.linetemp
        end if
        print #20, swp.lineitem
    loop
    close
    return true

end function

' MD5 encrypt from the Wikipedia page "MD5"
' compile with: fbc -s console
' from https://rosettacode.org/wiki/MD5/Implementation#FreeBASIC
' note md5 is not reversible, at least it shouldn't be...
' added basic file i/o thrive4 2022

' macro for a rotate left
#Macro ROtate_Left (x, n) ' rotate left
  (x) = (x) Shl (n) + (x) Shr (32 - (n))
#EndMacro

Function MD5(test_str As String) As String

    Dim As String message = test_str   ' strings are passed as ByRef's

    Dim As UByte sx, s(0 To ...) = { 7, 12, 17, 22,  7, 12, 17, 22,  7, 12, _
    17, 22,  7, 12, 17, 22,  5,  9, 14, 20,  5,  9, 14, 20,  5,  9, 14, 20, _
    5,  9, 14, 20,  4, 11, 16, 23,  4, 11, 16, 23,  4, 11, 16, 23,  4, 11, _
    16, 23,  6, 10, 15, 21,  6, 10, 15, 21,  6, 10, 15, 21,  6, 10, 15, 21 }

    Dim As UInteger<32> K(0 To ...) = { &Hd76aa478, &He8c7b756, &H242070db, _
    &Hc1bdceee, &Hf57c0faf, &H4787c62a, &Ha8304613, &Hfd469501, &H698098d8, _
    &H8b44f7af, &Hffff5bb1, &H895cd7be, &H6b901122, &Hfd987193, &Ha679438e, _
    &H49b40821, &Hf61e2562, &Hc040b340, &H265e5a51, &He9b6c7aa, &Hd62f105d, _
    &H02441453, &Hd8a1e681, &He7d3fbc8, &H21e1cde6, &Hc33707d6, &Hf4d50d87, _
    &H455a14ed, &Ha9e3e905, &Hfcefa3f8, &H676f02d9, &H8d2a4c8a, &Hfffa3942, _
    &H8771f681, &H6d9d6122, &Hfde5380c, &Ha4beea44, &H4bdecfa9, &Hf6bb4b60, _
    &Hbebfbc70, &H289b7ec6, &Heaa127fa, &Hd4ef3085, &H04881d05, &Hd9d4d039, _
    &He6db99e5, &H1fa27cf8, &Hc4ac5665, &Hf4292244, &H432aff97, &Hab9423a7, _
    &Hfc93a039, &H655b59c3, &H8f0ccc92, &Hffeff47d, &H85845dd1, &H6fa87e4f, _
    &Hfe2ce6e0, &Ha3014314, &H4e0811a1, &Hf7537e82, &Hbd3af235, &H2ad7d2bb, _
                                                              &Heb86d391 }

    ' Initialize variables
    Dim As UInteger<32> A, a0 = &H67452301
    Dim As UInteger<32> B, b0 = &Hefcdab89
    Dim As UInteger<32> C, c0 = &H98badcfe
    Dim As UInteger<32> D, d0 = &H10325476
    Dim As UInteger<32> dtemp, F, g, temp

    Dim As Long i, j

    Dim As ULongInt l = Len(message)
    ' set the first bit after the message to 1
    message = message + Chr(1 Shl 7)
    ' add one char to the length
    Dim As ULong padding = 64 - ((l +1) Mod (512 \ 8)) ' 512 \ 8 = 64 char.

    ' check if we have enough room for inserting the length
    If padding < 8 Then padding = padding + 64

    message = message + String(padding, Chr(0))   ' adjust length
    Dim As ULong l1 = Len(message)                ' new length

    l = l * 8    ' orignal length in bits
    ' create ubyte ptr to point to l ( = length in bits)
    Dim As UByte Ptr ub_ptr = Cast(UByte Ptr, @l)

    For i = 0 To 7  'copy length of message to the last 8 bytes
    message[l1 -8 + i] = ub_ptr[i]
    Next

    For j = 0 To (l1 -1) \ 64 ' split into block of 64 bytes

    A = a0 : B = b0 : C = c0 : D = d0

    ' break chunk into 16 32bit uinteger
    Dim As UInteger<32> Ptr M = Cast(UInteger<32> Ptr, @message[j * 64])

    For i = 0 To 63
      Select Case As Const i
        Case 0 To 15
          F = (B And C) Or ((Not B) And D)
          g = i
        Case 16 To 31
          F = (B And D) Or (C And (Not D))
          g = (i * 5 +1) Mod 16
        Case 32 To 47
          F = (B Xor C Xor D)
          g = (i * 3 +5) Mod 16
        Case 48 To 63
          F = C Xor (B Or (Not D))
          g = (i * 7) Mod 16
      End Select
      dtemp = D
      D = C
      C = B
      temp = A + F + K(i)+ M[g] : ROtate_left(temp, s(i))
      B = B + temp
      A = dtemp
    Next

    a0 += A : b0 += B : c0 += C : d0 += D

    Next

    Dim As String answer
    ' convert a0, b0, c0 and d0 in hex, then add, low order first
    Dim As String s1 = Hex(a0, 8)
    For i = 7 To 1 Step -2 : answer +=Mid(s1, i, 2) : Next
    s1 = Hex(b0, 8)
    For i = 7 To 1 Step -2 : answer +=Mid(s1, i, 2) : Next
    s1 = Hex(c0, 8)
    For i = 7 To 1 Step -2 : answer +=Mid(s1, i, 2) : Next
    s1 = Hex(d0, 8)
    For i = 7 To 1 Step -2 : answer +=Mid(s1, i, 2) : Next

    Return LCase(answer)

End Function
