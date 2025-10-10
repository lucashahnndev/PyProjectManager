@echo off
setlocal enabledelayedexpansion
TITLE Python Project Manager

:: -------------------------------------
:: Arquivos de controle
:: -------------------------------------
set "DB_FILE=%~dp0projects.csv"
set "CONFIG_FILE=project_config.ini"
set "START_SCRIPT=start_app.bat"
set "CORE_SCRIPT=start_app_core.bat"

:: -------------------------------------
:: Tratamento de argumentos
:: -------------------------------------
if /i "%~1"=="/?" goto :HELP
if /i "%~1"=="/help" goto :HELP
if /i "%~1"=="/list" goto :LIST
if /i "%~1"=="/clear" goto :CLEAR
if /i "%~1"=="/install_python" goto :INSTALL_PYTHON
if /i "%~1"=="/add_python" goto :ADD_PYTHON_MANUAL

:: Comandos que exigem um identificador (ID ou Nome)
if /i "%~1"=="/remove" goto :HANDLE_COMMAND_WITH_ID
if /i "%~1"=="/edit" goto :HANDLE_COMMAND_WITH_ID
if /i "%~1"=="/view" goto :HANDLE_COMMAND_WITH_ID
if /i "%~1"=="/rebuild" goto :HANDLE_COMMAND_WITH_ID
if /i "%~1"=="/start" goto :HANDLE_COMMAND_WITH_ID
if /i "%~1"=="/open_dir" goto :HANDLE_COMMAND_WITH_ID
if /i "%~1"=="/prompt" goto :HANDLE_COMMAND_WITH_ID
if /i "%~1"=="/py_prompt" goto :HANDLE_COMMAND_WITH_ID
if /i "%~1"=="/install_dep" goto :HANDLE_COMMAND_WITH_ID


:: -------------------------------------
:: Criar novo projeto ou editar existente
:: -------------------------------------
if exist "%CONFIG_FILE%" (
    echo Projeto ja possui configuracao: %CONFIG_FILE%
    set /p resp="Deseja reconfigurar? (S/N): "
    if /i "%resp%"=="S" goto :CONFIG_PROJECT
    goto :ASK_RUN
) else (
    goto :CONFIG_PROJECT
)

:: ==========================================================
:HELP
type "%~dp0help.txt"
exit /b

:: ==========================================================
:LIST
if not exist "%DB_FILE%" (
    echo Nenhum projeto registrado ainda.
    exit /b
)

echo =================================================================================
echo                              PROJETOS REGISTRADOS
echo =================================================================================
echo ID ^| NOME                 ^| DATA E HORA           ^| DIRETORIO
echo ---------------------------------------------------------------------------------
set /a id=0

for /f "usebackq skip=1 tokens=1-7 delims=;" %%a in ("%DB_FILE%") do (
    set /a id+=1
    set "name=%%a"
    set "date=%%b"
    set "exec_dir=%%c"
    rem Adiciona espacos para alinhar a coluna
    set "name_padded=!name!                  "
    set "name_padded=!name_padded:~0,20!"
    echo !id! ^| !name_padded! ^| !date! ^| !exec_dir!
)

echo ---------------------------------------------------------------------------------
echo Total: !id! projeto^(s^)
exit /b

:: ==========================================================
:CLEAR
if exist "%DB_FILE%" del "%DB_FILE%" >nul 2>nul
echo Registro limpo.
exit /b

:: ==========================================================
:: BLOCO PARA LIDAR COM COMANDOS QUE USAM ID/NOME
:: ==========================================================
:HANDLE_COMMAND_WITH_ID
set "COMMAND=%~1"
set "IDENTIFIER=%~2"
if "%IDENTIFIER%"=="" (
    echo Uso: pyproj %COMMAND% ^<id_ou_nome^>
    exit /b
)
if not exist "%DB_FILE%" (
    echo Nenhum registro encontrado.
    exit /b
)

