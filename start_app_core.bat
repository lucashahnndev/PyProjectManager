@echo off
TITLE Project Starter Core
echo Limpando ambiente da sessao atual...
setlocal enabledelayedexpansion
set before=init
goto :CLEAR_python_vars

:CLEAR_python_vars
:: --------------------------------------------------------
:: 1. CRIA UM AMBIENTE LOCAL E LIMPO PARA O SCRIPT
:: --------------------------------------------------------
:: Limpando variaveis relacionadas ao Python
set PYTHONPATH=
set PYTHONHOME=
set PYTHONSTARTUP=
set PYTHONNOUSERSITE=
set PIP_CONFIG_FILE=
set PIP_REQUIRE_VIRTUALENV=
set PIP_USER=
set PIP_CACHE_DIR=

:: Limpar entradas do PATH que contenham Python ou Scripts globais
for %%i in ("%PATH:;=" "%") do (
    echo %%i | findstr /i "Python" >nul
    if !ERRORLEVEL! neq 0 (
        rem Adiciona ao PATH temporário se não tiver Python
        if defined NEWPATH (
            set "NEWPATH=!NEWPATH!;%%~i"
        ) else (
            set "NEWPATH=%%~i"
        )
    )
)

rem Substitui PATH original pelo filtrado
set "PATH=%NEWPATH%"
echo PATH atualizado:
IF /i "%before%"=="venv" goto :venv2
goto :MAIN

:MAIN
:: --------------------------------------------------------
:: Arquivo de configuração
:: --------------------------------------------------------
set "CONFIG_FILE=pypm.ini"

if not exist "%CONFIG_FILE%" (
    echo ERRO: Arquivo de configuracao %CONFIG_FILE% nao encontrado.
    echo Execute o gerenciador global para criar a configuracao.
    pause
    exit /b
)

:: --------------------------------------------------------
:: Carregar configuração do INI
:: --------------------------------------------------------
for /f "tokens=1,* delims==" %%a in (%CONFIG_FILE%) do (
    set "%%a=%%b"
)
TITLE Project (%PROJECT_NAME%)

:: --------------------------------------------------------
:: 1. VERIFICA PYTHON
:: --------------------------------------------------------
echo.
echo Verificando se o Python selecionado esta disponivel...
"!PYTHON_PATH!" --version >nul 2>nul
IF %ERRORLEVEL% NEQ 0 (
    echo ERRO: Python nao encontrado em "!PYTHON_PATH!".
    pause
    exit /b
)
set PATH=!path!;"!PYTHON_PATH!"
"!PYTHON_PATH!" python -m ensurepip >nul 2>&1
pip install --upgrade pip setuptools wheel >nul 2>&1
echo Python encontrado em "!PYTHON_PATH!"!

:: --------------------------------------------------------
:: 2. DIRETORIO DE EXECUCAO
:: --------------------------------------------------------
cd /d "%EXEC_DIR%"
echo Diretorio de execucao: %cd%
goto :venv

:venv
:: --------------------------------------------------------
:: 4. CRIAR/ATIVAR VENV
:: --------------------------------------------------------
if /i "%USE_VENV%"=="S" (
    if not exist "venv" (
        echo Criando ambiente virtual...
        "!PYTHON_PATH!" -m venv venv
        "!PYTHON_PATH!" -m pip install --upgrade pip

    )
    :: Antes de ativar, salvar PATH e Python do venv
    set "VENV_PYTHON=%CD%\venv\Scripts\python.exe"
    set "VENV_PATH=%CD%\venv\Scripts"

    echo Ativando venv...
    call "venv\Scripts\activate.bat"
    set before=venv
    goto :venv2
)

:venv2
    set "PYTHONPATH="
    set "PYTHONHOME="
    set "PATH=%VENV_PATH%;%PATH%"
    echo Venv ativado com sucesso!




:: -------------------------------------
:: Tratamento de argumentos
:: -------------------------------------
if /i "%~1"=="/open_python" goto :OPEN_PYTHON
if /i "%~1"=="/open_cmd" goto :OPEN_CMD
if /i "%~1"=="/install_dep" goto :INSTALL_DEP
if /i "%~1"=="/open_dir" goto :OPEN_DIR
if "%~1"=="" goto :INSTALL_DEP

:OPEN_PYTHON
:: --------------------------------------------------------
:: Abrir instancia python
:: --------------------------------------------------------
echo.
echo =======================================================
echo Abrindo instancia python:
echo =======================================================
python
exit /b


