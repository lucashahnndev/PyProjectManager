/*
# Python Project Manager (`pyproj`)

Uma ferramenta de linha de comando (CLI) poderosa para centralizar, automatizar e simplificar o gerenciamento de projetos Python no ambiente Windows.

Cansado de gerenciar manualmente ambientes virtuais, diferentes versões do Python e scripts de inicialização para cada projeto? O `pyproj` resolve isso criando um registro central para todos os seus projetos, permitindo que você os configure, execute e interaja com eles de qualquer lugar do seu terminal.

## Funcionalidades Principais

* **Gerenciamento Centralizado de Projetos**: Registre todos os seus projetos em um único local. Liste, visualize, edite e remova configurações de projeto com comandos simples.
* **Detecção Automática de Python**: Detecta automaticamente as versões do Python instaladas no seu sistema, permitindo que você escolha a versão correta para cada projeto.
* **Suporte a Ambientes Virtuais (Venv)**: Automatiza a criação, ativação e reconstrução de ambientes virtuais (`venv`) para garantir o isolamento completo das dependências.
* **Instalação Automatizada de Dependências**: Instala automaticamente as dependências a partir de um arquivo `requirements.txt` com modos configuráveis (sempre, apenas na primeira vez, ou nunca).
* **Sistema de Log Integrado**: Redirecione toda a saída do seu script para um arquivo de log com rotação automática baseada em data e hora.
* **Interface de Linha de Comando Completa**: Comandos intuitivos para iniciar projetos, abrir um terminal com o `venv` ativado, executar o shell do Python ou abrir o diretório do projeto no Explorer.
* **Instalador de Python**: Inclui um comando para baixar e instalar versões específicas do Python diretamente da CLI.

## Instalação Rápida

Para instalar e configurar o `pyproj` para uso global, abra um terminal (CMD ou PowerShell) e cole o comando abaixo. Ele irá clonar o projeto e adicioná-lo automaticamente ao PATH do seu sistema.

```cmd
git clone https://github.com/lucashahnndev/PyProjectManager.git && cd PyProjectManager && setx PATH "%PATH%;%cd%"
```

**Importante**: Após a execução do comando, **feche e abra o terminal novamente** para que as alterações entrem em vigor.

Agora você pode usar o comando `pyproj` de qualquer diretório!

## Guia Rápido (Quick Start)

1.  **Navegue até a pasta de um projeto Python existente**:
    ```cmd
    cd C:\caminho\para\meu-projeto-python
    ```

2.  **Inicie a configuração**:
    Execute `pyproj.bat` sem argumentos. Como não há um projeto configurado neste diretório, o assistente interativo será iniciado.

3.  **Siga o Assistente**:
    * Dê um nome ao projeto (ex: `meu-projeto-api`).
    * Escolha uma das versões do Python detectadas.
    * Decida se deseja usar um ambiente virtual (`venv`).
    * Configure o modo de instalação de dependências.
    * Defina o comando de execução principal (ex: `python main.py`).

4.  **Execute seu projeto de qualquer lugar**:
    Após a configuração, você pode ir para qualquer outro diretório e iniciar seu projeto pelo nome ou ID.
    ```cmd
    pyproj /start meu-projeto-api
    ```

5.  **Abra um terminal com o venv ativado**:
    Precisa instalar uma nova biblioteca ou rodar um comando específico?
    ```cmd
    pyproj /prompt meu-projeto-api
    ```
    Isso abrirá um novo CMD com o ambiente virtual já ativado e pronto para uso.

## Referência de Comandos

Todos os comandos disponíveis podem ser visualizados com `pyproj /help`.

---
#### **Gerenciamento de Projetos**
* `/list`: Lista todos os projetos configurados (ID e Nome).
* `/view <id_ou_nome>`: Exibe todas as informações detalhadas de um projeto.
* `/edit <id_ou_nome>`: Permite editar as configurações de um projeto através de um menu interativo.
* `/remove <id_ou_nome>`: Remove um projeto do registro do sistema (não apaga os arquivos).
* `/clear`: Remove TODOS os projetos do registro.

#### **Execução e Interação**
* `/start <id_ou_nome>`: Inicia o projeto, ativando a venv e executando o comando principal.
* `/prompt <id_ou_nome>`: Abre um terminal (CMD) com o ambiente virtual do projeto já ativado.
* `/py_prompt <id_ou_nome>`: Inicia o interpretador Python interativo no contexto da venv.
* `/open_dir <id_ou_nome>`: Abre o diretório raiz do projeto no Windows Explorer.

#### **Gerenciamento de Ambiente e Dependências**
* `/rebuild <id_ou_nome>`: Recria o ambiente virtual (venv) do projeto do zero.
* `/install_dep <id_ou_nome>`: Força a reinstalação das dependências do `requirements.txt`.
* `/add_python <caminho>`: Registra manualmente um novo executável do Python no sistema.
* `/install_python <versao>`: Baixa e instala uma versão específica do Python no sistema.

---
## Como Funciona

O `pyproj` utiliza um arquivo `projects.csv` na sua pasta de instalação para armazenar os metadados de cada projeto. Ao configurar um projeto, ele cria um `project_config.ini` e um script `start_app.bat` local no diretório do seu projeto. Toda a lógica de execução pesada (limpeza de ambiente, ativação de venv, etc.) é centralizada no `start_app_core.bat` para evitar duplicação de código.

## Contribuições

Contribuições são muito bem-vindas! Se você tiver ideias para novas funcionalidades, melhorias ou encontrar algum bug, sinta-se à vontade para abrir uma *Issue* ou enviar um *Pull Request*.

## Licença

Este projeto está licenciado sob a **Licença MIT**. Veja o arquivo `LICENSE` para mais detalhes.

*/

