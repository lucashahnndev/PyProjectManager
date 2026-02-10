from __future__ import annotations

import argparse
import logging
import os
import platform
import re
import subprocess
from enum import Enum
from pathlib import Path
from typing import Optional, List, Tuple, Dict
import uuid

from pydantic import BaseModel, Field, field_validator

from db_manager import DatabaseManager, get_default_db_path, get_user_data_dir


# =========================
# ENUMS E CONSTANTES
# =========================

class DependencyEngine(str, Enum):
    poetry = "poetry"
    pip = "pip"


class LogLevel(str, Enum):
    debug = "debug"
    info = "info"
    warn = "warn"
    error = "error"


class OSType(str, Enum):
    windows = "windows"
    linux = "linux"
    macos = "macos"


SEMVER_RE = re.compile(r"^(\d+)\.(\d+)(?:\.(\d+))?$")


# =========================
# UTILIDADES BÁSICAS
# =========================

def detect_os_type() -> OSType:
    sysname = platform.system().lower()
    if "windows" in sysname:
        return OSType.windows
    if "linux" in sysname:
        return OSType.linux
    if "darwin" in sysname or "mac" in sysname:
        return OSType.macos
    return OSType.linux


def normalize_path(raw: str) -> Path:
    return Path(raw).expanduser().resolve()


def setup_logging(level: LogLevel) -> logging.Logger:
    level_map = {
        LogLevel.debug: logging.DEBUG,
        LogLevel.info: logging.INFO,
        LogLevel.warn: logging.WARNING,
        LogLevel.error: logging.ERROR,
    }
    logging.basicConfig(
        level=level_map.get(level, logging.INFO),
        format="[init_project] [%(levelname)s] %(message)s",
    )
    return logging.getLogger("init_project")


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


# =========================
# KV (pypm / pypm.local)
# =========================

def parse_kv_file(path: Path) -> Dict[str, str]:
    if not path.exists():
        return {}
    data: Dict[str, str] = {}
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            continue
        k, v = line.split("=", 1)
        data[k.strip()] = v.strip()
    return data


def write_kv_file(path: Path, data: Dict[str, str]) -> None:
    # Ordem previsível (melhor pra diff / git)
    lines = [f"{k}={data[k]}" for k in sorted(data.keys())]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def get_or_create_project_uid(project_dir: Path) -> str:
    pypm_dir = project_dir / ".pypm"
    pypm_file = pypm_dir / "pypm"
    existing = parse_kv_file(pypm_file)
    uid = existing.get("PROJECT_UID")
    if uid:
        return uid
    return str(uuid.uuid4())


def get_default_project_venv_path(project_id: int) -> Path:
    base = get_user_data_dir("pypm")
    return (base / "venvs" / str(project_id) / ".venv").resolve()


# =========================
# INPUT INTERATIVO
# =========================

def prompt_yes_no(message: str, default_yes: bool = True) -> bool:
    suffix = " [Y/n]: " if default_yes else " [y/N]: "
    while True:
        ans = input(message + suffix).strip().lower()
        if ans == "" and default_yes:
            return True
        if ans == "" and not default_yes:
            return False
        if ans in ("y", "yes", "s", "sim"):
            return True
        if ans in ("n", "no", "nao", "não"):
            return False
        print("Resposta inválida. Use y/n.")


def prompt_text(message: str) -> str:
    while True:
        ans = input(message + ": ").strip()
        if ans:
            return ans
        print("Valor não pode ser vazio.")


# =========================
# PYTHON MANAGER INTEGRAÇÃO
# =========================

def get_pypm_root() -> Path:
    return Path(__file__).resolve().parents[1]


def get_python_manager_path() -> Path:
    root = get_pypm_root()
    shell_dir = root / "shell_src"
    if detect_os_type() == OSType.windows:
        return shell_dir / "python_manager.bat"
    return shell_dir / "python_manager.sh"


