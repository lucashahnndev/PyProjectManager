# Roadmap do `pypm` v2.0: O Orquestrador de Tarefas Híbrido

A versão 2.0 do **Python Project Manager (`pypm`)** marca uma evolução fundamental. Migramos de uma ferramenta de gerenciamento de projeto para uma **plataforma de automação, orquestração e deploy** para Python.

A visão é transformar o `pypm` em uma ferramenta híbrida que resolve o "problema do bootstrap" (provisionando o próprio Python), ao mesmo tempo que oferece uma CLI poderosa para gerenciar, executar e "instalar" projetos Python como aplicações nativas, sem a necessidade de compilação ou virtualização de SO.

---

## 1. A Nova Convenção da CLI (A API do Usuário)

Todo o desenvolvimento será guiado por esta interface de linha de comando (CLI) unificada e profissional. Ela é o guia mestre para o desenvolvimento dos roteadores `pypm.bat` e `pypm.sh`.

#### Sintaxe Geral

A sintaxe segue um padrão claro de 3 modos de operação:

`pypm [ALVO] <COMANDO> [ARGUMENTOS] [--OPÇÕES]`

---

#### Modo 1: Comandos Globais (O `pypm` é o alvo)

O usuário executa comandos que afetam o `pypm` em si ou o registro de projetos.

* `pypm init [opções...]`: Inicia um novo projeto no diretório atual.
    * *Ex (Cadeia de Parâmetros):* `pypm init --name "my-api" --python 3.11 --engine poetry`
* `pypm list`: Lista todos os projetos registrados no banco de dados SQLite.
* `pypm python <sub-comando> [args...]`: Interface para o gerenciador de Python.
    * *Ex:* `pypm python list`
    * *Ex:* `pypm python install 3.12.0`
* `pypm edit <ALVO> [opções...]`: Edita a configuração de um projeto via cadeia de parâmetros.
    * *Ex:* `pypm edit my-api --cmd "python server.py"`
* `pypm deploy <ALVO> [launcher_name] [opções...]`: Inicia o processo de empacotamento (ver Seção 7).
* `pypm help [comando]`: Exibe a ajuda.

---

#### Modo 2: Comandos de Contexto (O *Diretório Atual* é o alvo)

O usuário está *dentro* de um diretório de projeto (`.pypm/` existe). O `pypm` aplica o comando a esse projeto.

* `pypm start [launcher_name]`: Inicia um launcher (padrão ou nomeado).
* `pypm add <pacote> [--dev]`: Adiciona uma dependência (Poetry ou Pip).
* `pypm remove <pacote>`: Remove uma dependência.
* `pypm run <comando...>`: Executa um comando arbitrário no venv.
* `pypm shell`: Ativa o shell (prompt) do ambiente.
* `pypm status`: Lista os launchers *em execução* deste projeto.
* `pypm launcher list`: Lista os launchers *configurados* para este projeto.

---

#### Modo 3: Comandos de Alvo (Um *Projeto Específico* é o alvo)

O usuário está em *qualquer* diretório e especifica qual projeto deseja controlar.

* `pypm my-api start dev`: Inicia o launcher "dev" do projeto "my-api".
* `pypm my-api add fastapi`: Adiciona `fastapi` ao projeto "my-api".
* `pypm my-api status`: Mostra os processos em execução do "my-api".
* `pypm my-api launcher create "run-tests" --cmd "pytest"`: Cria um novo launcher.

---

## 2. Arquitetura Híbrida (A Solução de Bootstrap)

A v2.0 abandona a ideia de um core 100% Python em favor de uma arquitetura híbrida mais robusta, que resolve o "Problema do Bootstrap": **O `pypm` não pode depender de Python para instalar o Python.**

* **Camada Nativa (Shell Routers):** Os scripts `pypm.bat` (e futuros `pypm.sh`) são "roteadores" leves. Eles são responsáveis por:
    1.  Analisar a CLI (conforme Seção 1).
    2.  Delegar o provisionamento de Python ao `python_manager.bat`.
    3.  Lidar com lógica de shell pura (ativação de `venv`, prompts interativos).
    4.  Executar lógicas *headless* (via VBS/PowerShell) para launchers de deploy.
* **Camada Lógica (Python Workers):** Um projeto Python interno, gerenciado pelo próprio `pypm`, que atua como o "cérebro" para tarefas pesadas. Ele será chamado pelos scripts de shell *após* um Python válido ser garantido. Suas responsabilidades incluem:
    1.  Gerenciamento do banco de dados **SQLite** (projetos, PIDs, status).
    2.  Leitura e escrita dos arquivos de configuração `.json` dos launchers.
    3.  Monitoramento de processos (para o comando `status`).

---

## 3. O "Projeto Ouroboros" (O Core Interno)

Para garantir o isolamento e a robustez, os "Python Workers" (a Camada Lógica) serão gerenciados como um projeto `pypm` interno, chamado `pypm_proj`.

O `pypm` usará seus próprios recursos para executar seus scripts internos, forçando-o a "comer a própria ração" (*dogfooding*).

* *Exemplo de chamada interna:* `pypm pypm_proj run list_projects.py`

---

## 4. O Coração do pypm: Gestão de Launchers

Esta é a evolução do "comando final". Cada projeto agora gerencia múltiplos "launchers" de tarefas.

