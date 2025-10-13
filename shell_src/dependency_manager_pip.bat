@echo off
setlocal enabledelayedexpansion

:: ============================================================================
::                DEPENDENCY MANAGER - MODO PIP
:: ============================================================================
:: Este script e um modulo de servico para gerir ambientes virtuais (venv)
:: e dependencias atraves do pip e de um ficheiro requirements.txt.
::
:: Comunicacao de Retorno:
:: - Sucesso: Termina com codigo de saida 0.
:: - Falha:   Imprime uma mensagem de erro para stderr e termina com codigo de saida 1.
:: - --shell: Ativa o venv e abre um novo CMD interativo.
:: ============================================================================

:: --- Configuracao e Analisador de Argumentos ---
set "MODE="
set "ARG_PYTHON_EXE="
set "ARG_PROJECT_DIR="
set "ARG_VENV_NAME="
set "ARG_DEPS_FILE="
set "ARG_DEP_TO_ADD="
set "ARG_DEP_TO_REMOVE="
set "ARG_NO_CACHE=false"

if "%~1"=="" goto :USAGE

:PARSE_ARGS_LOOP
if "%~1"=="" goto :DISPATCH
if /i "%~1"=="--shell" set "MODE=SHELL"
if /i "%~1"=="--add-dep" set "MODE=ADD_DEP"
if /i "%~1"=="--remove-dep" set "MODE=REMOVE_DEP"
if /i "%~1"=="--rebuild" set "MODE=REBUILD"
if /i "%~1"=="--help" goto :HELP
if /i "%~1"=="-h" goto :HELP
if /i "%~1"=="-?" goto :HELP
if /i "%~1"=="/?" goto :HELP

if /i "%~1"=="--python-exe" ( set "ARG_PYTHON_EXE=%~2" & shift )
if /i "%~1"=="--py" ( set "ARG_PYTHON_EXE=%~2" & shift )
if /i "%~1"=="--project-dir" ( set "ARG_PROJECT_DIR=%~2" & shift )
if /i "%~1"=="--venv" ( set "ARG_VENV_NAME=%~2" & shift )
if /i "%~1"=="--deps-file" ( set "ARG_DEPS_FILE=%~2" & shift )
if /i "%~1"=="--no-cache" set "ARG_NO_CACHE=true"

rem O --add-dep e --remove-dep podem nao ter mais argumentos
if "%MODE%"=="ADD_DEP" ( set "ARG_DEP_TO_ADD=%~2" & goto :DISPATCH )
if "%MODE%"=="REMOVE_DEP" ( set "ARG_DEP_TO_REMOVE=%~2" & goto :DISPATCH )

shift
goto :PARSE_ARGS_LOOP

:DISPATCH
if not defined MODE goto :USAGE

rem Validacao de parametros obrigatorios
if not defined ARG_PYTHON_EXE ( echo [ERRO] O parametro --python-exe e obrigatorio. >&2 & exit /b 1 )
if not defined ARG_PROJECT_DIR ( echo [ERRO] O parametro --project-dir e obrigatorio. >&2 & exit /b 1 )
if not exist "%ARG_PROJECT_DIR%" ( echo [ERRO] O diretorio do projeto nao existe: "%ARG_PROJECT_DIR%". >&2 & exit /b 1 )
if not exist "%ARG_PYTHON_EXE%" ( echo [ERRO] O executavel Python nao existe: "%ARG_PYTHON_EXE%". >&2 & exit /b 1 )

rem Navega para o diretorio do projeto para todas as operacoes
cd /d "%ARG_PROJECT_DIR%"

if "%MODE%"=="SHELL" goto :MODE_SHELL
if "%MODE%"=="ADD_DEP" goto :MODE_ADD_DEP
if "%MODE%"=="REMOVE_DEP" goto :MODE_REMOVE_DEP
if "%MODE%"=="REBUILD" goto :MODE_REBUILD
goto :USAGE

:: ============================================================================
:: --- FLUXOS DE MODO ---
:: ============================================================================

:MODE_SHELL
    call :ENSURE_VENV_AND_INSTALL
    if !ERRORLEVEL! neq 0 exit /b 1
    
    echo A abrir um novo terminal com o ambiente ativado...
    cmd /k ""!ARG_VENV_NAME!\Scripts\activate.bat""
    exit /b 0

