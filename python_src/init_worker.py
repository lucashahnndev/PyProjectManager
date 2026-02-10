import sys
import argparse
import os
import subprocess
import tempfile
from pathlib import Path
from dataclasses import dataclass
from typing import List, Tuple, Optional

# Importa o DatabaseManager
try:
    from db_manager import DatabaseManager
except ImportError:
    print(f"[INIT_WORKER_ERROR] Falha ao importar 'db_manager.py'.", file=sys.stderr)
    sys.exit(1)


@dataclass
class ProjectConfig:
    """Guarda os resultados do menu interativo"""
    name: str
    project_dir: Path
    python_version: str
    python_path: str
    engine: str
    venv_name: str
    log_level: int = 2


def get_available_pythons() -> List[Tuple[str, str]]:
    """
    Chama o 'python_manager.bat --list' para obter a lista de Pythons.
    Esta é a arquitetura "Ouroboros" em ação.
    """
    pythons = []
    try:
        # 1. Encontrar o caminho para o python_manager.bat
        # __file__ = C:\pypm\python_src\init_worker.py
        # .parent.parent = C:\pypm
        root_dir = Path(__file__).resolve().parent.parent
        py_manager_path = root_dir / "shell_src" / "python_manager.bat"

        # O python_manager.bat escreve o seu resultado neste ficheiro
        return_file = Path(tempfile.gettempdir()) / ".pypm" / "pypm_py_return.tmp"

        # 2. Executar o worker
        # Usamos --quiet para suprimir a saída [INFO] do próprio manager
        subprocess.run(
            [str(py_manager_path), "--list", "--quiet"],
            check=True,
            shell=True, # shell=True é necessário para executar .bat
            stdout=subprocess.DEVNULL, # Ignora stdout
            stderr=subprocess.DEVNULL  # Ignora stderr
        )

        # 3. Ler o ficheiro de resultado
        if not return_file.exists():
            return []

        with open(return_file, 'r') as f:
            for line in f:
                if ";" in line:
                    version, path = line.strip().split(";", 1)
                    pythons.append((version, path))

        return pythons

    except Exception as e:
        print(f"[INIT_WORKER_ERROR] Falha ao executar python_manager.bat: {e}", file=sys.stderr)
        return []


def _select_from_list(prompt: str, options: List[str]) -> Tuple[int, str]:
    """Helper de menu genérico"""
    print(f"\n--- {prompt} ---")
    for i, option in enumerate(options):
        print(f"  [{i+1}] {option}")

    while True:
        try:
            choice = input(f"Escolha [1-{len(options)}]: ")
            idx = int(choice) - 1
            if 0 <= idx < len(options):
                return idx, options[idx]
        except ValueError:
            pass
        print(f"Escolha inválida. Por favor, insira um número entre 1 e {len(options)}.")


def run_interactive_init() -> Optional[ProjectConfig]:
    """
    Executa o menu interativo passo a passo.
    """
    print("--- Configuração de Novo Projeto pypm ---")
    print(f"A configurar projeto no diretório: {Path.cwd()}")

    # 1. Nome do Projeto
    default_name = Path.cwd().name
    name = input(f"Nome do projeto (alvo) [padrão: {default_name}]: ").strip()
    if not name:
        name = default_name

    # 2. Versão do Python
    pythons = get_available_pythons()
    if not pythons:
        print("[INIT_WORKER_ERROR] Nenhum Python encontrado!", file=sys.stderr)
        print("Por favor, instale um Python ou adicione-o usando 'pypm python install ...'", file=sys.stderr)
        return None

    # Formata as opções para o menu
    python_options = [f"{ver} ({path})" for ver, path in pythons]
    idx, _ = _select_from_list("Escolha uma versão do Python", python_options)
    selected_version, selected_path = pythons[idx]
    # Guardamos apenas a versão principal, ex: "3.11"
    python_version_short = ".".join(selected_version.split(".")[:2])

    # 3. Motor de Dependência (Poetry como padrão)
    engine_options = ["poetry (Recomendado)", "pip (Legacy)"]
    idx, _ = _select_from_list("Escolha o motor de dependências", engine_options)
    engine = "poetry" if idx == 0 else "pip"

    # 4. Nome da Venv
    default_venv = ".venv" if engine == "poetry" else f"{name}_venv"
    venv_name = input(f"Nome da pasta venv [padrão: {default_venv}]: ").strip()
    if not venv_name:
        venv_name = default_venv

    return ProjectConfig(
        name=name,
        project_dir=Path.cwd(),
        python_version=python_version_short, # "3.11"
        python_path=selected_path,           # "C:\Python311\python.exe"
        engine=engine,
        venv_name=venv_name
    )


