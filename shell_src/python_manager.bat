@echo off
setlocal enabledelayedexpansion
set "this_module=%~n0"
:: ============================================================================
::                PYTHON MANAGER CORE (`python_manager.bat`)
:: ============================================================================
:: v2 com sistema de logging externo (log_util.bat).
::
:: Comunicacao de Retorno:
:: - Sucesso: Devolve o(s) resultado(s) para o ficheiro %TEMP%\.pypm\pypm_py_return.tmp
::           e termina com codigo de saida 0.
:: - Falha:   Usa o log_util.bat para stderr e termina com codigo de saida 1.
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
set "ARG_VERSION="
set "ARG_PATH="
set "pypm_TEMP=%TEMP%\.pypm"
if not exist "%pypm_TEMP%" mkdir "%pypm_TEMP%"
set "PY_CACHE_FILE=%pypm_TEMP%\python_versions.dat"
set "RETURN_FILE=%pypm_TEMP%\pypm_py_return.tmp"
del "%RETURN_FILE%" 2>nul

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
if /i "%~1"=="--get" set "MODE=GET"
if /i "%~1"=="--list" set "MODE=LIST"
if /i "%~1"=="-l" set "MODE=LIST"
if /i "%~1"=="--install" set "MODE=INSTALL"
if /i "%~1"=="--help" goto :HELP
if /i "%~1"=="-h" goto :HELP
if /i "%~1"=="-?" goto :HELP
if /i "%~1"=="/?" goto :HELP

if /i "%~1"=="--version" ( set "ARG_VERSION=%~2" & shift )
if /i "%~1"=="-v" ( set "ARG_VERSION=%~2" & shift )
if /i "%~1"=="--path" ( set "ARG_PATH=%~2" & shift )
if /i "%~1"=="-p" ( set "ARG_PATH=%~2" & shift )

shift
goto :PARSE_ARGS_LOOP

:DISPATCH
if not defined MODE goto :USAGE
if "%MODE%"=="GET" goto :MODE_GET
if "%MODE%"=="LIST" goto :MODE_LIST
if "%MODE%"=="INSTALL" goto :MODE_INSTALL
goto :USAGE

:: ============================================================================
:: --- FLUXOS DE MODO ---
:: ============================================================================

:MODE_GET
    if not defined ARG_VERSION (
        call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "ERROR" "!this_module!"  "O modo --get requer um parametro --version <versao>."
        goto :USAGE
    )
    call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "DEBUG" "!this_module!"  "A garantir que uma versao do Python compativel com '%ARG_VERSION%' esta disponivel..."

    rem 1. Se um caminho foi passado, valida-o primeiro (cache do projeto).
    if defined ARG_PATH (
        call :VALIDATE_PYTHON_PATH "!ARG_PATH!" "%ARG_VERSION%"
        if !ERRORLEVEL! equ 0 (
            call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "DEBUG" "!this_module!"  "Python validado com sucesso a partir do caminho do projeto: !ARG_PATH!"
            > "%RETURN_FILE%" echo !ARG_PATH!
            exit /b 0
        )
        call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "DEBUG" "!this_module!"  "O caminho em cache do projeto '!ARG_PATH!' e invalido. A procurar no sistema..."
    )

    rem 2. Procura por um Python compativel no sistema usando o cache auto-reparavel.
    call :SCAN_AND_POPULATE_ARRAYS
    call :FIND_PYTHON_BY_VERSION "%ARG_VERSION%"
    if !ERRORLEVEL! equ 0 (
        call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "DEBUG" "!this_module!"  "Python compativel encontrado no sistema: !FOUND_PYTHON_PATH!"
        > "%RETURN_FILE%" echo !FOUND_PYTHON_PATH!
        exit /b 0
    )

    rem 3. Se nada foi encontrado, instala-o.
    call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "WARN" "!this_module!"  "Nenhum Python compativel encontrado. A iniciar processo de instalacao..."
    call :INSTALL_PYTHON "%ARG_VERSION%"
    if !ERRORLEVEL! neq 0 (
        call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "ERROR" "!this_module!"  "Falha ao instalar o Python^."
        exit /b 1
    )
    
    call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "INFO" "!this_module!"  "Python instalado com sucesso em: !INSTALLED_PYTHON_PATH!"
    > "%RETURN_FILE%" echo !INSTALLED_PYTHON_PATH!
    exit /b 0

:MODE_LIST
    call :SCAN_AND_POPULATE_ARRAYS
    if %py_count% equ 0 (
        call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "WARN" "!this_module!"  "Nenhum Python encontrado no sistema."
        exit /b 0
    )
    call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "DEBUG" "!this_module!"  "Lista de Pythons encontrados:"
    (for /l %%i in (1,1,%py_count%) do (
        echo !py_version[%%i]!;!py_path[%%i]!
    )) > "%RETURN_FILE%"
    
    :: Se o log for INFO ou superior, imprime a lista no console.
    if %LOG_LEVEL_NUM% GEQ 2 type "%RETURN_FILE%"
    exit /b 0

