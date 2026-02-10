import sqlite3
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional
import datetime
import uuid

import os
import platform

def get_user_data_dir(app_name: str = "pypm") -> Path:
    """
    Retorna um diretório de dados por usuário, de forma cross-platform, sem dependências externas.
    Windows: %LOCALAPPDATA%\<app_name>
    Linux:   $XDG_DATA_HOME/<app_name> ou ~/.local/share/<app_name>
    macOS:   ~/Library/Application Support/<app_name>
    """
    system = platform.system().lower()

    if system == "windows":
        base = os.environ.get("LOCALAPPDATA") or os.environ.get("APPDATA")
        if not base:
            # fallback extremo
            base = str(Path.home() / "AppData" / "Local")
        return Path(base) / app_name

    if system == "darwin":
        return Path.home() / "Library" / "Application Support" / app_name

    # linux/others
    xdg = os.environ.get("XDG_DATA_HOME")
    if xdg:
        return Path(xdg) / app_name
    return Path.home() / ".local" / "share" / app_name


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def get_default_db_path() -> Path:
    """
    Caminho padrão do SQLite do pypm no escopo do usuário atual.
    """
    data_dir = get_user_data_dir("pypm")
    ensure_dir(data_dir / "db")
    return data_dir / "db" / "pypm.sqlite"


def generate_project_uid() -> str:
    """
    Gera um identificador estável (UUID4) para o projeto.
    Esse UID deve ser persistido em '.pypm/pypm' e também no DB (unique).
    """
    return str(uuid.uuid4())


# --- 1. Definição do Modelo Tipificado ---

@dataclass
class Project:
    """
    Um dataclass 'bem tipificado' que representa um projeto
    registrado no banco de dados do pypm (escopo do usuário).
    """
    id: int
    project_uid: str
    name: str  # O 'alvo' ou nome único (ex: 'my-api')
    project_dir: str  # O caminho absoluto para o diretório do projeto
    python_version: str  # A versão do Python requerida (ex: "3.11")
    engine: str  # O motor de dependência (ex: 'pip' ou 'poetry')
    created_at: str  # Data de registro


# --- 2. Classe de Gerenciamento do Banco de Dados ---

