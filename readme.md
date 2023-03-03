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
https://github.com/libsdl-org/SDL_mixer
## performance
windows 7 / windows 10(1903)\
ram usage ~2MB / 2MB\
handles   ~120 / ~200\
threads   4 / 7\
cpu       ~1 (low) / ~2\
tested on intel i5-6600T
## navigation
press p     to play\
press .     to play next\
press ,     to play previous\
press ]     to skip forward   10 secs\
press [     to skip backwards 10 secs\
press space to pause / play or mute / unmute\
press r     to restart\
press -     to increase volume\
press +     to decrease volume\
press esc   to quit\
# special thanks to
squall4226 for getmp3tag\
see https://www.freebasic.net/forum/viewtopic.php?p=149207&hilit=user+need+TALB+for+album#p149207
rosetta code for compoundtime\
https://rosettacode.org/wiki/Convert_seconds_to_compound_duration#FreeBASIC

