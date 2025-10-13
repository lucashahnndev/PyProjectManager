@echo off
setlocal enabledelayedexpansion

:: ============================================================================
::                SUITE DE TESTES PARA OS MODULOS DO PYPM
:: ============================================================================
:: Este script executa uma serie de testes para validar a funcionalidade
:: dos modulos `python_manager.bat` e `dependency_manager_pip.bat`.
::
:: COMO USAR:
:: 1. Coloque este ficheiro na raiz do seu projeto PyProjectManager.
:: 2. Execute-o a partir do terminal.
:: ============================================================================

:: --- CONFIGURACAO DO AMBIENTE DE TESTE ---
set "TEST_DIR=test_env"
set "PYTHON_MANAGER=..\shell_src\python_manager.bat"
set "DEP_MANAGER_PIP=..\shell_src\dependency_manager_pip.bat"
set "PYTHON_FOR_TESTS="

if exist "%TEST_DIR%" (
    echo A limpar ambiente de teste antigo...
    rmdir /s /q "%TEST_DIR%"
)
mkdir "%TEST_DIR%"
cd "%TEST_DIR%"

set "START_TIME=%TIME%"
echo ======================================================
echo           INICIANDO SUITE DE TESTES DO PYPM
echo ======================================================
echo.

:: ============================================================================
::                TESTES PARA `python_manager.bat`
:: ============================================================================
echo ----------------------------------------------
echo       TESTANDO: python_manager.bat
echo ----------------------------------------------

rem NOTA: Usamos 'start /b /wait cmd /c' em vez de 'call' para que o 'exit /b'
rem nos scripts de modulo nao termine a suite de testes prematuramente.

rem Teste 1: Comando --help
start "" /b /wait cmd /c ""%PYTHON_MANAGER%" --help > nul"
call :ASSERT "python_manager: --help funciona" 0 %ERRORLEVEL%

rem Teste 2: Comando --list
start "" /b /wait cmd /c ""%PYTHON_MANAGER%" --list > nul"
call :ASSERT "python_manager: --list executa com sucesso" 0 %ERRORLEVEL%
if exist "%TEMP%\.pypm\pypm_py_return.tmp" ( call :ASSERT "python_manager: --list cria ficheiro de retorno" 0 0 ) else ( call :ASSERT "python_manager: --list cria ficheiro de retorno" 0 1 )

rem Teste 3: Comando --get para uma versao que provavelmente existe
start "" /b /wait cmd /c ""%PYTHON_MANAGER%" --get --version 3 > nul"
call :ASSERT "python_manager: --get encontra Python 3 existente" 0 %ERRORLEVEL%
if %ERRORLEVEL% equ 0 set /p PYTHON_FOR_TESTS=<"%TEMP%\.pypm\pypm_py_return.tmp"

rem Teste 4: Comando --get para uma versao que nao existe (forca a instalacao)
echo.
echo [INFO] O proximo teste pode demorar, pois ira baixar e instalar o Python 3.8.10...
start "" /b /wait cmd /c ""%PYTHON_MANAGER%" --get --version 3.8.10 > nul"
call :ASSERT "python_manager: --get instala versao inexistente" 0 %ERRORLEVEL%
echo.

rem Teste 5: Comando --install
echo [INFO] O proximo teste pode reutilizar o instalador em cache...
start "" /b /wait cmd /c ""%PYTHON_MANAGER%" --install --version 3.9.13 --path "%CD%\py39" > nul"
call :ASSERT "python_manager: --install executa com sucesso" 0 %ERRORLEVEL%
if exist "%CD%\py39\python.exe" ( call :ASSERT "python_manager: --install cria o diretorio correto" 0 0 ) else ( call :ASSERT "python_manager: --install cria o diretorio correto" 0 1 )
echo.


:: ============================================================================
::                TESTES PARA `dependency_manager_pip.bat`
:: ============================================================================
echo ----------------------------------------------
echo       TESTANDO: dependency_manager_pip.bat
echo ----------------------------------------------

if not defined PYTHON_FOR_TESTS (
    echo [AVISO] A saltar testes do dependency_manager pois nenhum Python foi encontrado para os testes.
    goto :END_TESTS
)

rem --- Setup para os testes de dependencias ---
mkdir my_project
set "PROJECT_DIR=%CD%\my_project"
set "VENV_NAME=test_venv"

rem Teste 6: Comando --help
start "" /b /wait cmd /c ""%DEP_MANAGER_PIP%" --help > nul"
call :ASSERT "dep_manager_pip: --help funciona" 0 %ERRORLEVEL%

