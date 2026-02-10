@echo off
setlocal enabledelayedexpansion
set "this_module=%~n0"
:: ============================================================================
::                PROJECT STARTER CORE (`start_app_core.bat`)
:: ============================================================================
:: v2 com sistema de logging configuravel (refatorado para usar log_util.bat).
:: ============================================================================

:: --- 1. CONFIGURACAO DE LOGGING E ANALISE DE ARGS ---

set "pypm_shell_path=%~dp0"
set "pypm_python_src_path=../%~dp0"

:: Niveis de verbosidade
set "LOG_LEVEL_ERROR=0"
set "LOG_LEVEL_WARN=1"
set "LOG_LEVEL_INFO=2"
set "LOG_LEVEL_DEBUG=3"

:: Nivel padrao
set "LOG_LEVEL_NUM=2"
set "LOG_LEVEL_NAME=INFO"

:: Variaveis do script
set "COMMAND_MODE="
set "NEW_LOG_LEVEL_FLAG="
set "ARGS_FOR_CORE="

:: Loop de pre-analise para encontrar flags de log
:PARSE_LOG_ARGS_LOOP
if "%~1"=="" goto :PARSE_LOG_ARGS_END
if /i "%~1"=="--quiet" ( set "NEW_LOG_LEVEL_FLAG=0" & shift & goto :PARSE_LOG_ARGS_LOOP )
if /i "%~1"=="-q" ( set "NEW_LOG_LEVEL_FLAG=0" & shift & goto :PARSE_LOG_ARGS_LOOP )
if /i "%~1"=="--verbose" ( set "NEW_LOG_LEVEL_FLAG=3" & shift & goto :PARSE_LOG_ARGS_LOOP )
if /i "%~1"=="-v" ( set "NEW_LOG_LEVEL_FLAG=3" & shift & goto :PARSE_LOG_ARGS_LOOP )
if /i "%~1"=="--log-level" ( set "NEW_LOG_LEVEL_FLAG=%~2" & shift & shift & goto :PARSE_LOG_ARGS_LOOP )

:: Se nao for uma flag de log, reconstroi a lista de argumentos para o core
if not defined COMMAND_MODE ( set "COMMAND_MODE=%~1" )
if defined ARGS_FOR_CORE ( set "ARGS_FOR_CORE=!ARGS_FOR_CORE! %1" ) else ( set "ARGS_FOR_CORE=%1" )
shift
goto :PARSE_LOG_ARGS_LOOP
:PARSE_LOG_ARGS_END

rem (Restante do analisador de comandos e help...)
if /i "%COMMAND_MODE%"=="--help" goto :HELP
if /i "%COMMAND_MODE%"=="-h" goto :HELP
if /i "%COMMAND_MODE%"=="-?" goto :HELP
if /i "%COMMAND_MODE%"=="/?" goto :HELP


:: --- 2. Limpeza do Ambiente ---
TITLE Project Starter Core
set "PYTHONPATH=" & set "PYTHONHOME=" & set "PYTHONSTARTUP="
set "PYTHONNOUSERSITE=" & set "PIP_CONFIG_FILE=" & set "PIP_REQUIRE_VIRTUALENV="
set "PIP_USER=" & set "PIP_CACHE_DIR="
set "CLEAN_PATH="
for %%i in ("%PATH:;=" "%") do (
    echo "%%~i" | findstr /i "Python" >nul
    if !ERRORLEVEL! neq 0 (
        if defined CLEAN_PATH (set "CLEAN_PATH=!CLEAN_PATH!;%%~i") else (set "CLEAN_PATH=%%~i")
    )
)
set "PATH=%CLEAN_PATH%"


:: --- 3. Carregar Configuracoes ---
set "CONFIG_DIR=.pypm"
set "CONFIG_FILE=%CONFIG_DIR%\pypm"
set "LOCAL_CONFIG_FILE=%CONFIG_DIR%\pypm.local"

if not exist "!CONFIG_FILE!" (
    call "!pypm_shell_path!\log_util.bat" %LOG_LEVEL_NUM% "ERROR" "!this_module!"  "Ficheiro de configuracao do projeto ^(`%CONFIG_FILE%`^) nao encontrado."
    pause & exit /b 1
)

