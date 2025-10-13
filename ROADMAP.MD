# Roadmap do `pypm` v2.0: A Proxima Geracao

A versao 2.0 do **Python Project Manager (`pypm`)** marca uma evolucao fundamental na sua arquitetura, migrando de um conjunto de scripts inteligentes para uma aplicacao de linha de comando robusta, multiplataforma e escalavel. A visao e consolidar o `pypm` como uma **plataforma de automacao de tarefas** definitiva para orquestrar, provisionar e portabilizar ambientes de desenvolvimento Python completos.

## 1. Arquitetura: O Core Migra para Python

A mudanca mais significativa sera a migracao de toda a logica de negocio para um core modular escrito em Python.

* **Logica Central em Python:** Todas as operacoes — gestao de projetos, interacoes com Poetry, manipulacao de ficheiros, logica de base de dados — serao reescritas em Python, garantindo portabilidade e manutenibilidade.
* **Scripts Shell como "Roteadores":** Os ficheiros de shell (`pypm.bat`, `pypm.sh`) tornar-se-ao "launchers" leves, responsaveis por encontrar um Python valido e passar os comandos para o core da aplicacao.
* **Persistencia Escalavel com SQLite:** O banco de dados de projetos sera migrado para **SQLite** para maior robustez e performance.
* **Distribuicao via PyPI:** A instalacao sera padronizada para `pip install python-project-manager`.

## 2. Core Engine: Adoção do Poetry como Padrao

O `pypm` adotara o **Poetry** como o motor padrao para uma gestao de dependencias robusta e builds reprodutiveis.

* **Instalacao Sob Demanda:** O Poetry sera instalado automaticamente pelo `pypm` na sua primeira execucao, num ambiente isolado, garantindo consistencia.
* **Padrao para Novos Projetos:** Todos os novos projetos serao inicializados como projetos Poetry.
* **Conversor Automatico:** O `pypm` oferecera a conversao de ficheiros `requirements.txt` existentes para o formato do `pyproject.toml` na configuracao inicial.

## 3. Estrutura de Projeto Padronizada e Portatil

Toda a infraestrutura do `pypm` sera contida numa unica pasta `.pypm` para manter o diretorio do projeto limpo e facilitar a colaboracao.

* **Ficheiros de Configuracao:** A pasta `.pypm` contera a configuracao do projeto partilhada (`pypm`) e a configuracao local especifica da maquina (`pypm.local`). O formato sera chave-valor, para ser compativel com o bootstrap inicial.
* **Estrategia de `.gitignore` Inteligente:** O `pypm` ira gerar um `.gitignore` que versiona ficheiros de configuracao essenciais (`pypm`, `poetry.lock`, as configuracoes dos lancadores) enquanto ignora o `pypm.local`, o ambiente e os logs.

## 4. Gestor de Lancadores (Launchers)

Esta e a evolucao do "comando final". Em vez de um unico ponto de entrada, o `pypm` ira gerir multiplos "lancadores" configuraveis para cada projeto.

* **Lancadores Ilimitados:** Os utilizadores poderao registar multiplos comandos (ex: `start-server`, `run-tests`, `apply-migrations`), cada um com o seu proprio nome e configuracao.
* **Configuracao Granular:** Cada lancador tera a sua propria configuracao, como o comando a ser executado, e se o output deve ser guardado num ficheiro de log com ou sem rotacao.
* **Armazenamento e Portabilidade:** As configuracoes de cada lancador serao guardadas em ficheiros individuais dentro de uma nova pasta `.pypm/launchers/`. Isto garante que os lancadores sao versionados no Git e podem ser recriados noutra maquina.
* **Criacao de Atalhos Fisicos:** O comando `--create-shortcut` ira ler a configuracao de um lancador especifico para criar um atalho (`.lnk` no Windows) que o executa.

## 5. Gerenciamento de Ambiente Declarativo e Portabilidade Total

O `pypm` garantira que um projeto funcione de forma identica em qualquer maquina.

* **Abstracao da Versao do Python:** A configuracao do projeto guardara a **versao requerida** do Python (ex: `python_version = "3.11.9"`), nao um caminho absoluto.
* **Provisionamento Automatico de Python (Python-on-Demand):** O `pypm` ira encontrar a versao do Python necessaria ou **baixa-la e instala-la automaticamente**.
* **Importacao Automatica de Projetos:** Ao ser executado num diretorio com uma pasta `.pypm` nao registada, o `pypm` iniciara um fluxo de **importacao automatica**, tornando trivial a configuracao de um projeto clonado do Git.

## 6. Melhoria da Interface de Linha de Comando (CLI)

A CLI sera modernizada para maior flexibilidade e poder.

* **Novo Padrao de Argumentos:** A sintaxe mudara para um formato mais familiar: `pypm <comando> [argumentos] --opcao <valor>`.
* **Comandos para Lancadores:**
    * `pypm <id> --list-launchers`: Lista todos os lancadores configurados para um projeto.
    * `pypm <id> --start <nome_do_lancador>`: Executa um lancador especifico. Se nenhum nome for fornecido, pode executar um lancador marcado como "padrao".
* **Comandos de Conveniencia:** `pypm shell` para ativar o ambiente no diretorio atual e `pypm init` para iniciar a configuracao.
* **Gestao de Dependencias via CLI:** Comandos `pypm <id> --add <pacote>` e `--remove <pacote>` para interagir com o Poetry.