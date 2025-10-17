@echo off
setlocal
:: ============================================================================
::                LOGGING UTILITY (`log_util.bat`)
:: ============================================================================
:: v2 - Agora inclui o nome do chamador.
::
:: Recebe 4 argumentos:
:: %1 = Nível de Log da Execução (ex: 2)
:: %2 = Nível da Mensagem (ex: "INFO", "ERROR")
:: %3 = Nome do Chamador (ex: "start_app_core")
:: %4 = Mensagem (ex: "Script iniciado")
:: ============================================================================

:: --- Definição dos Níveis ---
set "LOG_LEVEL_ERROR=0"
set "LOG_LEVEL_WARN=1"
set "LOG_LEVEL_INFO=2"
set "LOG_LEVEL_DEBUG=3"

:: --- Argumentos ---
set "LOG_LEVEL_NUM=%~1"
set "LOG_MSG_LEVEL_NAME=%~2"
set "CALLER_NAME=%~3"
set "LOG_MSG_TEXT=%~4"
set "LOG_MSG_LEVEL_NUM=2"

:: --- Lógica de Comparação ---
if /i "%LOG_MSG_LEVEL_NAME%"=="ERROR" set "LOG_MSG_LEVEL_NUM=%LOG_LEVEL_ERROR%"
if /i "%LOG_MSG_LEVEL_NAME%"=="WARN"  set "LOG_MSG_LEVEL_NUM=%LOG_LEVEL_WARN%"
if /i "%LOG_MSG_LEVEL_NAME%"=="INFO"  set "LOG_MSG_LEVEL_NUM=%LOG_LEVEL_INFO%"
if /i "%LOG_MSG_LEVEL_NAME%"=="DEBUG" set "LOG_MSG_LEVEL_NUM=%LOG_LEVEL_DEBUG%"

if %LOG_MSG_LEVEL_NUM% LEQ %LOG_LEVEL_NUM% (
    if %LOG_MSG_LEVEL_NUM% EQU 0 (
        :: Erros vão para stderr
        echo [%CALLER_NAME%] [%LOG_MSG_LEVEL_NAME%] %LOG_MSG_TEXT% >&2
    ) else (
        echo [%CALLER_NAME%] [%LOG_MSG_LEVEL_NAME%] %LOG_MSG_TEXT%
    )
)
endlocal
exit /b 0