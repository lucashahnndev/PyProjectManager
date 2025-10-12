# Roadmap do `pypm` v2.0: Rumo a um Gerenciamento de Projetos Moderno

A versão 2.0 do `pypm` representará um salto fundamental em robustez, conveniência e alinhamento com as melhores práticas do ecossistema Python moderno. A visão é transformar o `pypm` de um orquestrador de scripts para um verdadeiro "launcher" de projetos, que abstrai a complexidade da configuração de ambientes e promove um fluxo de trabalho padronizado e eficiente.

## 1. Core Engine: Adoção do Poetry como Padrão

O coração da v2.0 será a substituição do gerenciamento de dependências via `pip` em loop pelo **Poetry**, a ferramenta padrão da indústria para resolução de dependências e builds reprodutíveis.

* **Instalação Sob Demanda:** O `pypm` não embarcará o Poetry. Em vez disso, na primeira execução, ele detectará um Python compatível no sistema (ou usará sua própria função `/install_python` para baixar um), e instalará uma versão *fixa* e testada do Poetry em um ambiente isolado dentro da própria pasta do `pypm` (`tools/poetry_env`). Isso garante consistência e evita conflitos com versões do Poetry instaladas pelo usuário.
* **Padrão para Novos Projetos:** Todos os novos projetos configurados com `pypm` serão inicializados como projetos Poetry (`poetry init`).
* **Conversor Automático:** Ao configurar um projeto existente que contenha um `requirements.txt`, o `pypm` oferecerá a conversão automática, importando todas as dependências para o `pyproject.toml` usando o comando `poetry add`.

## 2. Estrutura de Projeto Padronizada: A Pasta `.pypm`

Para manter o diretório raiz do projeto do usuário limpo e organizado, toda a infraestrutura do `pypm` será contida em uma única pasta `.pypm`.

* **Centralização de Metadados:** O arquivo de configuração `pypm.ini` será criado dentro de `.pypm/`.
* **Logs Organizados:** A pasta de `LOGS/` será movida para dentro de `.pypm/logs/`.
* **Ambiente Virtual Localizado (Opcional):** O Poetry será configurado para criar o ambiente virtual (`.venv`) dentro da pasta do projeto (em vez do local padrão do Poetry), facilitando a localização e a limpeza. A estrutura ficaria: `.pypm/venv/`.

## 3. Melhoria da Interface de Linha de Comando (CLI)

A CLI será modernizada para seguir padrões mais convencionais, melhorando a usabilidade e a flexibilidade.

* **Novo Padrão de Argumentos:** A sintaxe mudará de `/comando <valor>` para um formato mais familiar: `pypm <comando> [argumentos] --opcao <valor>`.
    * Exemplo antigo: `pypm /start meu-projeto`
    * Exemplo novo: `pypm start meu-projeto`
* **Execução de Tarefas Arbitrárias:**
    * **Execução local:** `pypm run <script.py>` - Executará o script no contexto do ambiente virtual do projeto atual.
    * **Execução remota:** `pypm <id_ou_nome> --run <script.py> [args...]` - Executará um script específico em um projeto registrado, de qualquer lugar do sistema.
* **Comandos de Conveniência:**
    * `pypm shell`: Se executado dentro de um diretório de projeto, ativa o ambiente virtual e abre um novo prompt de comando (`poetry shell`).
    * `pypm init`: Inicia o assistente de configuração no diretório atual.

## 4. Novas Funcionalidades

* **Criação de Atalhos (`.lnk`):**
    * Um novo comando, `pypm <id_ou_nome> --create-shortcut`, será adicionado.
    * Ele criará um atalho (`.lnk`) na área de trabalho do usuário que, ao ser clicado, executará o comando de inicialização do projeto (`FINAL_CMD`). Isso é ideal para transformar projetos Python em "aplicativos" de fácil acesso para usuários finais.
* **Gerenciamento de Dependências via CLI:**
    * `pypm <id_ou_nome> --add <pacote>`: Adicionará uma nova dependência ao projeto usando `poetry add`.
    * `pypm <id_ou_nome> --remove <pacote>`: Removerá uma dependência usando `poetry remove`.

---

Essa evolução consolidará o `pypm` como uma ferramenta única no ecossistema, combinando um orquestrador de múltiplos projetos com as melhores práticas de gerenciamento de dependências e ambiente, tornando-o um "framework de bootstrap" indispensável para qualquer desenvolvedor Python no Windows.

