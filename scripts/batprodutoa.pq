@echo off
cls
setlocal

REM Garante serviço WebClient quando necessário para acesso via UNC/WebDAV
sc query WebClient | find /I "RUNNING" >nul || net start WebClient

REM Cabeçalho e chamadas dos scripts anonimizados
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
powershell -Command "Write-Host '=======================================' -ForegroundColor Cyan"
powershell -Command "Write-Host ' DISTRIBUIDOR DE PROPOSTAS - PRODUTO A' -ForegroundColor Cyan"
powershell -Command "Write-Host '=======================================' -ForegroundColor Cyan"

"%PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Copiar_Arquivo_Atual_Share.ps1"
"%PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Copiar_Arquivo_Historico_Share.ps1"

powershell -Command "Write-Host 'Operacao concluida. Pressione uma tecla para sair.' -ForegroundColor Green"
pause >nul