:MODE_ADD_DEP
    if not defined ARG_DEP_TO_ADD ( echo [ERRO] O modo --add-dep requer o nome de um pacote. >&2 & exit /b 1 )
    call :ENSURE_VENV_AND_INSTALL
    if !ERRORLEVEL! neq 0 exit /b 1

    echo A adicionar e instalar a dependencia: %ARG_DEP_TO_ADD%...
    "!ARG_VENV_NAME!\Scripts\pip.exe" install "%ARG_DEP_TO_ADD%"
    if !ERRORLEVEL! neq 0 ( echo [ERRO] Falha ao instalar o pacote. >&2 & exit /b 1 )

    if defined ARG_DEPS_FILE (
        if exist "%ARG_DEPS_FILE%" (
            findstr /i /L /x /c:"%ARG_DEP_TO_ADD%" "%ARG_DEPS_FILE%" >nul
            if !ERRORLEVEL! neq 0 (
                echo [INFO] A adicionar "%ARG_DEP_TO_ADD%" ao ficheiro %ARG_DEPS_FILE%...
                >>"%ARG_DEPS_FILE%" echo %ARG_DEP_TO_ADD%
            )
        )
    )
    echo Pacote instalado e adicionado com sucesso.
    exit /b 0

:MODE_REMOVE_DEP
    if not defined ARG_DEP_TO_REMOVE ( echo [ERRO] O modo --remove-dep requer o nome de um pacote. >&2 & exit /b 1 )
    call :ENSURE_VENV_AND_INSTALL
    if !ERRORLEVEL! neq 0 exit /b 1

    echo A desinstalar a dependencia: %ARG_DEP_TO_REMOVE%...
    "!ARG_VENV_NAME!\Scripts\pip.exe" uninstall -y "%ARG_DEP_TO_REMOVE%"
    if !ERRORLEVEL! neq 0 ( echo [ERRO] Falha ao desinstalar o pacote. >&2 & exit /b 1 )

    if defined ARG_DEPS_FILE (
        if exist "%ARG_DEPS_FILE%" (
            echo [INFO] A remover "%ARG_DEP_TO_REMOVE%" do ficheiro %ARG_DEPS_FILE%...
            findstr /i /L /v /x /c:"%ARG_DEP_TO_REMOVE%" "%ARG_DEPS_FILE%" > "%ARG_DEPS_FILE%.tmp"
            move /y "%ARG_DEPS_FILE%.tmp" "%ARG_DEPS_FILE%" >nul
        )
    )
    echo Pacote desinstalado e removido com sucesso.
    exit /b 0

:MODE_REBUILD
    if not defined ARG_VENV_NAME ( echo [ERRO] O modo --rebuild requer o parametro --venv. >&2 & exit /b 1 )

    echo A reconstruir o ambiente...
    if exist "%ARG_VENV_NAME%" (
        echo [INFO] A remover o ambiente virtual antigo...
        rmdir /s /q "%ARG_VENV_NAME%"
    )
    
    echo [INFO] A limpar caches Python ^(.pyc, __pycache__^)...
    for /r %%i in (*.pyc) do ( if exist "%%i" del "%%i" )
    for /r /d %%i in (__pycache__) do ( if exist "%%i" rmdir /s /q "%%i" )

    if "%ARG_NO_CACHE%"=="true" (
        echo [INFO] A limpar o cache do pip...
        if exist "%LOCALAPPDATA%\pip\cache" rmdir /s /q "%LOCALAPPDATA%\pip\cache"
    )

    call :ENSURE_VENV_AND_INSTALL
    if !ERRORLEVEL! neq 0 exit /b 1

    echo Ambiente reconstruido com sucesso.
    exit /b 0

:HELP
    if not exist "%~dp0..\helpers\dependency_manager_pip_help.txt" ( echo [ERRO] Ficheiro de ajuda nao encontrado. >&2 & exit /b 1 )
    type "%~dp0..\helpers\dependency_manager_pip_help.txt"
    exit /b 0

:USAGE
    echo. >&2 & echo Uso: %~n0 [modo] [parametros] >&2 & echo Para mais informacoes, use: %~n0 --help >&2 & exit /b 1

:: ============================================================================
:: --- FUNCOES DE LOGICA INTERNA ---
:: ============================================================================

:ENSURE_VENV_AND_INSTALL
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
                set "PIP_INSTALL_CMD=!ARG_VENV_NAME!\Scripts\pip.exe install -r ""%ARG_DEPS_FILE%"""
                if "%ARG_NO_CACHE%"=="true" set "PIP_INSTALL_CMD=!PIP_INSTALL_CMD! --no-cache-dir"
                
                !PIP_INSTALL_CMD!
                if !ERRORLEVEL! neq 0 ( echo [AVISO] Ocorreram erros durante a instalacao das dependencias. >&2 )
            )
        )
    )
    exit /b 0
goto :EOF