:: Carrega configuracoes e PROCURA o nivel de log
for /f "usebackq tokens=1,* delims==" %%a in ("%CONFIG_FILE%") do (
    set "%%a=%%b"
    if /i "%%a"=="LOG_LEVEL" set "LOG_LEVEL_NUM=%%b"
)
if exist "%LOCAL_CONFIG_FILE%" (
    for /f "usebackq tokens=1,* delims==" %%a in ("%LOCAL_CONFIG_FILE%") do (set "%%a=%%b")
)

:: APLICAR SOBRESCRITA DA FLAG (se existir)
if defined NEW_LOG_LEVEL_FLAG (
    call "!pypm_shell_path!\log_util.bat" %LOG_LEVEL_NUM% "DEBUG" "!this_module!"  "Log level sobrescrito pela flag: %NEW_LOG_LEVEL_FLAG%"
    set "LOG_LEVEL_NUM=%NEW_LOG_LEVEL_FLAG%"
)

TITLE Project (%PROJECT_NAME%)
call "!pypm_shell_path!\log_util.bat" %LOG_LEVEL_NUM% "DEBUG" "!this_module!"  "Projeto: %PROJECT_NAME% [Log Level: %LOG_LEVEL_NUM%]"
call "!pypm_shell_path!\log_util.bat" %LOG_LEVEL_NUM% "DEBUG" "!this_module!"  "Limpando ambiente da sessao atual..."


:: --- 4. Garantir o Python Correto ---
call "!pypm_shell_path!\log_util.bat" %LOG_LEVEL_NUM% "DEBUG" "!this_module!"  "A verificar o ambiente Python..."
call "!pypm_shell_path!\python_manager.bat" --get --version "%PYTHON_VERSION%" --path "%PYTHON_PATH%"  --log-level !LOG_LEVEL_NUM!
if !ERRORLEVEL! neq 0 (
    call "!pypm_shell_path!\log_util.bat" %LOG_LEVEL_NUM% "ERROR" "!this_module!"  "Nao foi possivel obter um Python compativel com a versao %PYTHON_VERSION%."
    pause & exit /b 1
)
set /p FINAL_PYTHON_EXE=<"%TEMP%\.pypm\pypm_py_return.tmp"
call "!pypm_shell_path!\log_util.bat" %LOG_LEVEL_NUM% "DEBUG" "!this_module!"  "Python a ser usado: %FINAL_PYTHON_EXE%"

:: --- 5. DELEGAR a Preparacao do Ambiente ---
call "!pypm_shell_path!\log_util.bat" %LOG_LEVEL_NUM% "DEBUG" "!this_module!"  "A preparar o ambiente de dependencias com o motor: %DEPENDENCY_ENGINEER%..."

:: Venv agora pode ser externa ao projeto. Se VENV_PATH estiver definido em .pypm\pypm.local, usamos ele.
:: Fallback para compatibilidade: .pypm\<VENV> (legado).
if defined VENV_PATH (
    set "FINAL_VENV_PATH=%VENV_PATH%"
) else (
    set "FINAL_VENV_PATH=%CD%\%CONFIG_DIR%\%VENV%"
)

:: Se ainda nao existe VENV_PATH (primeira execucao), cria um path padrao user-scope e persiste em pypm.local.
if not defined VENV_PATH (
    if defined LOCALAPPDATA (
        for %%I in ("%CD%") do set "PROJECT_ID=%%~nI"
        set "PROJECT_ID=!PROJECT_ID: =_!"
        set "FINAL_VENV_PATH=%LOCALAPPDATA%\pypm\venvs\pip_engine\!PROJECT_ID!\.venv"
        if not exist "!LOCAL_CONFIG_FILE!" (
            (
                echo PYTHON_PATH=!FINAL_PYTHON_EXE!
                echo deps_installed=!deps_installed!
                echo VENV_PATH=!FINAL_VENV_PATH!
            )>!LOCAL_CONFIG_FILE!
        ) else (
            findstr /b /i "VENV_PATH=" "!LOCAL_CONFIG_FILE!" >nul
            if !ERRORLEVEL! neq 0 (
                >>"!LOCAL_CONFIG_FILE!" echo VENV_PATH=!FINAL_VENV_PATH!
            )
        )
    )
)