:: Chama a funcao de busca
call :FIND_PROJECT "%IDENTIFIER%"
if "!project_found!"=="false" (
    echo Projeto com ID ou Nome '!IDENTIFIER!' nao encontrado.
    exit /b
)

:: Redireciona para o comando correto apos encontrar o projeto
if /i "%COMMAND%"=="/remove" goto :REMOVE
if /i "%COMMAND%"=="/edit" goto :EDIT
if /i "%COMMAND%"=="/view" goto :VIEW
if /i "%COMMAND%"=="/rebuild" goto :REBUILD
if /i "%COMMAND%"=="/start" goto :START
if /i "%COMMAND%"=="/prompt" goto :START
if /i "%COMMAND%"=="/open_dir" goto :START
if /i "%COMMAND%"=="/py_prompt" goto :START
if /i "%COMMAND%"=="/install_dep" goto :START
exit /b


:: ==========================================================
:: FUNCAO DE BUSCA DE PROJETO (POR ID OU NOME)
:: ==========================================================
:FIND_PROJECT
set "lookup=%~1"
set "project_found=false"
set /a current_id=0

:: ATENCAO: tokens aumentados para 1-10 para incluir os novos campos de log
for /f "usebackq skip=1 tokens=1-10 delims=;" %%a in ("%DB_FILE%") do (
    set /a current_id+=1
    set "line_name=%%a"
    set "project_found=false"
    if /i "!line_name!"=="%lookup%" (
        set "found_id=!current_id!"
        set "project_found=true"
    ) else if "!current_id!"=="%lookup%" (
        set "found_id=!current_id!"
        set "project_found=true"
    )

    if "!project_found!"=="true" (
            set "PROJECT_NAME=%%a"
            set "PROJECT_DATE=%%b"
            set "EXEC_DIR=%%c"
            set "PYTHON_PATH=%%d"
            set "PROJECT_DIR=%%e"
            set "use_venv=%%f"
            set "install_mode=%%g"
            set "final_cmd=%%h"
            set "use_log_file=%%i"
            set "use_log_rotation=%%j"
            set "project_found=true"
        goto :EOF
    )
)

endlocal & (
    set project_found=false
)
goto :EOF

:: ==========================================================
:REMOVE
> "%DB_FILE%.tmp" (
    echo Name;Date;Exec_dir;Python_path;Project_dir;Use_venv;Install_mode;Final_cmd;Use_log_file;Use_log_rotation
    set /a id=0
    for /f "usebackq skip=1 tokens=*" %%a in ("%DB_FILE%") do (
        set /a id+=1
        if not !id!==%found_id% echo %%a
    )
)
del "%PROJECT_DIR%\%CONFIG_FILE%" >nul 2>nul
del "%PROJECT_DIR%\%START_SCRIPT%" >nul 2>nul
move /y "%DB_FILE%.tmp" "%DB_FILE%" >nul
echo Projeto '%PROJECT_NAME%' (ID: %found_id%) removido.
exit /b

:: ==========================================================
:VIEW
echo.
echo Visualizando projeto: %PROJECT_NAME% (ID: %found_id%)
echo ------------------------------------------
echo PROJECT_NAME:      %PROJECT_NAME%
echo PYTHON_PATH:       %PYTHON_PATH%
echo EXEC_DIR:          %EXEC_DIR%
echo PROJECT_DIR:       %PROJECT_DIR%
echo USE_VENV:          %use_venv%
echo INSTALL_MODE:      %install_mode%
echo FINAL_CMD:         !final_cmd!
echo USE_LOG_FILE:      %use_log_file%
echo USE_LOG_ROTATION:  %use_log_rotation%
echo ------------------------------------------
exit /b

:: ==========================================================
:EDIT
goto :Edit_Menu

