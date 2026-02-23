$vsPath = "C:\Program Files\Microsoft Visual Studio\2022\Community"
$vcvarsall = "$vsPath\VC\Auxiliary\Build\vcvarsall.bat"

# Import MSVC environment
$tempFile = [System.IO.Path]::GetTempFileName()
cmd /c "`"$vcvarsall`" x64 && set > `"$tempFile`""
Get-Content $tempFile | ForEach-Object {
    if ($_ -match "^([^=]+)=(.*)$") {
        [Environment]::SetEnvironmentVariable($matches[1], $matches[2], "Process")
    }
}
Remove-Item $tempFile

Set-Location "D:\Code\HilmCode\Code\Customized_QGC"
cmake --build build --config Debug 2>&1
Write-Host "BUILD_EXIT_CODE=$LASTEXITCODE"
