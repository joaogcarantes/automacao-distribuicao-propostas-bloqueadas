@echo off
setlocal
cd /d "%~dp0"

set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

"%PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Copiar_Arquivo_Atual_ProdutoB_Share.ps1"
"%PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Copiar_Arquivo_Historico_ProdutoB_Share.ps1"

rem Mensagem final em verde
"%PS%" -NoLogo -NoProfile -Command "Write-Host 'Operacao concluida. Pressione uma tecla para sair.' -ForegroundColor Green"
pause >nul
endlocal