:: ==========================================================
:Edit_Menu
:: cls
echo.
echo Editando projeto: %PROJECT_NAME% (ID: %found_id%)
echo ------------------------------------------
echo [0] - Nome do Projeto:    %PROJECT_NAME%
echo [1] - Python:             %PYTHON_PATH%
echo [2] - Diretorio:          %EXEC_DIR%
echo [3] - Ambiente virtual:   %use_venv%
echo [4] - Modo de instalacao: %install_mode%
echo [5] - Comando final:      !final_cmd!
echo [6] - Configurar Log:     Log [%use_log_file%], Rotacao [%use_log_rotation%]
echo ------------------------------------------
echo [7] - Salvar e Sair
echo [8] - Sair sem Salvar

set /p choice="Escolha uma opcao: "
if "%choice%"=="0" goto :Edit_Name
if "%choice%"=="1" goto :Edit_Python
if "%choice%"=="2" goto :Edit_Exec_Dir
if "%choice%"=="3" goto :Edit_Use_Venv
if "%choice%"=="4" goto :Edit_Install_Mode
if "%choice%"=="5" goto :Edit_Final_Cmd
if "%choice%"=="6" goto :Edit_Log
if "%choice%"=="7" goto :SAVE
if "%choice%"=="8" exit /b
goto :Edit_Menu

:: ==========================================================
:CONFIG_PROJECT
echo =======================================================
echo Configuracao inicial do projeto
echo =======================================================
:: Define valores padrao para novos projetos
set "use_log_file=N"
set "use_log_rotation=N"
goto :Edit_Name

:: ----------------------------
:Edit_Name
echo.
if defined PROJECT_NAME (
    echo Nome atual: %PROJECT_NAME%
)
set /p PROJECT_NAME="Digite o nome do projeto (sem espacos ou caracteres especiais): "
if not defined COMMAND goto :Edit_Python
goto :Edit_Menu

:: ==========================================================
:: BLOCO DE DETECCAO E SELECAO DE PYTHON
:: ==========================================================
:Edit_Python
echo.
if /i "%~1"=="/edit" (
    echo Configuracao atual do projeto: %PYTHON_PATH%
)
echo Detectando instalacoes Python...

:: --- Bloco setlocal para evitar que variáveis vazem
setlocal enabledelayedexpansion
set "PY_CACHE_FILE=%~dp0python_versions.csv"
set /a count=0
set "cache_updated=false"

:: Limpa arrays antigos
for /l %%i in (1,1,99) do (
    set "py_version[%%i]="
    set "py_path[%%i]="
)

:: --- CARREGAR E VALIDAR CACHE ---
if exist "%PY_CACHE_FILE%" (
    echo Validando versoes salvas...
    >"%PY_CACHE_FILE%.tmp" (
        for /f "usebackq tokens=1,2 delims=;" %%a in ("%PY_CACHE_FILE%") do (
            if exist "%%b" (
                set /a count+=1
                set "py_version[!count!]=%%a"
                set "py_path[!count!]=%%b"
                echo %%a;%%b
            ) else (
                echo Removendo entrada invalida: %%b
                set "cache_updated=true"
            )
        )
    )
    if exist "%PY_CACHE_FILE%.tmp" (
        move /y "%PY_CACHE_FILE%.tmp" "%PY_CACHE_FILE%" >nul
    )
)

:: --- DETECTAR NOVAS VERSOES VIA REGISTRO ---
echo Verificando Registro do Windows por novas instalacoes...
for %%R in (HKLM HKCU) do (
    for /f "delims=" %%K in ('reg query "%%R\SOFTWARE\Python\PythonCore" 2^>nul') do (
        set "py_key=%%K"
        if /i not "!py_key!"=="!py_key:PythonCore=!" (
            for /f "tokens=*" %%V in ('reg query "!py_key!" 2^>nul ^| findstr /r "[0-9]\.[0-9]"') do (
                set "version_key=%%V"
                for /f "tokens=2,*" %%A in ('reg query "!version_key!\InstallPath" /ve 2^>nul') do (
                    set "current_path=%%B\python.exe"
                    set "is_new=true"
                    for /l %%i in (1,1,!count!) do (
                        if /i "!py_path[%%i]!"=="!current_path!" (
                            set "is_new=false"
                        )
                    )
                    if "!is_new!"=="true" (
                        if exist "!current_path!" (
                            echo Nova versao encontrada: !current_path!
                            for /f "tokens=2" %%v in ('"!current_path!" --version 2^>^&1') do (
                                set "version_str=%%v"
                            )
                            set /a count+=1
                            set "py_version[!count!]=!version_str!"
                            set "py_path[!count!]=!current_path!"
                            set "cache_updated=true"
                        )
                    )
                )
            )
        )
    )
)

