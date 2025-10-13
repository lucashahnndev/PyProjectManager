@echo off
setlocal enabledelayedexpansion

:: ============================================================================
::                PROJECT STARTER CORE (`start_app_core.bat`)
:: ============================================================================
:: Este script e o motor de execucao para um projeto pypm.
::
:: Responsabilidades:
:: 1. Limpar o ambiente de execucao.
:: 2. Ler as configuracoes do projeto (`pypm` e `pypm.local`).
:: 3. Usar `python_manager.bat` para garantir a versao correta do Python.
:: 4. Delegar a preparacao do ambiente ao gestor de dependencias apropriado.
:: 5. Executar a acao final solicitada pelo utilizador.
:: ============================================================================


:: --- 2. Carregar Configuracoes e Analisar Comando ---
set "COMMAND_MODE=%~1"

rem (Restante do analisador de comandos e help...)
if /i "%COMMAND_MODE%"=="--help" goto :HELP
if /i "%COMMAND_MODE%"=="-h" goto :HELP
if /i "%COMMAND_MODE%"=="-?" goto :HELP
if /i "%COMMAND_MODE%"=="/?" goto :HELP


:: --- 1. Limpeza do Ambiente ---
TITLE Project Starter Core
echo Limpando ambiente da sessao atual...
set "pypm_shell_path=%~dp0"
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


set "CONFIG_DIR=.pypm"
set "CONFIG_FILE=%CONFIG_DIR%\pypm"
set "LOCAL_CONFIG_FILE=%CONFIG_DIR%\pypm.local"

if not exist "!CONFIG_FILE!" (
    echo [ERRO] Ficheiro de configuracao do projeto ^(`%CONFIG_FILE%`^) nao encontrado. >&2
    pause & exit /b 1
)

for /f "usebackq tokens=1,* delims==" %%a in ("%CONFIG_FILE%") do (
    set "%%a=%%b"
)
if exist "%LOCAL_CONFIG_FILE%" (
    for /f "usebackq tokens=1,* delims==" %%a in ("%LOCAL_CONFIG_FILE%") do (set "%%a=%%b")
)
TITLE Project (%PROJECT_NAME%)
echo Projeto: %PROJECT_NAME%

:: --- 3. Garantir o Python Correto ---
echo A verificar o ambiente Python...
call "!pypm_shell_path!\python_manager.bat" --get --version "%PYTHON_VERSION%" --path "%PYTHON_PATH%"
if !ERRORLEVEL! neq 0 (
    echo [ERRO] Nao foi possivel obter um Python compativel com a versao %PYTHON_VERSION%. >&2
    pause & exit /b 1
)
set /p FINAL_PYTHON_EXE=<"%TEMP%\.pypm\pypm_py_return.tmp"
echo Python a ser usado: %FINAL_PYTHON_EXE%

:: --- 4. DELEGAR a Preparacao do Ambiente ---
echo A preparar o ambiente de dependencias com o motor: %DEPENDENCY_ENGINEER%...
set "VENV_PATH=%CD%\%CONFIG_DIR%\%VENV%"
set "DEPS_FILE=%CD%\requirements.txt"

if /i "!PYTHON_PATH!" neq "!FINAL_PYTHON_EXE!" (
    echo O executavel Python foi alterado. Reconstruindo o ambiente...
    if /i "%DEPENDENCY_ENGINEER%"=="pip" (
        (
            echo PYTHON_PATH=!FINAL_PYTHON_EXE!
            echo EXEC_DIR=!EXEC_DIR!
            echo PROJECT_DIR=!PROJECT_DIR!
            echo deps_installed=False
        )>!LOCAL_CONFIG_FILE!
        call "!pypm_shell_path!\dependency_manager_pip.bat" --rebuild --python-exe "!FINAL_PYTHON_EXE!" --project-dir "%CD%" --venv "!VENV_PATH!" --deps-file "!DEPS_FILE!"
    ) else (
        rem logica para poetry
    )
) else if /i "%COMMAND_MODE%"=="--rebuild" (
    if /i "%DEPENDENCY_ENGINEER%"=="pip" (
        call "!pypm_shell_path!\dependency_manager_pip.bat" --rebuild --python-exe "!FINAL_PYTHON_EXE!" --project-dir "%CD%" --venv "!VENV_PATH!" --deps-file "!DEPS_FILE!"
    ) else (
        rem logica para poetry
    )
) else if /i "%COMMAND_MODE%"=="--add-dep" (
    rem Nao faz nada aqui, sera tratado na secao 5
) else (
    rem Execucao padrao "smart"
    if /i "%DEPENDENCY_ENGINEER%"=="pip" (
        call "!pypm_shell_path!\dependency_manager_pip.bat" --ensure-env --python-exe "!FINAL_PYTHON_EXE!" --project-dir "%CD%" --venv "!VENV_PATH!" --deps-file "!DEPS_FILE!" --deps-installed "!deps_installed!"
    ) else (
        rem logica para poetry
    )
)
if !ERRORLEVEL! neq 0 ( echo [ERRO] Falha ao preparar o ambiente. >&2 & pause & exit /b 1 )
echo Ambiente pronto.


:: --- 5. Analisador de Comandos e Execucao ---
shift
set "COMMAND_ARGS=%*"
echo.
echo ============================================================================

if /i "%COMMAND_MODE%"=="--shell" (
    if /i "%DEPENDENCY_ENGINEER%"=="pip" (
        echo "!pypm_shell_path!dependency_manager_pip.bat"
        call "!pypm_shell_path!dependency_manager_pip.bat" --shell --python-exe "!FINAL_PYTHON_EXE!" --project-dir "%CD%" --venv "!VENV_PATH!"
    ) else (
        rem logica para poetry
    )
    exit /b
)

if /i "%COMMAND_MODE%"=="--add-dep" (
    if not defined COMMAND_ARGS ( echo [ERRO] O modo --add-dep requer um pacote para adicionar. >&2 & pause & exit /b 1 )
    if /i "%DEPENDENCY_ENGINEER%"=="pip" (
        call "!pypm_shell_path!\dependency_manager_pip.bat" --add-dep "!COMMAND_ARGS!" --python-exe "!FINAL_PYTHON_EXE!" --project-dir "%CD%" --venv "!VENV_PATH!" --deps-file "!DEPS_FILE!"
    ) else (
        rem logica para poetry
    )
    exit /b
)

rem (Restante dos comandos: --run, --python-shell, etc.)
if /i "%COMMAND_MODE%"=="--python-shell" (
    echo [INFO] Ambiente preparado. Executando !FINAL_PYTHON_EXE!
    "!FINAL_PYTHON_EXE!"
) else if /i "%COMMAND_MODE%"=="--run" (
    if /i "%~1"=="" (
        echo [INFO] Ambiente preparado. Nenhum comando de execucao fornecido.
    ) else (
        echo [INFO] Ambiente preparado. Executando comando --run %~1 %~2 %~3 %~4
        "!FINAL_PYTHON_EXE!" %~1 %~2 %~3 %~4
    )
) else if /i not "%COMMAND_MODE%"=="--rebuild" (
    echo [ERRO] Comando desconhecido: %COMMAND_MODE%
)

:: pause
goto :EOF

:HELP
    if not exist "!pypm_shell_path!..\helpers\start_app_core_help.txt" ( echo [ERRO] Ficheiro de ajuda nao encontrado. >&2 & exit /b 1 )
    type "!pypm_shell_path!..\helpers\start_app_core_help.txt"
    exit /b 0

endlocal

