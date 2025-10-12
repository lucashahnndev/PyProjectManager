# Roadmap do `pypm` v2.0: A Próxima Geração

A versão 2.0 do **Python Project Manager (`pypm`)** marca uma evolução fundamental na sua arquitetura, migrando de um conjunto de scripts inteligentes para uma aplicação de linha de comando robusta, multiplataforma e escalável. A visão é consolidar o `pypm` como a ferramenta definitiva para orquestrar, provisionar e portabilizar ambientes de desenvolvimento Python completos.

## 1. Arquitetura: O Core Migra para Python

A mudança mais significativa será a migração de toda a lógica de negócio, atualmente em scripts Batch, para um core modular escrito em Python.

* **Lógica Central em Python:** Todas as operações — gerenciamento de projetos, interações com Poetry, manipulação de arquivos, lógica de banco de dados — serão reescritas em Python. Isso garantirá portabilidade, testabilidade e facilitará a manutenção e a adição de novas funcionalidades complexas.
* **Scripts Shell como "Roteadores":** Os arquivos de shell (`pypm.bat`, `pypm.sh`) se tornarão "launchers" leves. Suas únicas responsabilidades serão encontrar um interpretador Python válido e passar todos os argumentos para o ponto de entrada da aplicação Python (ex: `python -m pypm.cli %*`).
* **Persistência Escalável com SQLite:** O banco de dados de projetos, atualmente em `.csv`, será migrado para **SQLite**. Isso proporcionará maior robustez, performance e a capacidade de realizar consultas mais complexas, tudo isso mantendo a simplicidade de um único arquivo de banco de dados e sem adicionar dependências externas.
* **Distribuição via PyPI:** O projeto será empacotado e distribuído no Python Package Index (PyPI). A instalação será padronizada para o comando `pip install python-project-manager`, tornando a ferramenta facilmente acessível a toda a comunidade Python.

## 2. Core Engine: Adoção do Poetry como Padrão
*(Esta seção permanece a mesma)*

* **Instalação Sob Demanda:** O `pypm` não embarcará o Poetry. Em vez disso, na primeira execução, ele detectará um Python compatível no sistema (ou usará sua própria função para baixar um), e instalará uma versão *fixa* e testada do Poetry em um ambiente isolado.
* **Padrão para Novos Projetos:** Todos os novos projetos configurados com `pypm` serão inicializados como projetos Poetry (`poetry init`).
* **Conversor Automático:** Ao configurar um projeto existente que contenha um `requirements.txt`, o `pypm` oferecerá a conversão automática, importando as dependências para o `pyproject.toml` usando `poetry add`.

## 3. Estrutura de Projeto Padronizada e Portátil
*(Esta seção permanece a mesma)*

* **Centralização na Pasta `.pypm`:** Toda a infraestrutura do `pypm` (configuração, logs, ambiente virtual) será contida em uma única pasta `.pypm` para manter o diretório do projeto limpo.
* **Estratégia de `.gitignore` Inteligente:** O `pypm` irá gerar um `.gitignore` que versiona arquivos de configuração essenciais (`pypm.ini`, `poetry.lock`) enquanto ignora o ambiente e os logs.

## 4. Gerenciamento de Ambiente Declarativo e Portabilidade Total

O gerenciamento de ambientes será a funcionalidade central, garantindo que um projeto funcione de forma idêntica em qualquer máquina.

* **Abstração da Versão do Python:** O `pypm.ini` não armazenará mais o caminho absoluto para o executável do Python. Em vez disso, ele guardará a **versão requerida** (ex: `python_version = "3.11.9"`).
* **Provisionamento Automático de Python (Python-on-Demand):** Ao executar um projeto, o `pypm` lerá a versão do Python necessária. Se não a encontrar, ele usará sua própria funcionalidade para **baixar e instalar a versão exata automaticamente**.
* **Importação Automática de Projetos:** Ao ser executado em um diretório com uma pasta `.pypm` não registrada, o `pypm` iniciará um fluxo de **importação automática**, registrando o projeto e adaptando os caminhos para a nova máquina, tornando trivial a configuração de um projeto clonado do Git.
* **Exportação/Importação Manual:** Comandos `pypm export` e `pypm import` serão implementados para permitir a fácil migração de projetos entre sistemas.

## 5. Melhoria da Interface de Linha de Comando (CLI)
*(Esta seção permanece a mesma)*

* **Novo Padrão de Argumentos:** A sintaxe mudará para um formato mais familiar: `pypm <comando> [argumentos] --opcao <valor>`.
* **Execução de Tarefas Arbitrárias:** Suporte para `pypm run <script.py>` (local) e `pypm <id> --run <script.py>` (remoto).
* **Comandos de Conveniência:** `pypm shell` para ativar o ambiente no diretório atual e `pypm init` para iniciar a configuração.
* **Criação de Atalhos (`.lnk`):** Comando `pypm <id> --create-shortcut` para gerar um lançador de fácil acesso.
* **Gerenciamento de Dependências via CLI:** Comandos `pypm <id> --add <pacote>` e `--remove <pacote>` para interagir com o Poetry.