:: --- SALVAR CACHE ATUALIZADO ---
if "%cache_updated%"=="true" (
    echo Atualizando arquivo de cache de versoes...
    >"%PY_CACHE_FILE%" (
        for /l %%i in (1,1,%count%) do (
            echo !py_version[%%i]!;!py_path[%%i]!
        )
    )
)

:Display_Python_List
if %count%==0 (
    echo.
    echo Nenhuma instalacao do Python foi encontrada.
)

:: --- EXIBIR LISTA ORDENADA PARA O USUARIO ---
echo.
echo Pythons disponiveis (ordenado por versao):
echo -----------------------------------------------------------------

set /a display_count=0
if %count% gtr 0 (
    >"%TEMP%\py_list.tmp" (
        for /l %%i in (1,1,%count%) do (
            echo !py_version[%%i]! -- !py_path[%%i]!
        )
    )
    for /f "delims=" %%L in ('sort /r "%TEMP%\py_list.tmp"') do (
        set /a display_count+=1
        set "display_line[!display_count!]=%%L"
        echo  [^!display_count!^] - %%L
    )
    del "%TEMP%\py_list.tmp" >nul 2>nul
)
echo -----------------------------------------------------------------
echo  [A] - Adicionar um novo caminho manualmente
echo -----------------------------------------------------------------

set /p choice="Escolha o Python a usar [1-%display_count% ou A]: "
if /i "%choice%"=="A" goto :Handle_Manual_Python_Entry_Interactive
if not defined choice goto :Edit_Python
if %choice% equ 0 goto :Edit_Python
if %choice% GTR %display_count% (
    echo Opcao invalida.
    goto :Edit_Python
)

:: --- Extrai o path da linha escolhida
for /f "tokens=3" %%P in ("!display_line[%choice%]!") do (
    set "PYTHON_PATH=%%P"
)

endlocal & (
    set "PYTHON_PATH=%PYTHON_PATH%"
)

if defined COMMAND goto :Edit_Menu
goto :Edit_Exec_Dir


:: --- SUB-ROTINA PARA LIDAR COM A ENTRADA MANUAL INTERATIVA ---
:Handle_Manual_Python_Entry_Interactive
echo.
set /p manual_path="Digite o caminho completo para o python.exe: "
call :ADD_PYTHON_MANUAL_SUB "%manual_path%"
goto :Edit_Python


:: ----------------------------
:Edit_Exec_Dir
echo.
echo Diretorio de execucao atual: %EXEC_DIR%
echo Diretorio do script: %cd%
set /p use_current="Usar este diretorio? (S/N): "
if /i "%use_current%"=="N" (
    set /p EXEC_DIR="Informe o diretorio completo: "
) else (
    set "EXEC_DIR=%cd%"
)
if defined COMMAND goto :Edit_Menu
goto :Edit_Use_Venv

:: ----------------------------
:Edit_Use_Venv
echo.
echo Usar VENV atual: %use_venv%
set /p use_venv="Deseja usar ambiente virtual (venv)? (S/N): "
if defined COMMAND goto :Edit_Menu
goto :Edit_Install_Mode

