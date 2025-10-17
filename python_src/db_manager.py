import sqlite3
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional
import datetime

# --- 1. Definição do Modelo Tipificado ---

@dataclass
class Project:
    """
    Um dataclass 'bem tipificado' que representa um projeto
    registrado no banco de dados global do pypm.
    """
    id: int
    name: str  # O 'alvo' ou nome único (ex: 'my-api')
    project_dir: str  # O caminho absoluto para o diretório do projeto
    python_version: str # A versão do Python requerida (ex: "3.11")
    engine: str # O motor de dependência (ex: 'pip' ou 'poetry')
    created_at: str # Data de registro


# --- 2. Classe de Gerenciamento do Banco de Dados ---

class DatabaseManager:
    """
    Gerencia a conexão e as operações no banco de dados SQLite global do pypm.
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

    def _provision_db(self) -> None:
        """
        Garante que o arquivo de banco de dados e a tabela 'projects' existam.
        Esta é a função de "auto-provisionamento".
        """
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                # Esta é a definição da tabela global de projetos
                cursor.execute("""
                CREATE TABLE IF NOT EXISTS projects (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    name TEXT NOT NULL UNIQUE,
                    project_dir TEXT NOT NULL,
                    python_version TEXT,
                    engine TEXT DEFAULT 'pip',
                    created_at TEXT NOT NULL
                )
                """)
        except sqlite3.Error as e:
            print(f"[DB_MANAGER_ERROR] Falha ao provisionar o banco de dados: {e}", file=sys.stderr)
            sys.exit(1)

    def add_project(self, name: str, project_dir: str, py_version: str, engine: str) -> Optional[Project]:
        """
        Adiciona um novo projeto ao banco de dados.
        Retorna o objeto Project criado ou None em caso de falha.
        """
        now = datetime.datetime.now().isoformat()
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(
                    "INSERT INTO projects (name, project_dir, python_version, engine, created_at) VALUES (?, ?, ?, ?, ?)",
                    (name, project_dir, py_version, engine, now)
                )
                new_id = cursor.lastrowid
                return Project(
                    id=new_id,
                    name=name,
                    project_dir=project_dir,
                    python_version=py_version,
                    engine=engine,
                    created_at=now
                )
        except sqlite3.IntegrityError:
            print(f"[DB_MANAGER_ERROR] Um projeto com o nome '{name}' já existe.", file=sys.stderr)
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
    """
    
    # Define o caminho do DB na pasta raiz do PYPM (um nível acima de 'python_src')
    # __file__ = C:\pypm\python_src\db_manager.py
    # .parent  = C:\pypm\python_src
    # .parent  = C:\pypm
    # / pypm.db = C:\pypm\pypm.db
    ROOT_DIR = Path(__file__).resolve().parent.parent
    DB_PATH = ROOT_DIR / "pypm.db"
    
    db = DatabaseManager(DB_PATH)
    
    # Simples roteamento de argumentos de linha de comando
    args = sys.argv[1:]
    if not args:
        print("[DB_MANAGER_ERROR] Nenhum comando fornecido (ex: list, get, add, remove).", file=sys.stderr)
        sys.exit(1)

    command = args[0].lower()

    try:
        if command == "list":
            projects = db.list_projects()
            if not projects:
                print("Nenhum projeto registrado.")
            for proj in projects:
                # O roteador .bat capturará esta saída
                print(f"[{proj.name}] - {proj.project_dir}")
        
        elif command == "get":
            name = args[1]
            proj = db.get_project_by_name(name)
            if proj:
                # O roteador .bat capturará este caminho
                print(proj.project_dir)
            else:
                # O roteador .bat capturará o erro
                print(f"[DB_MANAGER_ERROR] Projeto '{name}' não encontrado.", file=sys.stderr)
                sys.exit(1)

        elif command == "add":
            name, project_dir, py_version, engine = args[1], args[2], args[3], args[4]
            proj = db.add_project(name, project_dir, py_version, engine)
            if proj:
                print(f"Projeto '{proj.name}' adicionado com sucesso.")
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