set "DEPS_FILE=%CD%\requirements.txt"


if /i "!PYTHON_PATH!" neq "!FINAL_PYTHON_EXE!" (
    call "!pypm_shell_path!\log_util.bat" %LOG_LEVEL_NUM% "WARN" "!this_module!"  "O executavel Python foi alterado. Reconstruindo o ambiente..."
    if /i "%DEPENDENCY_ENGINEER%"=="pip" (
        (
            echo PYTHON_PATH=!FINAL_PYTHON_EXE!
            echo EXEC_DIR=!EXEC_DIR!
            echo PROJECT_DIR=!PROJECT_DIR!
            echo deps_installed=False
            echo VENV_PATH=!FINAL_VENV_PATH!
        )>!LOCAL_CONFIG_FILE!
        call "!pypm_shell_path!\dependency_manager_pip.bat" --rebuild --python-exe "!FINAL_PYTHON_EXE!" --project-dir "%CD%" --venv "!FINAL_VENV_PATH!" --log-level !LOG_LEVEL_NUM! --deps-file "!DEPS_FILE!" --no-cache
    ) else (
        rem logica para poetry
    )
) else if /i "%COMMAND_MODE%"=="--rebuild" (
    if /i "%DEPENDENCY_ENGINEER%"=="pip" (
        call "!pypm_shell_path!\dependency_manager_pip.bat" --rebuild --python-exe "!FINAL_PYTHON_EXE!" --project-dir "%CD%" --venv "!FINAL_VENV_PATH!" --log-level !LOG_LEVEL_NUM! --deps-file "!DEPS_FILE!" --no-cache
    ) else (
        rem logica para poetry
    )
) else if /i "%COMMAND_MODE%"=="--add-dep" (
    rem Nao faz nada aqui, sera tratado na secao 6
) else if /i "%COMMAND_MODE%"=="--remove-dep" (
    rem Nao faz nada aqui, sera tratado na secao 6
)  else (
    rem Execucao padrao "smart"
    if /i "%DEPENDENCY_ENGINEER%"=="pip" (
        call "!pypm_shell_path!\dependency_manager_pip.bat" --ensure-env --python-exe "!FINAL_PYTHON_EXE!" --project-dir "%CD%" --venv "!FINAL_VENV_PATH!" --deps-file "!DEPS_FILE!" --deps-installed "!deps_installed!" --log-level !LOG_LEVEL_NUM!
    ) else (
        rem logica para poetry
    )
)
if !ERRORLEVEL! neq 0 ( call "!pypm_shell_path!\log_util.bat" %LOG_LEVEL_NUM% "ERROR" "!this_module!"  "Falha ao preparar o ambiente." & pause & exit /b 1 )
call "!pypm_shell_path!\log_util.bat" %LOG_LEVEL_NUM% "DEBUG" "!this_module!"  "Ambiente pronto."

:: --- 6. Analisador de Comandos e Execucao ---
call "!pypm_shell_path!\log_util.bat" %LOG_LEVEL_NUM% "DEBUG" "!this_module!"  "Argumentos recebidos pelo core: %ARGS_FOR_CORE%"

:: (Precisamos re-parsear os argumentos sem as flags de log)
set "ARG1=" & set "ARG2="
for /f "tokens=1,2" %%i in ("%ARGS_FOR_CORE%") do (
    set "ARG1=%%i"
    set "ARG2=%%j"
)
set "COMMAND_MODE=%ARG1%"
set "COMMAND_ARGS=%ARG2%"

call "!pypm_shell_path!\log_util.bat" %LOG_LEVEL_NUM% "DEBUG" "!this_module!"  "Comando principal: %COMMAND_MODE%"
call "!pypm_shell_path!\log_util.bat" %LOG_LEVEL_NUM% "DEBUG" "!this_module!"  "Argumentos do comando: %COMMAND_ARGS%"

if %LOG_LEVEL_NUM% GEQ 3 echo.
if %LOG_LEVEL_NUM% GEQ 3 echo ============================================================================