def create_project_files(config: ProjectConfig, db_manager: DatabaseManager) -> bool:
    """
    Cria os ficheiros .pypm/pypm e .pypm/pypm.local e regista na DB.
    """
    print("\n[INFO] A criar ficheiros de configuração...")
    try:
        config_dir = config.project_dir / ".pypm"
        config_dir.mkdir(exist_ok=True)

        # 1. Criar .pypm/pypm (Ficheiro de config principal)
        with open(config_dir / "pypm", "w") as f:
            f.write(f"PROJECT_NAME={config.name}\n")
            f.write(f"PYTHON_VERSION={config.python_version}\n")
            f.write(f"DEPENDENCY_ENGINEER={config.engine}\n")
            f.write(f"VENV={config.venv_name}\n")
            f.write(f"LOG_LEVEL=2\n") # Padrão INFO

        # 2. Criar .pypm/pypm.local (Ficheiro de estado)
        with open(config_dir / "pypm.local", "w") as f:
            f.write(f"PYTHON_PATH={config.python_path}\n")
            f.write(f"deps_installed=False\n")

        # 3. Registar na Base de Dados Global
        proj = db_manager.add_project(
            name=config.name,
            project_dir=str(config.project_dir),
            py_version=config.python_version,
            engine=config.engine
        )

        if not proj:
            return False

        print(f"[INFO] Projeto '{config.name}' criado e registado com sucesso.")
        print("[INFO] Pode agora executar 'pypm start' (ou outros comandos) neste diretório.")
        return True

    except Exception as e:
        print(f"[INIT_WORKER_ERROR] Falha ao criar ficheiros do projeto: {e}", file=sys.stderr)
        return False


def main():
    """
    Ponto de entrada para o Roteador 'pypm.bat'.

    Chamado por: pypm.bat (handle_init) -> RUN_PYPM_WORKER "init_worker.py" [args...]
    """

    # 1. Conectar à Base de Dados
    ROOT_DIR = Path(__file__).resolve().parent.parent
    DB_PATH = ROOT_DIR / "pypm.db"
    db = DatabaseManager(DB_PATH)

    args = sys.argv[1:]

    # 2. Verificar o modo (Interativo ou Não)
    if args:
        # TODO: Implementar lógica de parsing de flags (ex: pypm init --name X --python Y)
        print("[INFO] Modo não-interativo (via flags) ainda não implementado.")
        print("A iniciar modo interativo...")

    # 3. Executar o Menu Interativo
    try:
        config = run_interactive_init()
        if config:
            create_project_files(config, db)
        else:
            print("[INFO] Criação do projeto cancelada.")

    except KeyboardInterrupt:
        print("\n\n[INFO] Criação do projeto cancelada pelo usuário.")
        sys.exit(0)


if __name__ == "__main__":
    print('oi')
    parser = argparse.ArgumentParser(description="Example CLI")
    parser.add_argument(
        "--project_dir",
        type=str,
        required=True,
        help="Project directory"
    )
    parser.add_argument(
        "--name",
        type=str,
        required=True,
        help="Project name"
    )


    args = parser.parse_args()
    print(args.project_dir)

    main()