:: ----------------------------
:Edit_Install_Mode
echo.
echo Modo de instalacao atual: %install_mode%
if exist "%EXEC_DIR%\requirements.txt" (
    echo Arquivo requirements.txt encontrado.
    echo Automatizar instalacao de dependencias:
    echo [1] Sempre
    echo [2] Apenas na primeira vez
    echo [3] Nunca
    set /p install_mode="Escolha o modo de instalacao [1-3]: "
) else (
    echo Nenhum requirements.txt encontrado. A instalacao nao sera automatizada.
    set "install_mode=3"
)
if defined COMMAND goto :Edit_Menu
goto :Edit_Log


:: ----------------------------
:: NOVA SECAO DE CONFIGURACAO DE LOG
:: ----------------------------
:Edit_Log
echo.
echo Configuracao de Log
echo -------------------
echo Log em arquivo: %use_log_file%
echo Rotacao de Log: %use_log_rotation%
echo.
set /p use_log_file="Deseja salvar a saida em um arquivo de log? (S/N): "
if /i not "%use_log_file%"=="S" (
    set "use_log_rotation=N"
    if not defined COMMAND goto :Edit_Final_Cmd
    goto :Edit_Menu
)
set /p use_log_rotation="Deseja rotacionar o arquivo de log a cada execucao? (S/N): "
if not defined COMMAND goto :Edit_Final_Cmd
goto :Edit_Menu

:: ----------------------------
:Edit_Final_Cmd
echo.
echo Comando final atual: !final_cmd!
set /p final_cmd="Digite o comando a executar (ex: python main.py): "
if defined COMMAND goto :Edit_Menu
goto :SAVE

:SAVE
:: ----------------------------
:: SALVAR .INI E DB
:: ----------------------------
echo.
echo Salvando nova configuracao...
(
    echo PROJECT_NAME=%PROJECT_NAME%
    echo PYTHON_PATH=%PYTHON_PATH%
    echo EXEC_DIR=%EXEC_DIR%
    echo PROJECT_DIR=%EXEC_DIR%
    echo USE_VENV=%use_venv%
    echo INSTALL_MODE=%install_mode%
    echo FINAL_CMD=!final_cmd!
    echo USE_LOG_FILE=%use_log_file%
    echo USE_LOG_ROTATION=%use_log_rotation%
    echo deps_installed=False
) > "%EXEC_DIR%\%CONFIG_FILE%"
(

    echo @echo off
    echo setlocal enabledelayedexpansion
    echo echo Iniciando projeto '%PROJECT_NAME%'...
    echo if not "%%~1"=="" ^(
    echo     echo Parametro detectado: %%~1
    echo     call "%~dp0%CORE_SCRIPT%" "%%~1"
    echo     exit /b
    echo ^)
) > "%EXEC_DIR%\%START_SCRIPT%"

if /i not "%USE_LOG_FILE%"=="S" (
    (
        echo call "%~dp0%CORE_SCRIPT%" "%%~1"
    ) >> "%EXEC_DIR%\%START_SCRIPT%"
) else (

    (
        echo IF NOT EXIST "%EXEC_DIR%\LOGS\"  mkdir "%EXEC_DIR%\LOGS\"
        echo set LOG_FILE=%EXEC_DIR%\LOGS\%PROJECT_NAME%.log
    if /i "%USE_LOG_ROTATION%"=="S" (
        echo        SET YYYY=%%date:~6,4%%
        echo        SET MM=%%date:~3,2%%
        echo        SET DD=%%date:~0,2%%
        echo        SET HH=%%time:~0,2%%
        echo        SET MIN=%%time:~3,2%%
        echo        SET SEG=%%time:~6,2%%
        echo        set "LOG_FILE=%EXEC_DIR%\LOGS\%PROJECT_NAME%-%%YYYY%%-%%MM%%-%%DD%%_%%HH%%-%%MIN%%-%%SEG%%.log"
    )
        echo echo Redirecionando toda a saida para o arquivo de log:
        echo echo %%LOG_FILE%%
        echo call "%~dp0%CORE_SCRIPT%" "%%~1" ^>^>  "%%LOG_FILE%%" 2^>^&1
    ) >> "%EXEC_DIR%\%START_SCRIPT%"
)



