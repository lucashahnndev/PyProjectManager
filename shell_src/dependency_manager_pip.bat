@echo off
setlocal enabledelayedexpansion
set "this_module=%~n0"
:: ============================================================================
::                DEPENDENCY MANAGER - MODO PIP
:: ============================================================================
:: v2 com sistema de logging externo (log_util.bat).
:: ============================================================================

:: --- 1. CONFIGURACAO DE LOGGING E ANALISE DE ARGS ---
set "pypm_shell_path=%~dp0"
set "LOG_UTIL_SCRIPT=!pypm_shell_path!\log_util.bat"

:: Niveis de verbosidade
set "LOG_LEVEL_ERROR=0"
set "LOG_LEVEL_WARN=1"
set "LOG_LEVEL_INFO=2"
set "LOG_LEVEL_DEBUG=3"

:: Nivel padrao
set "LOG_LEVEL_NUM=2"

:: Variaveis do script
set "MODE="
set "ARG_PYTHON_EXE="
set "ARG_PROJECT_DIR="
set "ARG_VENV_NAME="
set "ARG_DEPS_FILE="
set "ARG_PACKAGE="
set "ARG_DEPS_INSTALLED_FLAG="
set "ARG_NO_CACHE=false"

if "%~1"=="" goto :USAGE

:PARSE_ARGS_LOOP
if "%~1"=="" goto :DISPATCH

:: --- Parser de Flags de Log ---
if /i "%~1"=="--quiet" ( set "LOG_LEVEL_NUM=0" & shift & goto :PARSE_ARGS_LOOP )
if /i "%~1"=="-q" ( set "LOG_LEVEL_NUM=0" & shift & goto :PARSE_ARGS_LOOP )
if /i "%~1"=="--verbose" ( set "LOG_LEVEL_NUM=3" & shift & goto :PARSE_ARGS_LOOP )
if /i "%~1"=="-v" ( set "LOG_LEVEL_NUM=3" & shift & goto :PARSE_ARGS_LOOP )
if /i "%~1"=="--log-level" ( set "LOG_LEVEL_NUM=%~2" & shift & shift & goto :PARSE_ARGS_LOOP )

:: --- Parser de Comandos do Script ---
if /i "%~1"=="--ensure-env" set "MODE=ENSURE_ENV"
if /i "%~1"=="--shell" set "MODE=SHELL"
if /i "%~1"=="--add-dep" set "MODE=ADD_DEP"
if /i "%~1"=="--remove-dep" set "MODE=REMOVE_DEP"
if /i "%~1"=="--rebuild" set "MODE=REBUILD"
if /i "%~1"=="--help" goto :HELP

if /i "%~1"=="--python-exe" ( set "ARG_PYTHON_EXE=%~2" & shift )
if /i "%~1"=="--project-dir" ( set "ARG_PROJECT_DIR=%~2" & shift )
if /i "%~1"=="--venv" ( set "ARG_VENV_NAME=%~2" & shift )
if /i "%~1"=="--deps-file" ( set "ARG_DEPS_FILE=%~2" & shift )
if /i "%~1"=="--deps-installed" ( set "ARG_DEPS_INSTALLED_FLAG=%~2" & shift )
if /i "%~1"=="--no-cache" set "ARG_NO_CACHE=true"

if /i "%~1"=="--add-dep" ( set "ARG_PACKAGE=%~2" & goto :DISPATCH )
if /i "%~1"=="--remove-dep" ( set "ARG_PACKAGE=%~2" & goto :DISPATCH )

shift
goto :PARSE_ARGS_LOOP