:MODE_INSTALL
    if not defined ARG_VERSION (
        call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "ERROR" "!this_module!"  "O modo --install requer um parametro --version <versao>."
        goto :USAGE
    )
    call :INSTALL_PYTHON "%ARG_VERSION%" "%ARG_PATH%"
    if !ERRORLEVEL! neq 0 (
        call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "ERROR" "!this_module!"  "Falha ao instalar o Python."
        exit /b 1
    )
    > "%RETURN_FILE%" echo !INSTALLED_PYTHON_PATH!
    exit /b 0

:HELP
    if not exist "%~dp0..\helpers\python_manager_help.txt" (
        call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "ERROR" "!this_module!"  "Ficheiro de ajuda 'python_manager_help.txt' nao encontrado."
        exit /b 1
    )
    type "%~dp0..\helpers\python_manager_help.txt"
    exit /b 0

:USAGE
    echo. >&2
    call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "INFO" "!this_module!"  "Uso: !this_module! [modo] [parametros]" >&2
    call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "INFO" "!this_module!"  "Para mais informacoes, use: !this_module! --help" >&2
    exit /b 1

:: ============================================================================
:: --- FUNCOES DE LOGICA INTERNA ---
:: ============================================================================

:SCAN_AND_POPULATE_ARRAYS
    set /a py_count=0
    set "cache_updated=false"
    
    rem Logica de cache auto-reparavel
    if exist "%PY_CACHE_FILE%" (
        (for /f "usebackq tokens=1,2 delims=;" %%a in ("%PY_CACHE_FILE%") do (
            call :VALIDATE_PYTHON_PATH "%%b" "%%a"
            if !ERRORLEVEL! equ 0 (
                rem A entrada e valida, adiciona ao array na memoria e mantem para a proxima escrita do cache
                set /a py_count+=1
                set "py_version[!py_count!]=%%a"
                set "py_path[!py_count!]=%%b"
                 echo %%a;%%b
            ) else (
                rem A entrada e invalida, marca o cache para atualizacao
                call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "DEBUG" "!this_module!"  "A remover entrada de cache invalida: %%b"
                set "cache_updated=true"
            )
        )) > "%PY_CACHE_FILE%.tmp"
        move /y "%PY_CACHE_FILE%.tmp" "%PY_CACHE_FILE%" >nul
    )

    rem Logica de scan do registro para encontrar novos Pythons
    for %%R in (HKLM HKCU) do ( for /f "delims=" %%K in ('reg query "%%R\SOFTWARE\Python\PythonCore" 2^>nul') do ( for /f "tokens=*" %%V in ('reg query "%%K" 2^>nul ^| findstr /r "[0-9]\.[0-9]"') do ( for /f "tokens=2,*" %%A in ('reg query "%%V\InstallPath" /ve 2^>nul') do ( set "current_path=%%B\python.exe" & set "is_new=true" & (for /l %%i in (1,1,!py_count!) do ( if /i "!py_path[%%i]!"=="!current_path!" set "is_new=false" )) & if "!is_new!"=="true" if exist "!current_path!" ( (for /f "tokens=2" %%v in ('"!current_path!" --version 2^>^&1') do set "version_str=%%v") & set /a py_count+=1 & set "py_version[!py_count!]=!version_str!" & set "py_path[!py_count!]=!current_path!" & set "cache_updated=true" ) ) ) ) )

    rem [NOVO] Logica de scan do PATH para encontrar ainda mais Pythons
    call :SEARCH_PATH_FOR_PYTHON

    rem Apenas escreve no cache se algo mudou
    if "%cache_updated%"=="true" (
        call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "DEBUG" "!this_module!"  "A atualizar o ficheiro de cache de Pythons..."
        >"%PY_CACHE_FILE%" (
            for /l %%i in (1,1,%py_count%) do (
                echo !py_version[%%i]!;!py_path[%%i]!
            )
        )
    )
goto :EOF