if not exist "%DB_FILE%" (
    echo Name;Date;Exec_dir;Python_path;Project_dir;Use_venv;Install_mode;Final_cmd;Use_log_file;Use_log_rotation > "%DB_FILE%"
)
set "NOW=%date% %time:~0,8%"
set /a id=0
if defined COMMAND (
    >"%DB_FILE%.tmp" (
        for /f "usebackq delims=" %%a in ("%DB_FILE%") do (
            if "!id!"=="%found_id%" (
                echo %PROJECT_NAME%;%NOW%;%EXEC_DIR%;%PYTHON_PATH%;%PROJECT_DIR%;%use_venv%;%install_mode%;!final_cmd!;%use_log_file%;%use_log_rotation%
            ) else (
                echo %%a
            )
            set /a id+=1
        )
    )
    move /y "%DB_FILE%.tmp" "%DB_FILE%" >nul
) else (
    >>"%DB_FILE%" echo %PROJECT_NAME%;%NOW%;%EXEC_DIR%;%PYTHON_PATH%;%EXEC_DIR%;%use_venv%;%install_mode%;!final_cmd!;%use_log_file%;%use_log_rotation%
)

echo.
echo Configuracao para '%PROJECT_NAME%' salva com sucesso!
goto :ASK_RUN

:: ==========================================================
:ASK_RUN
set /p runnow="Deseja iniciar o projeto agora? (S/N): "
if /i "%runnow%"=="S" (
    cd /d "%PROJECT_DIR%"
    call "%START_SCRIPT%"
)
exit /b

:: ==========================================================
:START
cd /d "%PROJECT_DIR%"
if exist "%START_SCRIPT%" (
    if "%COMMAND%"=="/start" (
        call "%START_SCRIPT%"
    ) else if "%COMMAND%"=="/prompt" (
        call "%START_SCRIPT%" /open_cmd
    ) else if "%COMMAND%"=="/open_dir" (
        echo.
        echo ======================================================
        echo Abrindo o diretorio  no explorador de arquivo
        echo ======================================================
        echo %PROJECT_DIR%
        echo.
        echo ------------------------------------------------------
        echo.
        start "" "%PROJECT_DIR%"
    ) else if "%COMMAND%"=="/py_prompt" (
        call "%START_SCRIPT%" /open_python
    ) else if "%COMMAND%"=="/install_dep" (
        call "%START_SCRIPT%" /install_dep
    )
) else (
    echo ERRO: %START_SCRIPT% nao encontrado em %PROJECT_DIR%
)
exit /b

:: ==========================================================
:REBUILD
cd /d "%PROJECT_DIR%"
if exist "venv" (
    echo Limpando ambiente virtual do projeto '%PROJECT_NAME%'...
    rmdir /s /q "venv"
    echo Ambiente virtual limpo.
) else (
    echo Nenhum ambiente virtual 'venv' para reconstruir.
)
echo Limpando caches Python antigos...
set count=0
for /r %%i in (*.pyc) do (
    del "%%i" >nul 2>nul
    set /a count+=1
    echo deletando %%i
    echo Arquivos deletados: !count!
)
echo Limpeza concluída!
echo Reconstruindo ambiente...
call "%START_SCRIPT%" /install_dep
echo Ambiente reconstruido com sucesso.
exit /b

:: ==========================================================
:: FUNCOES PARA ADICIONAR PYTHON MANUALMENTE
:: ==========================================================

:ADD_PYTHON_MANUAL
setlocal
set "PYTHON_EXE_PATH=%~2"
if not defined PYTHON_EXE_PATH (
    echo ERRO: Forneca o caminho completo para o python.exe.
    echo Uso: pyproj /add_python "C:\caminho\python.exe"
    exit /b 1
)
call :ADD_PYTHON_MANUAL_SUB "%PYTHON_EXE_PATH%"
exit /b 0

