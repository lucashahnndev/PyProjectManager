@echo off
setlocal enabledelayedexpansion
set "this_module=%~n0"
:: ============================================================================
::                PYPM v2.0 - O ROTEADOR DE COMANDOS
:: ============================================================================
:: v2 com sistema de logging externo (log_util.bat).
:: Default Log Level: 1 (WARN), para operar silenciosamente.
:: ============================================================================

:: --- 1. CONFIGURACAO DE CAMINHOS E LOGGING ---
set "ORIGINAL_DIR=%CD%"
set "PYPM_DIR=%~dp0"
set "PYPM_SHELL_SRC=%PYPM_DIR%shell_src\"
set "PYPM_PROJ_DIR=%PYPM_DIR%python_src\"
set "DB_WORKER_SCRIPT=%PYPM_PROJ_DIR%\db_manager.py"
set "INIT_WORKER_SCRIPT=%PYPM_PROJ_DIR%init_project.py"
set "CORE_RUNNER=%PYPM_SHELL_SRC%start_app_core.bat"
set "LOG_UTIL_SCRIPT=%PYPM_SHELL_SRC%\log_util.bat"

:: Niveis de verbosidade
set "LOG_LEVEL_ERROR=0"
set "LOG_LEVEL_WARN=1"
set "LOG_LEVEL_INFO=2"
set "LOG_LEVEL_DEBUG=3"

:: Nivel padrao "Quiet" (WARN), conforme solicitado.
set "LOG_LEVEL_NUM=1"
set "LOG_ARGS_FOR_MODULES="
set "ARGS_FOR_ROUTER="

:: Limpa variaveis de resultado
set "TARGET_DIR="
set "COMMAND_RESULT="

:: --- 2. PRE-ANALISE DE ARGUMENTOS (Para Log) ---
:: Este loop separa as flags de log dos comandos.
:PARSE_LOG_ARGS_LOOP
if "%~1"=="" goto :PARSE_LOG_ARGS_END
if /i "%~1"=="--quiet" ( set "LOG_LEVEL_NUM=0" & set "LOG_ARGS_FOR_MODULES=--quiet" & shift & goto :PARSE_LOG_ARGS_LOOP )
if /i "%~1"=="-q" ( set "LOG_LEVEL_NUM=0" & set "LOG_ARGS_FOR_MODULES=--quiet" & shift & goto :PARSE_LOG_ARGS_LOOP )
if /i "%~1"=="--verbose" ( set "LOG_LEVEL_NUM=3" & set "LOG_ARGS_FOR_MODULES=--verbose" & shift & goto :PARSE_LOG_ARGS_LOOP )
if /i "%~1"=="-v" ( set "LOG_LEVEL_NUM=3" & set "LOG_ARGS_FOR_MODULES=--verbose" & shift & goto :PARSE_LOG_ARGS_LOOP )
if /i "%~1"=="--log-level" ( set "LOG_LEVEL_NUM=%~2" & set "LOG_ARGS_FOR_MODULES=--log-level %~2" & shift & shift & goto :PARSE_LOG_ARGS_LOOP )

:: Se nao for uma flag de log, reconstroi a lista de argumentos para o Roteador
if defined ARGS_FOR_ROUTER ( set "ARGS_FOR_ROUTER=!ARGS_FOR_ROUTER! %1" ) else ( set "ARGS_FOR_ROUTER=%1" )
shift
goto :PARSE_LOG_ARGS_LOOP
:PARSE_LOG_ARGS_END

:: --- 3. ANALISE PRINCIPAL DE ARGUMENTOS ---
:: Use ARGS_FOR_ROUTER para a logica do roteador
for /f "tokens=1,2" %%i in ("%ARGS_FOR_ROUTER%") do (
    set "ARG1=%%i"
    set "ARG2=%%j"
)

if "%ARG1%"=="" goto :HELP

:: ============================================================================
::                FLUXO DE ROTEAMENTO (ROADMAP.MD - SECAO 1)
:: ============================================================================

:: --- MODO 1: COMANDOS GLOBAIS (O 'pypm' e o alvo) ---
if /i "%ARG1%"=="init" goto :HANDLE_INIT
if /i "%ARG1%"=="list" goto :HANDLE_LIST
if /i "%ARG1%"=="python" goto :HANDLE_PYTHON
if /i "%ARG1%"=="edit" goto :HANDLE_EDIT
if /i "%ARG1%"=="deploy" goto :HANDLE_DEPLOY
if /i "%ARG1%"=="help" goto :HELP
if /i "%ARG1%"=="/?" goto :HELP
if /i "%ARG1%"=="-h" goto :HELP

:: --- MODOS 2/3: CONTEXTO OU ALVO ---

:: --- MODO 2: COMANDO DE CONTEXTO (O 'Diretorio Atual' e o alvo) ---
if exist "%CD%\.pypm\" (
    call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "INFO" "!this_module!" "Projeto detectado em %CD%"
    set "PROJECT_DIR=%CD%"
    :: Passa as flags de log E os argumentos do roteador para o core
    call "%CORE_RUNNER%" %LOG_ARGS_FOR_MODULES% %ARGS_FOR_ROUTER%
    goto :SUCCESS
)

:: --- MODO 3: COMANDO DE ALVO (Um 'Projeto Especifico' e o alvo) ---
call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "INFO" "!this_module!" "Procurando pelo alvo '%ARG1%'..."
call :FIND_PROJECT_DIR "%ARG1%"

if "!TARGET_DIR!"=="" (
    call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "ERROR" "Nao foi encontrado um projeto no diretorio atual."
    call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "ERROR" "E '%ARG1%' nao e um nome de projeto valido."
    echo.
    call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "INFO" "!this_module!" "Para executar um comando aqui, primeiro crie um projeto com:"
    echo        pypm init
    call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "INFO" "!this_module!" "Ou especifique o nome de um projeto existente:"
    echo        pypm ^<nome-do-projeto^> %~2
    goto :FAILURE
)

