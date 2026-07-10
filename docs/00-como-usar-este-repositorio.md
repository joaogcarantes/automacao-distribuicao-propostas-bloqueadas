# 00\. Como usar este repositório

Este repositório foi preparado como um case público de portfólio sobre automação de distribuição de propostas bloqueadas.

A estrutura atual do projeto está organizada em cinco áreas principais:



assets/
docs/
power-query/
sample-data/
scripts/



## Ordem recomendada de leitura

1. `README.md`  
Visão geral do projeto, contexto, arquitetura resumida e padrão de anonimização.
2. `docs/01-contexto-do-problema.md`  
Explica o problema operacional que motivou a automação.
3. `docs/02-arquitetura-da-solucao.md`  
Mostra como arquivos, scripts, Power Query e Power BI se conectam.
4. `docs/03-regras-de-negocio.md`  
Detalha as regras de elegibilidade, atribuição, ausência e classificação final.
5. `docs/04-modelo-de-dados.md`  
Resume a tabela fato e as tabelas auxiliares usadas na solução.

## Onde estão os principais arquivos

### `power-query/`

Contém as queries principais do projeto:

* `fatoempresa.pq`
* `fatocondominio.pq`
* `anteriorempresa.pq`
* `anteriorcondominio.pq`
* `atribuidoresempresa.pq`
* `atribuidorescondominio.pq`
* `feriasempresa.pq`
* `feriascondominio.pq`
* `filialempresa.pq`
* `funcoesempresa.pq`
* `funcoescondominio.pq`

### `scripts/`

Contém scripts de apoio para preparação dos arquivos:

* `scriptsempresa.pq`
* `scriptscondominio.pq`
* `batempresa.pq`
* `batcondominio.pq`

Os arquivos estão com extensão `.pq` por conveniência de publicação, mas representam scripts PowerShell ou BAT anonimizados.

### `sample-data/`

Contém arquivos CSV fictícios para demonstrar a estrutura esperada das bases auxiliares.

### `assets/`

Contém imagens demonstrativas do painel.

## Observação

Os arquivos deste repositório foram anonimizados. Nomes de arquivos, campos, caminhos, produtos, regras e áreas foram substituídos por termos públicos e genéricos.