:DISPATCH
if not defined MODE ( goto :USAGE )
if not defined ARG_PYTHON_EXE ( call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "ERROR" "!this_module!"  "O parametro --python-exe e obrigatorio." & exit /b 1 )
if not defined ARG_PROJECT_DIR ( call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "ERROR" "!this_module!"  "O parametro --project-dir e obrigatorio." & exit /b 1 )
if not defined ARG_VENV_NAME (
    call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "ERROR" "!this_module!"  "O parametro --venv deve receber o caminho completo do ambiente virtual (ex: C:\\...\\.venv)."
    exit /b 1
)
cd /d "%ARG_PROJECT_DIR%"
if "%MODE%"=="ENSURE_ENV" goto :MODE_ENSURE_ENV
if "%MODE%"=="SHELL" goto :MODE_SHELL
if "%MODE%"=="ADD_DEP" goto :MODE_ADD_DEP
if "%MODE%"=="REMOVE_DEP" goto :MODE_REMOVE_DEP
if "%MODE%"=="REBUILD" goto :MODE_REBUILD
goto :USAGE

:: ============================================================================
:: --- FLUXOS DE MODO ---
:: ============================================================================

:MODE_ENSURE_ENV
    set "NEEDS_INSTALL=false"
    if not exist "%ARG_VENV_NAME%" (
        set "NEEDS_INSTALL=true"
    ) else if /i "%ARG_DEPS_INSTALLED_FLAG%"=="False" (
        set "NEEDS_INSTALL=true"
    )

    if "%NEEDS_INSTALL%"=="true" (
         call :CREATE_VENV_AND_INSTALL
        if !ERRORLEVEL! neq 0 ( exit /b 1 )
        call :UPDATE_DEPS_FLAG
    )
    exit /b 0

:MODE_SHELL
    call :CREATE_VENV_AND_INSTALL
    if !ERRORLEVEL! neq 0 ( exit /b 1 )
    call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "DEBUG" "!this_module!"  "A abrir um novo terminal com o ambiente ativado..."
    cmd /k ""%ARG_VENV_NAME%\Scripts\activate.bat""
    exit /b 0

:MODE_ADD_DEP
    if not defined ARG_PACKAGE ( call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "ERROR" "!this_module!"  "O modo --add-dep requer o nome de um pacote." & exit /b 1 )
    call :CREATE_VENV_AND_INSTALL
    if !ERRORLEVEL! neq 0 ( exit /b 1 )

    call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "INFO" "!this_module!"  "A adicionar e instalar a dependencia: %ARG_PACKAGE%..."
    "!ARG_VENV_NAME!\Scripts\python.exe" -m pip install "%ARG_PACKAGE%"
    if !ERRORLEVEL! neq 0 ( call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "ERROR" "!this_module!"  "Falha ao instalar o pacote." & exit /b 1 )

    if exist "!ARG_DEPS_FILE!" (
        call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "INFO" "!this_module!"  "A adicionar '%ARG_PACKAGE%' ao ficheiro %ARG_DEPS_FILE%..."
        >>"%ARG_DEPS_FILE%" echo %ARG_PACKAGE%
    )
    call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "INFO" "!this_module!"  "Pacote instalado e adicionado com sucesso."
    exit /b 0

:MODE_REMOVE_DEP
    "!ARG_VENV_NAME!\Scripts\python.exe" -m pip uninstall "%ARG_PACKAGE%" -y
    if !ERRORLEVEL! equ 1 (
        call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "ERROR" "!this_module!"  "!ARG_PACKAGE! nao encontrada como instalada!"
    )
    if not exist "%ARG_DEPS_FILE%" ( exit /b 0 )
    set "LOCAL_CONFIG_FILE=%ARG_DEPS_FILE%.temp"
    set "found_depdendency=False"
    (for /f "usebackq tokens=1,* delims==" %%a in ("%ARG_DEPS_FILE%") do (
            echo %%a | findstr /R /C:^%ARG_PACKAGE% >nul
            if !ERRORLEVEL! equ 1 (
                 echo %%a
            ) else (
                set "found_depdendency=True"
            )
    )) > "%LOCAL_CONFIG_FILE%.tmp"
    move /y "%LOCAL_CONFIG_FILE%.tmp" "%ARG_DEPS_FILE%" >nul
    if "!found_depdendency!"=="True" (
        call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "INFO" "!this_module!"  "!ARG_PACKAGE! removido com sucesso!"
    ) else (
        call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "WARN" "!this_module!"  "!ARG_PACKAGE! nao encontrada como instalada!"
    )
    exit /b 0

