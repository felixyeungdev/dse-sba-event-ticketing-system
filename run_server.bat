@echo off
cd server
fpc @fpc.cfg lib/main.pas -FuC:\FPC\3.0.4\units\i386-win32\*;
.\lib\main.exe;
cd ..