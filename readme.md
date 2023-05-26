## audioplayer (sdl2 mixer)
basic audioplayer written in freebasic and bass\
supported audio types are .flac, .mp3, .m4a, .mp4, .ogg, .wav\
supported playlists .m3u, .pls\
ascii interface\
\
basic config options in conf.ini\
locale          = <locale>\
defaultvolume   = <1 .. 128>\
playtype        = <shuffle, linear>\
' dynamic range compression *currently not working with sdl\
drc             = <true, false>\
\
basic help localization via:\
help-de.ini\
help-en.ini\
\
if present coverart will be extracted and written to file as thumb.jpg\
When a file or path is specified the current dir and sub dir(s)\
will be scanned for audio file(s) which will generate an internal playlist\
## usage
audioplayer.exe "path to file or folder"\
if a file or path is specified the folder will be scanned for an audio file\
if the folder has subfolder(s) these will be scanned for audio files as well.
## requirements
sdl2.dll (32bit)\
https://www.libsdl.org/
and\
sdl2_mixer.dll (32bit)\
https://github.com/libsdl-org/SDL_mixer\

Note a number of bindings have been added to\
SDL2_mixer.bi\
located in <FreeBASIC-1.09.0-gcc-9.3>\inc\SDL2\

Either copy the SDL2_mixer.bi included in the source\
from\
inc\SDL2\
to
<FreeBASIC-1.09.0-gcc-9.3>\inc\SDL2\

or add this to <FreeBASIC-1.09.0-gcc-9.3>\inc\SDL2\SDL2_mixer.bi

[code]\
' added for version sdl2 mixer 2.6.2\
declare function Mix_GetMusicArtistTag(byval music as Mix_Music ptr) as const zstring ptr\
declare function Mix_GetMusicTitleTag(byval music as Mix_Music ptr) as const zstring ptr\
declare function Mix_GetMusicAlbumTag(byval music as Mix_Music ptr) as const zstring ptr\
declare function Mix_GetMusicCopyrightTag(byval music as Mix_Music ptr) as const zstring ptr\
declare function Mix_MusicDuration(byval music as Mix_Music ptr) as double\
declare function Mix_GetMusicPosition(byval music as Mix_Music ptr) as double\
declare function Mix_GetMusicVolume(byval volume as long) as long\
declare function Mix_MasterVolume(byval volume as long) as long\
[/code]

## performance
windows 7 / windows 10(1903)\
ram usage ~2MB / 2MB\
handles   ~120 / ~200\
threads   4 / 7\
cpu       ~1 (low) / ~2\
tested on intel i5-6600T
## navigation
press .     to play next\
press ,     to play previous\
press ]     to skip forward   10 secs\
press [     to skip backwards 10 secs\
press space to pause / play or mute / unmute\
press r     to restart\
press l     for linear / shuffle list play\
press d     for dynamic range compression *note currently not working for sdl\
press -     to increase volume\
press +     to decrease volume\
press esc   to quit\
# special thanks to
squall4226 for getmp3tag\
see https://www.freebasic.net/forum/viewtopic.php?p=149207&hilit=user+need+TALB+for+album#p149207
rosetta code for compoundtime\
https://rosettacode.org/wiki/Convert_seconds_to_compound_duration#FreeBASIC