call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "INFO" "!this_module!" "Alvo '%ARG1%' encontrado em: !TARGET_DIR!"
set "PROJECT_DIR=!TARGET_DIR!"

:: Remove o ARG1 (nome do alvo) dos argumentos do roteador
set "REMAINING_ARGS="
for /f "tokens=1,*" %%i in ("%ARGS_FOR_ROUTER%") do (
    set "REMAINING_ARGS=%%j"
)

cd /d "%PROJECT_DIR%"
call "%CORE_RUNNER%" %LOG_ARGS_FOR_MODULES% %REMAINING_ARGS%
cd /d "%ORIGINAL_DIR%"
goto :SUCCESS


:: ============================================================================
::                HANDLERS DOS COMANDOS GLOBAIS
:: ============================================================================

:HANDLE_INIT
    call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "DEBUG" "!this_module!" "Modo: INIT"

    :: Remove 'init' dos argumentos
    set "REMAINING_ARGS="
    for /f "tokens=1,*" %%i in ("%ARGS_FOR_ROUTER%") do (
        set "REMAINING_ARGS=%%j"
    )

    call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "INFO" "!this_module!" "Iniciando worker de configuracao em %ORIGINAL_DIR%..."

    :: Chama o worker init_worker.py, passando quaisquer argumentos
    :: (ex: --name, --python) que o usuário possa ter fornecido.
    call :RUN_PYPM_WORKER "%INIT_WORKER_SCRIPT%" --project_dir="%ORIGINAL_DIR%" %REMAINING_ARGS%
    goto :SUCCESS

:HANDLE_LIST
    call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "DEBUG" "!this_module!" "Modo: LIST"
    call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "INFO" "!this_module!" "Buscando lista de projetos no banco de dados..."
    :: Passa as flags de log do usuario para o worker
    call :RUN_PYPM_WORKER "%DB_WORKER_SCRIPT%" list
    goto :SUCCESS

:HANDLE_PYTHON
    call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "DEBUG" "!this_module!" "Modo: PYTHON MANAGER"
    :: Remove 'python' dos argumentos
    set "REMAINING_ARGS="
    for /f "tokens=1,*" %%i in ("%ARGS_FOR_ROUTER%") do (
        set "REMAINING_ARGS=%%j"
    )
    :: Passa as flags de log E os argumentos restantes para o python_manager
    call "%PYPM_SHELL_SRC%python_manager.bat" %LOG_ARGS_FOR_MODULES% %REMAINING_ARGS%
    goto :SUCCESS

:HANDLE_EDIT
    call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "DEBUG" "!this_module!" "Modo: EDIT"
    call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "DEBUG" "!this_module!" "[STUB] Logica de edicao"
    goto :SUCCESS

:HANDLE_DEPLOY
    call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "DEBUG" "!this_module!" "Modo: DEPLOY"
    call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "DEBUG" "!this_module!" "[STUB] Logica de deploy"
    goto :SUCCESS

:HELP
    call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "DEBUG" "!this_module!" "Exibindo Ajuda..."
    :: (Logica para mostrar o pypm_help.txt global)
    goto :SUCCESS

:: ============================================================================
::                SUB-ROTINAS DO ROTEADOR
:: ============================================================================

:FIND_PROJECT_DIR
    :: Esta funcao consulta o DB (via worker) para encontrar o diretorio
    set "TARGET_DIR="
    set "TARGET_TO_FIND=%~1"

    call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "DEBUG" "!this_module!" "Consultando DB para: %TARGET_TO_FIND%"

    :: Captura a saida do worker Python (que da 'print' no caminho)
    for /f "delims=" %%i in ('call :RUN_PYPM_WORKER_FOR_OUTPUT "%DB_WORKER_SCRIPT%" get %TARGET_TO_FIND%') do (
        set "COMMAND_RESULT=%%i"
    )

    :: Se a saida contiver [ERROR], falhou
    if not "!COMMAND_RESULT!"=="!COMMAND_RESULT:[DB_MANAGER_ERROR]=!" (
        set "TARGET_DIR="
        goto :EOF
    )

    set "TARGET_DIR=!COMMAND_RESULT!"
    goto :EOF

:: ----------------------------------------------------------------------------
::                A CHAMADA OUROBOROS (WORKER EXEC)
:: ----------------------------------------------------------------------------

:RUN_PYPM_WORKER
    :: Executa um worker python (ex: list) passando as flags de log do USUARIO.
    call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "DEBUG" "!this_module!" "Executando Worker: %*"
    cd /d "%PYPM_PROJ_DIR%"
    call "%CORE_RUNNER%" %LOG_ARGS_FOR_MODULES% --run %*
    cd /d "%ORIGINAL_DIR%"
    goto :EOF

:RUN_PYPM_WORKER_FOR_OUTPUT
    :: Executa um worker (ex: get) e FORCA o --quiet para capturar
    :: uma saida limpa (o caminho do diretorio).
    call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "DEBUG" "!this_module!" "Executando Worker (Modo Output): %*"

    cd /d "%PYPM_PROJ_DIR%"
    :: Forca --quiet, independentemente das flags do usuario
    call "%CORE_RUNNER%" --quiet --run %*
    cd /d "%ORIGINAL_DIR%"
    goto :EOF


:: ============================================================================
::                PONTOS DE SAIDA
:: ============================================================================
:SUCCESS
    cd /d "%ORIGINAL_DIR%"
    endlocal
    exit /b 0

:FAILURE
    cd /d "%ORIGINAL_DIR%"
    endlocal
    exit /b 1