def get_return_file_path() -> Path:
    temp_dir = os.environ.get("TEMP") or os.environ.get("TMPDIR") or "/tmp"
    return Path(temp_dir) / ".pypm" / "pypm_py_return.tmp"


def run_python_manager_list() -> List[Tuple[str, str]]:
    manager = get_python_manager_path()
    if not manager.exists():
        return []

    if detect_os_type() == OSType.windows:
        cmd = ["cmd", "/c", str(manager), "--list", "--log-level", "0"]
    else:
        cmd = [str(manager), "--list", "--log-level", "0"]

    subprocess.run(cmd, capture_output=True, text=True, check=False)

    rf = get_return_file_path()
    if not rf.exists():
        return []

    items: List[Tuple[str, str]] = []
    for line in rf.read_text(encoding="utf-8", errors="ignore").splitlines():
        if ";" in line:
            ver, path = line.split(";", 1)
            items.append((ver.strip(), path.strip()))
    return items


def validate_python_version_string(s: str) -> str:
    s = s.strip().lstrip("v")
    m = SEMVER_RE.match(s)
    if not m:
        raise ValueError("Versão inválida (use 3.11 ou 3.11.8)")
    major, minor, patch = m.groups()
    if int(major) < 3:
        raise ValueError("Apenas Python 3.x é suportado")
    return f"{major}.{minor}" if patch is None else f"{major}.{minor}.{patch}"


def prompt_python_version_with_list() -> str:
    detected = run_python_manager_list()

    if detected:
        print("\nPythons detectados:")
        for i, (ver, path) in enumerate(detected, start=1):
            print(f"  {i}) {ver} -> {path}")
        print("\nEscolha pelo número ou informe uma versão manualmente.")

        while True:
            raw = input("Python: ").strip()
            if raw.isdigit():
                idx = int(raw)
                if 1 <= idx <= len(detected):
                    return validate_python_version_string(detected[idx - 1][0])
            try:
                return validate_python_version_string(raw)
            except ValueError as e:
                print(e)

    print("\nNenhum Python detectado.")
    while True:
        raw = prompt_text("Informe a versão do Python")
        try:
            return validate_python_version_string(raw)
        except ValueError as e:
            print(e)


# =========================
# MODELO DE DADOS
# =========================

class InitWorkerParams(BaseModel):
    project_dir: Path
    name: str
    python_version: str

    os_type: OSType = Field(default_factory=detect_os_type)
    engine: DependencyEngine = DependencyEngine.poetry
    log_level: LogLevel = LogLevel.info

    venv_path: Optional[Path] = None
    create_dir: bool = Field(False, exclude=True)

    @field_validator("project_dir", mode="before")
    @classmethod
    def normalize_dir(cls, v):
        return normalize_path(str(v))

    @field_validator("project_dir")
    @classmethod
    def validate_dir(cls, v: Path, info):
        if v.exists():
            if not v.is_dir():
                raise ValueError("project_dir não é um diretório")
            return v
        if info.data.get("create_dir"):
            v.mkdir(parents=True, exist_ok=True)
            return v
        raise ValueError("Diretório não existe (use --create)")

    @field_validator("name")
    @classmethod
    def validate_name(cls, v):
        v = v.strip()
        if not v:
            raise ValueError("Nome do projeto é obrigatório")
        return v

    @field_validator("python_version", mode="before")
    @classmethod
    def normalize_python(cls, v):
        return validate_python_version_string(str(v))


# =========================
# CLI
# =========================

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser("pypm init")
    p.add_argument("--project_dir")
    p.add_argument("-c", "--create", action="store_true")
    p.add_argument("--name")
    p.add_argument("--python", dest="python_version")
    p.add_argument("--engine", type=DependencyEngine, default=DependencyEngine.poetry)
    p.add_argument("--log_level", type=LogLevel, default=LogLevel.info)
    p.add_argument("--venv", dest="venv_path")
    return p


