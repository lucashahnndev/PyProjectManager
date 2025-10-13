
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