class DatabaseManager:
    """
    Gerencia a conexão e as operações no banco de dados SQLite do pypm (por usuário).
    Auto-provisiona o banco e as tabelas na inicialização.
    """

    def __init__(self, db_path: Path):
        """
        Inicializa o gerenciador e garante que o banco de dados e as tabelas existam.
        """
        self.db_path = db_path
        self._provision_db()

    def _get_connection(self) -> sqlite3.Connection:
        """Retorna uma nova conexão com o banco de dados."""
        # O isolation_level=None habilita o modo autocommit.
        return sqlite3.connect(self.db_path, isolation_level=None)

    def _column_exists(self, conn: sqlite3.Connection, table: str, column: str) -> bool:
        cur = conn.cursor()
        cur.execute(f"PRAGMA table_info({table})")
        cols = [r[1] for r in cur.fetchall()]
        return column in cols

    def _provision_db(self) -> None:
        """
        Garante que o arquivo de banco de dados e a tabela 'projects' existam.
        Também executa migrações leves (ex: adicionar project_uid em instalações antigas).
        """
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                CREATE TABLE IF NOT EXISTS projects (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    project_uid TEXT,
                    name TEXT NOT NULL UNIQUE,
                    project_dir TEXT NOT NULL,
                    python_version TEXT,
                    engine TEXT DEFAULT 'pip',
                    created_at TEXT NOT NULL
                )
                """)

                # Migração: adicionar coluna project_uid se vier de DB antigo
                if not self._column_exists(conn, "projects", "project_uid"):
                    cursor.execute("ALTER TABLE projects ADD COLUMN project_uid TEXT")

                # Índice/unique do UID (SQLite: IF NOT EXISTS em índice existe)
                cursor.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_projects_uid ON projects(project_uid)")
        except sqlite3.Error as e:
            print(f"[DB_MANAGER_ERROR] Falha ao provisionar o banco de dados: {e}", file=sys.stderr)
            sys.exit(1)

    def add_project(self, name: str, project_dir: str, py_version: str, engine: str, project_uid: Optional[str] = None) -> Optional[Project]:
        """
        Adiciona um novo projeto ao banco de dados.
        - Se project_uid não for fornecido, gera automaticamente (UUID4).
        Retorna o objeto Project criado ou None em caso de falha.
        """
        now = datetime.datetime.now().isoformat()
        uid = project_uid or generate_project_uid()
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(
                    "INSERT INTO projects (project_uid, name, project_dir, python_version, engine, created_at) VALUES (?, ?, ?, ?, ?, ?)",
                    (uid, name, project_dir, py_version, engine, now)
                )
                new_id = cursor.lastrowid
                return Project(
                    id=new_id,
                    project_uid=uid,
                    name=name,
                    project_dir=project_dir,
                    python_version=py_version,
                    engine=engine,
                    created_at=now
                )
        except sqlite3.IntegrityError as e:
            # Pode ser nome duplicado ou UID duplicado
            msg = str(e).lower()
            if "name" in msg:
                print(f"[DB_MANAGER_ERROR] Um projeto com o nome '{name}' já existe.", file=sys.stderr)
            elif "project_uid" in msg or "idx_projects_uid" in msg:
                print(f"[DB_MANAGER_ERROR] Um projeto com o UID '{uid}' já existe.", file=sys.stderr)
            else:
                print(f"[DB_MANAGER_ERROR] Falha de integridade ao adicionar projeto: {e}", file=sys.stderr)
            return None
        except sqlite3.Error as e:
            print(f"[DB_MANAGER_ERROR] Falha ao adicionar projeto: {e}", file=sys.stderr)
            return None

    def get_project_by_name(self, name: str) -> Optional[Project]:
        """
        Busca um projeto pelo seu nome ('alvo').
        Esta será a função principal do roteador pypm.bat.
        """
        try:
            with self._get_connection() as conn:
                conn.row_factory = sqlite3.Row
                cursor = conn.cursor()
                cursor.execute("SELECT * FROM projects WHERE name = ?", (name,))
                row = cursor.fetchone()

                if row:
                    return Project(**dict(row))
                return None
        except sqlite3.Error as e:
            print(f"[DB_MANAGER_ERROR] Falha ao buscar projeto: {e}", file=sys.stderr)
            return None

    def get_project_by_uid(self, project_uid: str) -> Optional[Project]:
        """
        Busca um projeto pelo seu project_uid (UUID).
        Útil para import/reconcile quando o ID local muda.
        """
        try:
            with self._get_connection() as conn:
                conn.row_factory = sqlite3.Row
                cursor = conn.cursor()
                cursor.execute("SELECT * FROM projects WHERE project_uid = ?", (project_uid,))
                row = cursor.fetchone()

                if row:
                    return Project(**dict(row))
                return None
        except sqlite3.Error as e:
            print(f"[DB_MANAGER_ERROR] Falha ao buscar projeto por UID: {e}", file=sys.stderr)
            return None

    def list_projects(self) -> List[Project]:
        """
        Lista todos os projetos registrados.
        Usado pelo comando 'pypm list'.
        """
        projects: List[Project] = []
        try:
            with self._get_connection() as conn:
                conn.row_factory = sqlite3.Row
                cursor = conn.cursor()
                cursor.execute("SELECT * FROM projects ORDER BY name")
                rows = cursor.fetchall()

                for row in rows:
                    projects.append(Project(**dict(row)))
            return projects
        except sqlite3.Error as e:
            print(f"[DB_MANAGER_ERROR] Falha ao listar projetos: {e}", file=sys.stderr)
            return []

    def remove_project(self, name: str) -> bool:
        """
        Remove um projeto pelo nome.
        Usado pelo comando 'pypm remove'.
        """
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("DELETE FROM projects WHERE name = ?", (name,))
                return cursor.rowcount > 0
        except sqlite3.Error as e:
            print(f"[DB_MANAGER_ERROR] Falha ao remover projeto: {e}", file=sys.stderr)
            return False


# --- 3. Ponto de Entrada (Exemplo de como o Roteador o usará) ---

def main():
    """
    Ponto de entrada principal para o roteador pypm.bat chamar.

    Exemplos de como o pypm.bat vai chamar este script (Projeto Ouroboros):

    1. pypm pypm_proj run db_manager.py get my-api
    2. pypm pypm_proj run db_manager.py list
    3. pypm pypm_proj run db_manager.py add my-api "C:..." "3.11" "poetry"
    4. pypm pypm_proj run db_manager.py get_uid <uuid>
    """

    DB_PATH = get_default_db_path()
    db = DatabaseManager(DB_PATH)

    args = sys.argv[1:]
    if not args:
        print("[DB_MANAGER_ERROR] Nenhum comando fornecido (ex: list, get, get_uid, add, remove).", file=sys.stderr)
        sys.exit(1)

    command = args[0].lower()

    try:
        if command == "list":
            projects = db.list_projects()
            if not projects:
                print("Nenhum projeto registrado.")
            for proj in projects:
                print(f"[{proj.name}] ({proj.project_uid}) - {proj.project_dir}")

        elif command == "get":
            name = args[1]
            proj = db.get_project_by_name(name)
            if proj:
                print(proj.project_dir)
            else:
                print(f"[DB_MANAGER_ERROR] Projeto '{name}' não encontrado.", file=sys.stderr)
                sys.exit(1)

        elif command == "get_uid":
            uid = args[1]
            proj = db.get_project_by_uid(uid)
            if proj:
                print(proj.project_dir)
            else:
                print(f"[DB_MANAGER_ERROR] Projeto UID '{uid}' não encontrado.", file=sys.stderr)
                sys.exit(1)

        elif command == "add":
            name, project_dir, py_version, engine = args[1], args[2], args[3], args[4]
            uid = args[5] if len(args) >= 6 else None
            proj = db.add_project(name, project_dir, py_version, engine, project_uid=uid)
            if proj:
                print(f"Projeto '{proj.name}' adicionado com sucesso. UID={proj.project_uid}")
            else:
                sys.exit(1)

        elif command == "remove":
            name = args[1]
            if db.remove_project(name):
                print(f"Projeto '{name}' removido com sucesso.")
            else:
                print(f"[DB_MANAGER_ERROR] Falha ao remover projeto '{name}'.", file=sys.stderr)
                sys.exit(1)

        else:
            print(f"[DB_MANAGER_ERROR] Comando desconhecido: {command}", file=sys.stderr)
            sys.exit(1)

    except IndexError:
        print(f"[DB_MANAGER_ERROR] Argumentos insuficientes para o comando '{command}'.", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"[DB_MANAGER_ERROR] Erro inesperado: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
