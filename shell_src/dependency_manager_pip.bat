@echo off
setlocal enabledelayedexpansion

:: ============================================================================
::                DEPENDENCY MANAGER - MODO PIP
:: ============================================================================
:: Este script e um modulo de servico para gerir ambientes virtuais (venv)
:: e dependencias atraves do pip.
:: ============================================================================

:: --- Configuracao e Analisador de Argumentos ---
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
if not defined MODE goto :USAGE
if not defined ARG_PYTHON_EXE ( echo [ERRO] O parametro --python-exe e obrigatorio. >&2 & exit /b 1 )
if not defined ARG_PROJECT_DIR ( echo [ERRO] O parametro --project-dir e obrigatorio. >&2 & exit /b 1 )
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
    if !ERRORLEVEL! neq 0 exit /b 1
    
    echo A abrir um novo terminal com o ambiente ativado...
    cmd /k ""%ARG_VENV_NAME%\Scripts\activate.bat""
    exit /b 0

:MODE_ADD_DEP
    if not defined ARG_PACKAGE ( echo [ERRO] O modo --add-dep requer o nome de um pacote. >&2 & exit /b 1 )
    call :CREATE_VENV_AND_INSTALL
    if !ERRORLEVEL! neq 0 exit /b 1

    echo A adicionar e instalar a dependencia: %ARG_PACKAGE%...
    "!ARG_VENV_NAME!\Scripts\pip.exe" install "%ARG_PACKAGE%"
    if !ERRORLEVEL! neq 0 ( echo [ERRO] Falha ao instalar o pacote. >&2 & exit /b 1 )

    if defined ARG_DEPS_FILE (
        echo [INFO] A adicionar "%ARG_PACKAGE%" ao ficheiro %ARG_DEPS_FILE%...
        >>"%ARG_DEPS_FILE%" echo %ARG_PACKAGE%
    )
    echo Pacote instalado e adicionado com sucesso.
    exit /b 0

:MODE_REMOVE_DEP
    rem Implementacao do remove-dep
    exit /b 0

:MODE_REBUILD
    if not defined ARG_VENV_NAME ( echo [ERRO] O modo --rebuild requer o parametro --venv. >&2 & exit /b 1 )
    
    echo A reconstruir o ambiente...
    if exist "%ARG_VENV_NAME%" (
        echo [INFO] A remover o ambiente virtual antigo...
        rmdir /s /q "%ARG_VENV_NAME%"
    )
    
    echo [INFO] A limpar caches Python...
    for /r %%i in (__pycache__) do if exist "%%i" rmdir /s /q "%%i"
    del /s /q *.pyc > nul 2>nul

    call :CREATE_VENV_AND_INSTALL
    if !ERRORLEVEL! neq 0 exit /b 1

    call :UPDATE_DEPS_FLAG
    echo Ambiente reconstruido com sucesso.
    exit /b 0

:HELP
    rem Implementacao do help
    exit /b 0

:USAGE
    echo. >&2 & echo Uso: %~n0 [modo] [parametros] >&2 & echo Para mais informacoes, use: %~n0 --help >&2 & exit /b 1

:: ============================================================================
:: --- FUNCOES DE LOGICA INTERNA ---
:: ============================================================================

:CREATE_VENV_AND_INSTALL
    if not defined ARG_VENV_NAME ( exit /b 0 )
    
    set "VENV_CREATED_NOW=false"
    if not exist "%ARG_VENV_NAME%" (
        echo [INFO] Ambiente virtual nao encontrado. A criar em "%ARG_VENV_NAME%"...
        "%ARG_PYTHON_EXE%" -m venv "%ARG_VENV_NAME%"
        if !ERRORLEVEL! neq 0 ( echo [ERRO] Falha ao criar o ambiente virtual. >&2 & exit /b 1 )
        set "VENV_CREATED_NOW=true"
    )

    if "%VENV_CREATED_NOW%"=="true" (
        if defined ARG_DEPS_FILE (
            if exist "%ARG_DEPS_FILE%" (
                echo [INFO] A instalar dependencias de %ARG_DEPS_FILE%...
                set "PIP_OPTIONS="
                if "%ARG_NO_CACHE%"=="true" set "PIP_OPTIONS=--no-cache-dir"
                "!ARG_VENV_NAME%\Scripts\pip.exe" install %PIP_OPTIONS% -r "%ARG_DEPS_FILE%"
                if !ERRORLEVEL! neq 0 (
                    echo [AVISO] Ocorreram erros durante a instalacao das dependencias. >&2
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
    echo [INFO] A atualizar o status de 'deps_installed' para True...
    (for /f "usebackq tokens=1,* delims==" %%a in ("%LOCAL_CONFIG_FILE%") do (
        if /i "%%a"=="deps_installed" (
            echo deps_installed=True
        ) else (
            echo %%a=%%b
        )
    )) > "%LOCAL_CONFIG_FILE%.tmp"
    move /y "%LOCAL_CONFIG_FILE%.tmp" "%LOCAL_CONFIG_FILE%" >nul
goto :EOF