:OPEN_CMD
:: --------------------------------------------------------
:: Abrir instancia CMD
:: --------------------------------------------------------

echo =======================================================
echo Abrindo instancia cmd:
echo =======================================================
:SANDBOX_PROMPT
set ifenv=""
::IF /i %use_venv%==s set ifenv=(%PROJECT_NAME%_VENV)
::set /p USER_CMD="%ifenv%!cd!> "
::if /i "%USER_CMD%"=="exit" goto :EOF
::cmd /c "%USER_CMD%"
::goto :SANDBOX_PROMPT
call cmd
exit /b

:OPEN_DIR
:: --------------------------------------------------------
:: Abrir diretorio do projeto
:: --------------------------------------------------------
echo.
echo ======================================================
echo Abrindo o diretorio  no explorador de arquivo
echo ======================================================
echo %PROJECT_DIR%
echo.
echo ------------------------------------------------------
echo
start "%PROJECT_DIR%"
exit /b


:: --------------------------------------------------------
:: 4. INSTALAR DEPENDENCIAS (CORRIGIDO)
:: --------------------------------------------------------
:INSTALL_DEP
:: Apaga o log antigo para começar um novo
if exist "installation_log.txt" ( del "installation_log.txt" )
set installed=false
if exist "requirements.txt" (
    if /i "%~1"=="/install_dep" (
        if "%INSTALL_MODE%" neq "3" (
            echo Forcando a reinstalacao de todas as dependencias^...
            for /f "usebackq delims=" %%p in ("requirements.txt") do (
                echo.
                echo +++ Instalando/Atualizando: "%%p" +++
                pip install --no-cache-dir --force-reinstall --upgrade "%%p"

                if !ERRORLEVEL! equ 0 (
                    echo [SUCESSO] - %%p >> installation_log.txt
                ) else (
                    echo [FALHA]   - %%p >> installation_log.txt
                )
            )
            set installed=true
        )
    ) else (
        if "%INSTALL_MODE%"=="1" (
            echo Verificando e instalando dependencias ^(^modo: Sempre^)^...
            for /f "usebackq delims=" %%p in ("requirements.txt") do (
                echo.
                echo +++ Instalando: "%%p" +++
                pip install "%%p"
                    if !ERRORLEVEL! equ 0 (
                    echo [SUCESSO] - %%p >> installation_log.txt
                ) else (
                    echo [FALHA]   - %%p >> installation_log.txt
                )
            )
            set installed=true
        ) else (
            if "%INSTALL_MODE%"=="2" (
                if /i "%deps_installed%"=="False"  (
                    echo Instalando dependencias pela primeira vez^...
                    for /f "usebackq delims=" %%p in ("requirements.txt") do (
                        echo.
                        echo +++ Instalando: "%%p" +++
                        pip install --no-cache-dir --force-reinstall --upgrade "%%p"
                        if !ERRORLEVEL! equ 0 (
                            echo [SUCESSO] - %%p >> installation_log.txt
                        ) else (
                            echo [FALHA]   - %%p >> installation_log.txt
                        )
                    )
                    set installed=true
                )
            )
        )
    )
    if /i !installed!==true (
                    echo PROJECT_NAME=!PROJECT_NAME!
                    echo PYTHON_PATH=!PYTHON_PATH!
                    echo EXEC_DIR=!EXEC_DIR!
                    echo PROJECT_DIR=!PROJECT_DIR!
                    echo USE_VENV=!USE_VENV!
                    echo INSTALL_MODE=!INSTALL_MODE!
                    echo FINAL_CMD=!FINAL_CMD!
                    echo USE_LOG_FILE=!USE_LOG_FILE!
                    echo USE_LOG_ROTATION=!USE_LOG_ROTATION!
                    echo deps_installed=True
    )> ".project_config.ini"
) else (
    echo Nenhum arquivo requirements.txt encontrado, pulando instalacao.
)

if /i "%~1"=="/install_dep" (
    exit /b
) else (
    goto :END_COMMAND
)


:END_COMMAND
:: --------------------------------------------------------
:: 5. EXECUTAR COMANDO FINAL
:: --------------------------------------------------------
echo.
echo =======================================================
echo Executando comando final:
echo !FINAL_CMD!
echo =======================================================
%FINAL_CMD%

endlocal