* **Portabilidade (JSON):** As configurações de cada launcher serão armazenadas em arquivos individuais em `.pypm/launchers/<nome_do_launcher>.json`. Isso garante que os launchers sejam versionados no Git e reproduzíveis.
* **Configuração Granular:** Cada launcher JSON suportará opções avançadas:
    * `cmd`: O comando a ser executado.
    * `icon`: Caminho para um arquivo `.ico` para ser usado no atalho.
    * `headless`: (Booleano) Se verdadeiro, executa sem console (via `.pyw`, VBS, etc.).
    * `singleton`: (Booleano) Se verdadeiro, impede execuções paralelas do mesmo launcher.
    * `log_config`: (Objeto) Define a configuração de log (arquivo, rotação) específica para este launcher, substituindo o log de nível de projeto.
    * `os_compat`: (Array) Lista de SOs compatíveis (ex: `["windows"]` ou `["windows", "linux"]`) para execução. O `pypm` irá pular a execução/criação de atalho se o SO não for compatível.
* **Gestão via CLI:** Um conjunto completo de comandos para gerenciar launchers:
    * `pypm [alvo] launcher list`
    * `pypm [alvo] launcher create <nome> --cmd "..." [opções...]`
    * `pypm [alvo] launcher edit <nome> [opções...]`
    * `pypm [alvo] launcher remove <nome>`
    * `pypm [alvo] launcher shortcut <nome>` (Cria o atalho físico).

---

## 5. Orquestração e Gestão de Processos (O "Docker-like")

O `pypm` evolui de um *runner* para um *orquestrador*, gerenciando ativamente os processos que inicia.

* **Rastreamento de PID:** O banco de dados SQLite registrará o PID, nome do launcher e projeto de todos os processos iniciados pelo `pypm`.
* **Comando `status`:** Fornecerá uma visão "estilo `docker ps`" dos launchers em execução, seu status, consumo de recursos (CPU/Memória) e PID.
* **Comando `stop`:** Permitirá o encerramento controlado de launchers pelo nome ou PID.
* **Controle de Instância (`singleton`):** O comando `start` verificará o DB de PIDs antes de executar um launcher marcado como `--singleton`.

---

## 6. Gestão de Ambiente (Refinada)

* **Suporte Multi-Engine (Poetry-first):** O `pypm` suportará `pip/venv` e `Poetry`. Poetry será o padrão preferencial para novos projetos.
* **Python-on-Demand:** O `python_manager.bat` mantém sua funcionalidade de "Provisionamento Automático de Python", garantindo que a versão correta esteja disponível, baixando-a se necessário.
* **Portabilidade Total:** O fluxo de "Importação Automática" será aprimorado. Executar `pypm init` em um diretório com um `.pypm/` clonado iniciará um fluxo de importação para registrar o projeto e recriar o ambiente e os launchers.

---

## 7. Distribuição e Empacotamento (Modo Deploy)

Esta é a *killer feature* que permite o deploy sem PyInstaller. Ela transforma um projeto `pypm` em um pacote de distribuição leve.

* **Comando:** `pypm [alvo] deploy <launcher_name> [opções...]`
* **Processo de "Build":**
    1.  Cria uma pasta de distribuição (ex: `dist/meu-projeto-v1.0/`).
    2.  Copia o código-fonte, mas compila todos os `.py` para `.pyc` e remove os `.py` originais (para ofuscação leve e proteção de código).
    3.  Copia a pasta `.pypm/` "limpa", excluindo `pypm.local`, `*.log` e o `venv`.
    4.  Gera um `setup.bat` e/ou `setup.sh` de bootstrap na raiz da pasta `dist/`.
    5.  Compacta o conteúdo da pasta `dist/` em um arquivo `.zip` final.
* **Processo de "Setup" (Na máquina do cliente):**
    1.  O usuário descompacta o `.zip` e executa o `setup.bat`.
    2.  O `setup.bat` (Bootstrap):
        a.  Verifica se o `pypm` está no PATH.
        b.  Se não estiver, baixa o `pypm` do GitHub e o instala (usando o comando do `Readme.md`).
        c.  Executa `pypm init` dentro da pasta do projeto, que aciona o fluxo de "Importação Automática".
        d.  Executa `pypm [alvo] launcher shortcut <launcher_name>` para criar os atalhos no Desktop/Menu Iniciar, efetivamente "instalando" a aplicação.
        e.  (Opcional) Adiciona o launcher ao PATH do usuário.

---

## 8. Segurança e Confiança na Distribuição

Para combater falsos positivos de antivírus e o Windows SmartScreen, o `pypm` adotará uma estratégia de confiança em duas frentes:

1.  **Transparência Radical (Open-Source):** Os scripts de shell (`.bat`, `python_manager.bat`) permanecerão abertos e "barulhentos" (verbosos), explicando ações de risco (downloads, instalações) para provar que não há intenção maliciosa.
2.  **Verificação Criptográfica (Assinatura):** Em vez de certificados de código tradicionais caros, o `pypm` usará padrões modernos como o **Sigstore** (da Linux Foundation) para assinar digitalmente seus *releases* oficiais. Isso permite que qualquer pessoa verifique criptograficamente que a ferramenta é autêntica e não foi adulterada.