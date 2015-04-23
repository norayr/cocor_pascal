rem collect recursively into %1.lzh including subdirectories
lha a %1 /rx
rem turn it into a self extracting executable %1.exe
lha s %1 /rx