if /i "%COMMAND_MODE%"=="--shell" (
    if /i "%DEPENDENCY_ENGINEER%"=="pip" (
        call "!pypm_shell_path!dependency_manager_pip.bat" --shell --python-exe "!FINAL_PYTHON_EXE!" --project-dir "%CD%" --venv "!FINAL_VENV_PATH!" --log-level !LOG_LEVEL_NUM!
    ) else (
        rem logica para poetry
    )
    exit /b
)

if /i "%COMMAND_MODE%"=="--add-dep" (
    if not defined COMMAND_ARGS ( call "!pypm_shell_path!\log_util.bat" %LOG_LEVEL_NUM% "ERROR" "!this_module!"  "O modo --add-dep requer um pacote para adicionar." & pause & exit /b 1 )
    if /i "%DEPENDENCY_ENGINEER%"=="pip" (
         call "!pypm_shell_path!\dependency_manager_pip.bat" --python-exe "!FINAL_PYTHON_EXE!" --project-dir "%CD%" --venv "!FINAL_VENV_PATH!" --deps-file "!DEPS_FILE!" --log-level !LOG_LEVEL_NUM! --add-dep "!COMMAND_ARGS!"
    ) else (
        rem logica para poetry
    )
    exit /b
)

if /i "%COMMAND_MODE%"=="--remove-dep" (
    if not defined COMMAND_ARGS ( call "!pypm_shell_path!\log_util.bat" %LOG_LEVEL_NUM% "ERROR" "!this_module!"  "O modo --remove-dep requer um pacote para adicionar." & pause & exit /b 1 )
    if /i "%DEPENDENCY_ENGINEER%"=="pip" (
        call "!pypm_shell_path!\dependency_manager_pip.bat" --python-exe "!FINAL_PYTHON_EXE!" --project-dir "%CD%" --venv "!FINAL_VENV_PATH!" --deps-file "!DEPS_FILE!" --log-level !LOG_LEVEL_NUM! --remove-dep "!COMMAND_ARGS!"
    ) else (
         rem logica para poetry
    )
    exit /b
)

if /i "%COMMAND_MODE%"=="--python-shell" (
    call "!pypm_shell_path!\log_util.bat" %LOG_LEVEL_NUM% "DEBUG" "!this_module!"  "Executando !FINAL_PYTHON_EXE!"
    "!FINAL_PYTHON_EXE!"
) else if /i "%COMMAND_MODE%"=="--run" (
    if /i "%COMMAND_ARGS%"=="" (
        call "!pypm_shell_path!\log_util.bat" %LOG_LEVEL_NUM% "WARN" "!this_module!"  "Ambiente preparado. Nenhum comando de execucao fornecido."
    ) else (
        call "!pypm_shell_path!\log_util.bat" %LOG_LEVEL_NUM% "DEBUG" "!this_module!"  "Ambiente preparado. Executando comando --run %COMMAND_ARGS%..."

        :: Reconstrói os argumentos restantes (tudo depois de --run)
        set "RUN_CMD="
        for %%a in (%ARGS_FOR_CORE%) do (
            if /i not "%%a"=="--run" (
                set "RUN_CMD=!RUN_CMD! %%a"
            )
        )

        set "VENV_PYTHON_EXE=!FINAL_VENV_PATH!\Scripts\python.exe"
        if exist "!VENV_PYTHON_EXE!" (
            set "PYTHON_TO_RUN=!VENV_PYTHON_EXE!"
        ) else (
            set "PYTHON_TO_RUN=!FINAL_PYTHON_EXE!"
        )

        "!PYTHON_TO_RUN!" !RUN_CMD!

    )
) else if /i not "%COMMAND_MODE%"=="--rebuild" (
    call "!pypm_shell_path!\log_util.bat" %LOG_LEVEL_NUM% "ERROR" "!this_module!"  "Comando desconhecido: %COMMAND_MODE%"
)

goto :EOF

:HELP
    if not exist "!pypm_shell_path!..\helpers\start_app_core_help.txt" ( call "!pypm_shell_path!\log_util.bat" %LOG_LEVEL_NUM% "ERROR" "!this_module!"  "Ficheiro de ajuda nao encontrado." & exit /b 1 )
    type "!pypm_shell_path!..\helpers\start_app_core_help.txt"
    exit /b 0

endlocal
