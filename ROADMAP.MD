# Roadmap do `pypm` v2.0: Rumo a um Gerenciamento de Projetos Moderno

A versão 2.0 do `pypm` representará um salto fundamental em robustez, conveniência e alinhamento com as melhores práticas do ecossistema Python moderno. A visão é transformar o `pypm` de um orquestrador de scripts para um verdadeiro "launcher" de projetos, que abstrai a complexidade da configuração de ambientes e promove um fluxo de trabalho padronizado, portátil e eficiente.

## 1. Core Engine: Adoção do Poetry como Padrão
*(Esta seção permanece a mesma)*

* **Instalação Sob Demanda:** O `pypm` não embarcará o Poetry. Em vez disso, na primeira execução, ele detectará um Python compatível no sistema (ou usará sua própria função para baixar um), e instalará uma versão *fixa* e testada do Poetry em um ambiente isolado.
* **Padrão para Novos Projetos:** Todos os novos projetos configurados com `pypm` serão inicializados como projetos Poetry (`poetry init`).
* **Conversor Automático:** Ao configurar um projeto existente que contenha um `requirements.txt`, o `pypm` oferecerá a conversão automática, importando as dependências para o `pyproject.toml` usando `poetry add`.

## 2. Estrutura de Projeto Padronizada e Portátil

Para manter o diretório raiz do projeto limpo e facilitar a colaboração via Git, toda a infraestrutura do `pypm` será contida em uma única pasta `.pypm`.

* **Centralização de Metadados:** O arquivo de configuração `pypm.ini` será criado e gerenciado dentro de `.pypm/`.
* **Ambiente e Logs Isolados:** A pasta do ambiente virtual (`.pypm/venv/`) e os logs (`.pypm/logs/`) serão mantidos dentro da estrutura do `.pypm`.
* **Estratégia de `.gitignore` Inteligente:** O `pypm` irá gerar ou atualizar o `.gitignore` do projeto para garantir que arquivos de ambiente e logs (como `.pypm/venv/` e `.pypm/logs/`) sejam ignorados, enquanto arquivos de configuração essenciais para a reprodutibilidade (`pypm.ini`, `pyproject.toml`, `poetry.lock`) **sejam versionados**, permitindo que a configuração do projeto seja compartilhada entre a equipe.

## 3. Melhoria da Interface de Linha de Comando (CLI)
*(Esta seção permanece a mesma)*

* **Novo Padrão de Argumentos:** A sintaxe mudará para um formato mais familiar: `pypm <comando> [argumentos] --opcao <valor>`.
* **Execução de Tarefas Arbitrárias:** Suporte para `pypm run <script.py>` (local) e `pypm <id> --run <script.py>` (remoto).
* **Comandos de Conveniência:** `pypm shell` para ativar o ambiente no diretório atual e `pypm init` para iniciar a configuração.

## 4. Novas Funcionalidades
*(Esta seção permanece a mesma)*

* **Criação de Atalhos (`.lnk`):** Comando `pypm <id> --create-shortcut` para gerar um lançador de fácil acesso.
* **Gerenciamento de Dependências via CLI:** Comandos `pypm <id> --add <pacote>` e `--remove <pacote>` para interagir com o Poetry.

## 5. Gerenciamento de Ambiente Declarativo e Portabilidade Total

Para transformar o `pypm` em uma solução completa de provisionamento, o gerenciamento de ambientes será desacoplado da máquina local e a portabilidade será uma feature central.

* **Abstração da Versão do Python:** O `pypm.ini` não armazenará mais o caminho absoluto para o executável do Python. Em vez disso, ele guardará a **versão requerida** (ex: `python_version = "3.11.9"`).
* **Provisionamento Automático de Python (Python-on-Demand):** Ao executar um projeto, o `pypm` lerá a versão do Python necessária. Ele então buscará em seu cache por um Python compatível já instalado. **Se não encontrar, ele usará sua própria funcionalidade para baixar e instalar a versão exata automaticamente.** Isso garante que o projeto sempre execute no ambiente para o qual foi projetado, mesmo que o Python tenha sido desinstalado ou o projeto movido para uma nova máquina.
* **Importação Automática de Projetos:** Ao executar um comando `pypm` em um diretório que contém uma pasta `.pypm/` mas não está registrado no `pypm` global, a ferramenta detectará um projeto "órfão". Ela então iniciará um fluxo de **importação automática**, registrando o projeto no sistema e atualizando as configurações específicas da máquina (como caminhos de diretório), tornando a configuração de um projeto clonado do Git um processo trivial.
* **Configuração em Seções (`pypm.ini`):** O arquivo de configuração será organizado em seções (ex: `[core]`, `[environment]`, `[commands]`) para melhor legibilidade e gerenciamento.