:MODE_REBUILD
    if not defined ARG_VENV_NAME ( call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "ERROR" "!this_module!"  "O modo --rebuild requer o parametro --venv." & exit /b 1 )
    call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "INFO" "!this_module!"  "A reconstruir o ambiente..."
    if exist "%ARG_VENV_NAME%" (
        call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "INFO" "!this_module!"  "A remover o ambiente virtual antigo..."
        rmdir /s /q "%ARG_VENV_NAME%"
    )

    call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "INFO" "!this_module!"  "A limpar caches Python..."
    for /r %%i in (__pycache__) do if exist "%%i" rmdir /s /q "%%i"
    del /s /q *.pyc > nul 2>nul


    set "ARG_DEPS_INSTALLED_FLAG=False"
    call :MODE_ENSURE_ENV
    if !ERRORLEVEL! neq 0 ( exit /b 1 )

    call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "INFO" "!this_module!"  "Ambiente reconstruido com sucesso."
    exit /b 0

:HELP
    :: (Implementacao do help...)
    exit /b 0

:USAGE
    echo. >&2
    call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "INFO" "!this_module!"  "Uso: !this_module! [modo] [parametros]" >&2
    call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "INFO" "!this_module!"  "Para mais informacoes, use: !this_module! --help" >&2
    exit /b 1

:: ============================================================================
:: --- FUNCOES DE LOGICA INTERNA ---
:: ============================================================================

:CREATE_VENV_AND_INSTALL
    if not defined ARG_VENV_NAME ( call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "ERROR" "!this_module!"  "O parametro --venv (caminho completo) e obrigatorio para este modo." & exit /b 1 )
    set "VENV_CREATED_NOW=false"
    if not exist "%ARG_VENV_NAME%" (
        call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "INFO" "!this_module!"  "A criar novo ambiente virtual em '%ARG_VENV_NAME%'..."
        call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "INFO" "!this_module!"  "Isso acontecera apenas uma vez..."
        "%ARG_PYTHON_EXE%" -m venv "%ARG_VENV_NAME%"
        if !ERRORLEVEL! neq 0 ( call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "ERROR" "!this_module!"  "Falha ao criar o ambiente virtual." & exit /b 1 )
        set "VENV_CREATED_NOW=true"
        call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "INFO" "!this_module!"  "A atualizar pip..."
        "!ARG_VENV_NAME!\Scripts\python.exe" -m pip install --upgrade pip
    )
    if "%NEEDS_INSTALL%"=="true" (
        if defined ARG_DEPS_FILE (
            if exist "!ARG_DEPS_FILE!" (
                call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "INFO" "!this_module!"  "A instalar dependencias de %ARG_DEPS_FILE%..."
                call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "INFO" "Isso acontecera apenas uma vez..."
                set "PIP_OPTIONS="
                if "%ARG_NO_CACHE%"=="true" set "PIP_OPTIONS=--no-cache-dir"
                "!ARG_VENV_NAME!\Scripts\python.exe" -m pip install %PIP_OPTIONS% -r "!ARG_DEPS_FILE!"
                if !ERRORLEVEL! neq 0 (
                    call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "WARN" "!this_module!"  "Ocorreram erros durante a instalacao das dependencias."
                    exit /b 1
                )
            )
        )
    )
    exit /b 0
goto :EOF

:UPDATE_DEPS_FLAG
    set "LOCAL_CONFIG_FILE=.pypm\pypm.local"
    if not exist "%LOCAL_CONFIG_FILE%" goto :EOF
    call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "DEBUG" "!this_module!"  "A atualizar o status de 'deps_installed' para True..."
    (for /f "usebackq tokens=1,* delims==" %%a in ("%LOCAL_CONFIG_FILE%") do (
        if /i "%%a"=="deps_installed" (
            echo deps_installed=True
        ) else (
            echo %%a=%%b
        )
    )) > "%LOCAL_CONFIG_FILE%.tmp"
    move /y "%LOCAL_CONFIG_FILE%.tmp" "%LOCAL_CONFIG_FILE%" >nul
goto :EOF
