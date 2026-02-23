@echo off
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat" x64 >nul 2>&1
cd /d D:\Code\HilmCode\Code\Customized_QGC
cmake --build build --config Debug 2>&1
echo BUILD_EXIT_CODE=%ERRORLEVEL%