rem Teste 7: --rebuild (primeira criacao do venv e instalacao)
set "DEPS_FILE_7=%CD%\req_rebuild.txt"
echo Flask > "%DEPS_FILE_7%"
start "" /b /wait cmd /c ""%DEP_MANAGER_PIP%" --rebuild --python-exe "%PYTHON_FOR_TESTS%" --project-dir "%PROJECT_DIR%" --venv "%VENV_NAME%" --deps-file "%DEPS_FILE_7%" > nul"
call :ASSERT "dep_manager_pip: --rebuild cria venv e instala deps" 0 %ERRORLEVEL%
if exist "%PROJECT_DIR%\%VENV_NAME%\Scripts\pip.exe" ( call :ASSERT "dep_manager_pip: venv foi criado corretamente" 0 0 ) else ( call :ASSERT "dep_manager_pip: venv foi criado corretamente" 0 1 )

rem Teste 8: --add-dep
set "DEPS_FILE_8=%CD%\req_add.txt"
(echo # Ficheiro de teste para add-dep) > "%DEPS_FILE_8%"
start "" /b /wait cmd /c ""%DEP_MANAGER_PIP%" --add-dep requests --python-exe "%PYTHON_FOR_TESTS%" --project-dir "%PROJECT_DIR%" --venv "%VENV_NAME%" --deps-file "%DEPS_FILE_8%" > nul"
call :ASSERT "dep_manager_pip: --add-dep executa com sucesso" 0 %ERRORLEVEL%
findstr /i "requests" "%DEPS_FILE_8%" >nul
call :ASSERT "dep_manager_pip: --add-dep atualiza requirements.txt" 0 %ERRORLEVEL%

rem Teste 9: --remove-dep
set "DEPS_FILE_9=%CD%\req_remove.txt"
(echo click) > "%DEPS_FILE_9%"
(echo requests) >> "%DEPS_FILE_9%"
start "" /b /wait cmd /c ""%DEP_MANAGER_PIP%" --remove-dep requests --python-exe "%PYTHON_FOR_TESTS%" --project-dir "%PROJECT_DIR%" --venv "%VENV_NAME%" --deps-file "%DEPS_FILE_9%" > nul"
call :ASSERT "dep_manager_pip: --remove-dep executa com sucesso" 0 %ERRORLEVEL%
findstr /i "requests" "%DEPS_FILE_9%" >nul
if %ERRORLEVEL% equ 0 ( call :ASSERT "dep_manager_pip: --remove-dep remove do requirements.txt" 1 0 ) else ( call :ASSERT "dep_manager_pip: --remove-dep remove do requirements.txt" 1 1 )

rem Teste 10: --rebuild --no-cache
set "DEPS_FILE_10=%CD%\req_rebuild_nocache.txt"
echo colorama > "%DEPS_FILE_10%"
start "" /b /wait cmd /c ""%DEP_MANAGER_PIP%" --rebuild --no-cache --python-exe "%PYTHON_FOR_TESTS%" --project-dir "%PROJECT_DIR%" --venv "%VENV_NAME%" --deps-file "%DEPS_FILE_10%" > nul"
call :ASSERT "dep_manager_pip: --rebuild --no-cache executa" 0 %ERRORLEVEL%

echo.

:END_TESTS
:: --- LIMPEZA DO AMBIENTE ---
cd ..
if exist "%TEST_DIR%" (
    echo A limpar ambiente de teste...
    rmdir /s /q "%TEST_DIR%"
)

set "END_TIME=%TIME%"
echo ======================================================
echo           SUITE DE TESTES CONCLUIDA
echo           Inicio: %START_TIME%
echo           Fim:    %END_TIME%
echo ======================================================

goto :EOF

:: ============================================================================
:: --- FUNCOES AUXILIARES ---
:: ============================================================================
:ASSERT
    set "TEST_NAME=%~1"
    set "EXPECTED_EC=%~2"
    set "ACTUAL_EC=%~3"
    set "PADDING=........................................................"
    set "TEST_NAME_PADDED=%TEST_NAME% !PADDING!"
    set "TEST_NAME_PADDED=!TEST_NAME_PADDED:~0,50!"

    if "%ACTUAL_EC%"=="%EXPECTED_EC%" (
        echo [PASS] !TEST_NAME_PADDED!
    ) else (
        echo [FAIL] !TEST_NAME_PADDED! (Esperado: %EXPECTED_EC%, Recebido: %ACTUAL_EC%)
    )
goto :EOF

endlocal