:ADD_PYTHON_MANUAL_SUB
setlocal
set "PYTHON_EXE_PATH=%~1"
set "PY_CACHE_FILE=%~dp0python_versions.csv"
set "CLEAN_PATH=%PYTHON_EXE_PATH:"=%"

if /i not "%CLEAN_PATH:~-10%"=="python.exe" (
    echo ERRO: O caminho fornecido deve terminar com "python.exe".
    pause
    goto :EOF
)
if not exist "%CLEAN_PATH%" (
    echo ERRO: Arquivo nao encontrado: "%CLEAN_PATH%"
    pause
    goto :EOF
)
if exist "%PY_CACHE_FILE%" (
    for /f "usebackq tokens=2 delims=;" %%a in ("%PY_CACHE_FILE%") do (
        if /i "%%a"=="%PYTHON_EXE_PATH%" (
            echo Este Python ja esta registrado. Nenhuma acao necessaria.
            pause
            goto :EOF
        )
    )
)
echo Validando executavel...
"%PYTHON_EXE_PATH%" --version > "%TEMP%\pyver.tmp" 2>&1
findstr /i /c:"Python" "%TEMP%\pyver.tmp" >nul
if errorlevel 1 (
    echo ERRO: Nao foi possivel obter uma versao valida do Python.
    del "%TEMP%\pyver.tmp" >nul 2>nul
    pause
    goto :EOF
)
for /f "tokens=2" %%v in ('type "%TEMP%\pyver.tmp"') do (
    set "version_str=%%v"
)
del "%TEMP%\pyver.tmp" >nul 2>nul

if not defined version_str (
    echo ERRO: Falha ao extrair o numero da versao.
    pause
    goto :EOF
)

echo %version_str%;%PYTHON_EXE_PATH%>>"%PY_CACHE_FILE%"
echo Python '%version_str%' adicionado com sucesso ao cache!
pause
goto :EOF

:: ==========================================================
:INSTALL_PYTHON
:: -------------------------------
:: Instalador Python via CLI automatizado
:: -------------------------------
set "PY_VERSION=%~2"
if "%PY_VERSION%"=="" set "PY_VERSION=3.12.1"
set "ALL_USERS=%~3"
if "%ALL_USERS%"=="" set "ALL_USERS=1"
set "TARGET_DIR=%~4"
if "%TARGET_DIR%"=="" set "TARGET_DIR=C:\Python%PY_VERSION:.=%"
set "PY_INSTALLER=python-%PY_VERSION%-amd64.exe"
set "PY_URL=https://www.python.org/ftp/python/%PY_VERSION%/%PY_INSTALLER%"

echo ======================================================
echo Instalacao automatizada do Python %PY_VERSION%
echo ======================================================
if not exist "%PY_INSTALLER%" (
    powershell -Command "Invoke-WebRequest -Uri '%PY_URL%' -OutFile '%PY_INSTALLER%'"
)
if not exist "%PY_INSTALLER%" (
    echo ERRO: Falha ao baixar o instalador.
    exit /b 1
)
if "%ALL_USERS%"=="prompt" (
    set /p ALL_USERS="Instalar para todos os usuarios? (S/N): "
    if /i "%ALL_USERS%"=="S" set ALL_USERS=1
    if /i "%ALL_USERS%"=="N" set ALL_USERS=0
)
"%PY_INSTALLER%" /passive InstallAllUsers=%ALL_USERS% PrependPath=1 Include_pip=1 TargetDir="%TARGET_DIR%"
if %ERRORLEVEL% neq 0 (
    echo ERRO: Instalacao falhou.
    exit /b %ERRORLEVEL%
)
echo ======================================================
echo Python %PY_VERSION% instalado com sucesso em %TARGET_DIR%
echo ======================================================
del "%PY_INSTALLER%"
exit /b