:SEARCH_PATH_FOR_PYTHON
    call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "DEBUG" "!this_module!"  "A procurar por 'python.exe' no PATH do sistema..."
    for %%X in (python.exe) do (
        for /f "delims=" %%p in ('where %%X 2^>nul') do (
            set "current_path=%%p"
            set "is_new=true"
            rem Verifica se este caminho ja esta no nosso array
            for /l %%i in (1,1,!py_count!) do (
                 if /i "!py_path[%%i]!"=="!current_path!" set "is_new=false"
            )
            if "!is_new!"=="true" (
                if exist "!current_path!" (
                    rem E novo, obtem a versao e adiciona-o
                    (for /f "tokens=2" %%v in ('"!current_path!" --version 2^>^&1') do set "version_str=%%v")
                    if defined version_str (
                        call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "DEBUG" "!this_module!"  "Nova versao encontrada no PATH: !current_path!"
                        set /a py_count+=1
                        set "py_version[!py_count!]=!version_str!"
                        set "py_path[!py_count!]=!current_path!"
                        set "cache_updated=true"
                    )
                )
            )
        )
    )
goto :EOF

:VALIDATE_PYTHON_PATH
    set "path_to_validate=%~1"
    set "version_to_match=%~2"
    if not exist "%path_to_validate%" exit /b 1
    for /f "tokens=2" %%v in ('"%path_to_validate%" --version 2^>^&1') do (
         echo "%%v" | findstr /R /C:^%version_to_match% >nul
        if !ERRORLEVEL! equ 0 (
            exit /b 0
        ) else (
            exit /b 1
        )
    )
    exit /b 1
goto :EOF

:FIND_PYTHON_BY_VERSION
    set "required_version=%~1"
    set "FOUND_PYTHON_PATH="
    rem NOTA: Esta logica so suporta correspondencia de prefixo (ex: "3.11" corresponde a "3.11.9").
    for /l %%i in (1,1,%py_count%) do (
        echo "!py_version[%%i]!" | findstr /R /C:^%required_version% >nul
        if !ERRORLEVEL! equ 0 (
            set "FOUND_PYTHON_PATH=!py_path[%%i]!"
            goto :EOF
        )
    )
    exit /b 1
goto :EOF

:INSTALL_PYTHON
    set "PY_VERSION=%~1"
    set "INSTALL_DIR=%~2"
    set "INSTALLED_PYTHON_PATH="
    set "install_result=1"
     
    set "temp_version=%PY_VERSION%"
    set "temp_version=%temp_version:.= %"
    set /a dot_count=0
    for %%w in (%temp_version%) do set /a dot_count+=1
    if not %dot_count% equ 3 (
        call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "ERROR" "!this_module!"  "Para instalacao, e necessario especificar uma versao completa ex^:^ 3^.^11^.^9 .^"
        call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "ERROR" "!this_module!"  "A versao fornecida '%PY_VERSION%' e invalida para download."
        ::goto :EOF
        exit /b 1
    )
    
    if not defined INSTALL_DIR set "INSTALL_DIR=%SystemDrive%\Python\Python%PY_VERSION:.=%"
    
    rem [NOVO] Verifica a arquitetura do sistema para escolher o instalador correto.
    set "ARCH_SUFFIX="
    if defined ProgramFiles(x86) set "ARCH_SUFFIX=-amd64"
    
    set "PY_INSTALLER_FILENAME=python-%PY_VERSION%%ARCH_SUFFIX%.exe"
    set "INSTALLER_CACHE_DIR=%pypm_TEMP%\python_cache"
    if not exist "%INSTALLER_CACHE_DIR%" mkdir "%INSTALLER_CACHE_DIR%"
    set "PY_INSTALLER_PATH=%INSTALLER_CACHE_DIR%\%PY_INSTALLER_FILENAME%"
    set "PY_URL=https://www.python.org/ftp/python/%PY_VERSION%/%PY_INSTALLER_FILENAME%"

    if not exist "%PY_INSTALLER_PATH%" (
        call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "INFO" "!this_module!"  "A baixar o instalador de %PY_URL%..."
        powershell -Command "Invoke-WebRequest -Uri '%PY_URL%' -OutFile '%PY_INSTALLER_PATH%'"
    ) else (
        call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "INFO" "!this_module!"  "A utilizar o instalador ja existente em cache."
    )

    if not exist "%PY_INSTALLER_PATH%" ( call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "ERROR" "!this_module!"  "Falha ao baixar o instalador." & goto :EOF )
    
    call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "INFO" "!this_module!"  "A instalar para todos os utilizadores em '%INSTALL_DIR%'..."
    "%PY_INSTALLER_PATH%" /passive InstallAllUsers=1 Include_pip=1 TargetDir="%INSTALL_DIR%"
    if !ERRORLEVEL! neq 0 ( call "!LOG_UTIL_SCRIPT!" %LOG_LEVEL_NUM% "ERROR" "!this_module!"  "A instalacao falhou." & del "%PY_INSTALLER_PATH%" 2>nul & goto :EOF )

    rem Nao apaga o instalador para que possa ser reutilizado
    set "INSTALLED_PYTHON_PATH=%INSTALL_DIR%\python.exe"
    set "install_result=0"
goto :EOF