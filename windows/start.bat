taskkill /f /im quanta.exe

rd .\logs /s /q
start "ttplrc"  .\quanta.exe .\ttplrc.conf