def resolve_interactive_missing(args) -> dict:
    data = {}

    if args.project_dir:
        data["project_dir"] = args.project_dir
        data["create_dir"] = args.create
    else:
        cwd = str(Path.cwd())
        if prompt_yes_no(f"Diretório do projeto é o atual?\n  {cwd}"):
            data["project_dir"] = cwd
            data["create_dir"] = False
        else:
            data["project_dir"] = prompt_text("Informe o diretório do projeto")
            data["create_dir"] = True

    data["name"] = args.name or prompt_text("Nome do projeto")
    data["python_version"] = args.python_version or prompt_python_version_with_list()
    data["engine"] = args.engine
    data["log_level"] = args.log_level
    data["os_type"] = detect_os_type()
    data["venv_path"] = args.venv_path

    return data


def provision_project_files(project: "object", params: InitWorkerParams, logger: logging.Logger) -> None:
    project_dir = params.project_dir
    pypm_dir = project_dir / ".pypm"
    ensure_dir(pypm_dir)

    # 1) UID: reusa se já existir (import/reinit), senão cria
    uid = getattr(project, "project_uid", None) or get_or_create_project_uid(project_dir)

    # 2) Arquivo portável (vai pro git): .pypm/pypm
    pypm_file = pypm_dir / "pypm"
    pypm_data = parse_kv_file(pypm_file)  # se existir, preserva extras
    pypm_data.update({
        "PROJECT_UID": uid,
        "PROJECT_NAME": params.name,
        "PYTHON_VERSION": params.python_version,
        "DEPENDENCY_ENGINE": params.engine.value,
        "LOG_LEVEL": str(2 if params.log_level in (LogLevel.info, LogLevel.warn) else 3 if params.log_level == LogLevel.debug else 1),
    })
    write_kv_file(pypm_file, pypm_data)

    # 3) Arquivo local (não versiona): .pypm/pypm.local
    pypm_local_file = pypm_dir / "pypm.local"
    pypm_local_data = parse_kv_file(pypm_local_file)

    # venv_path: se não veio por argumento, padrão = user_data/venvs/<id>/.venv
    default_venv = get_default_project_venv_path(getattr(project, "id"))
    venv_path = params.venv_path or default_venv

    pypm_local_data.update({
        "PROJECT_ID": str(getattr(project, "id")),
        "PROJECT_UID": uid,
        "deps_installed": pypm_local_data.get("deps_installed", "False"),
        "VENV_PATH": str(venv_path),
    })
    # PYTHON_PATH fica pra camada shell preencher após python_manager validar (ou o core)
    if "PYTHON_PATH" not in pypm_local_data:
        pypm_local_data["PYTHON_PATH"] = ""

    write_kv_file(pypm_local_file, pypm_local_data)

    logger.info("Estrutura .pypm provisionada: %s", str(pypm_dir))


# =========================
# ENTRYPOINT
# =========================

if __name__ == "__main__":
    parser = build_parser()
    args = parser.parse_args()

    payload = resolve_interactive_missing(args)

    params = InitWorkerParams(
        project_dir=payload["project_dir"],
        name=payload["name"],
        python_version=payload["python_version"],
        os_type=payload["os_type"],
        engine=payload["engine"],
        log_level=payload["log_level"],
        venv_path=normalize_path(payload["venv_path"]) if payload.get("venv_path") else None,
        create_dir=payload.get("create_dir", False),
    )

    logger = setup_logging(params.log_level)
    logger.info("Criando projeto '%s'", params.name)

    db = DatabaseManager(get_default_db_path())

    # Se o diretório já tem PROJECT_UID, usa para registrar (import/reinit)
    inferred_uid = get_or_create_project_uid(params.project_dir)

    project = db.add_project(
        name=params.name,
        project_dir=str(params.project_dir),
        py_version=params.python_version,
        engine=params.engine.value,
        project_uid=inferred_uid,
    )

    if not project:
        logger.error("Projeto já existe ou falha ao registrar.")
        raise SystemExit(1)

    provision_project_files(project, params, logger)

    logger.info("Projeto registrado com sucesso. id=%s uid=%s", project.id, project.project_uid)
