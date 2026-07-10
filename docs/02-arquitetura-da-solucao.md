# 02. Arquitetura da solução

A arquitetura foi pensada para aproveitar ferramentas simples e disponíveis: arquivos TXT, PowerShell, Power Query, tabelas auxiliares e Power BI.

O foco da solução não foi criar uma arquitetura complexa, mas sim estruturar uma rotina diária de forma confiável, auditável e fácil de operar.

## Fluxo lógico


Arquivo TXT diário
↓
Scripts de cópia
↓
Arquivos ATUAL / ANTERIOR
↓
Arquivos de metadados
↓
Power Query
↓
Tabelas auxiliares
↓
Regras de negócio
↓
Fato de distribuição
↓
Power BI


## Componentes

### 1. Arquivos de entrada

Representam a extração diária das propostas bloqueadas.

No repositório, os arquivos reais foram substituídos por nomes genéricos, como:

- `ARQUIVO_PRODUTO_A_ATUAL.TXT`
- `ARQUIVO_PRODUTO_A_ANTERIOR.TXT`
- `ARQUIVO_PRODUTO_B_ATUAL.txt`
- `ARQUIVO_PRODUTO_B_ANTERIOR.txt`

### 2. Scripts

Os scripts localizam o TXT mais recente, copiam o arquivo para uma pasta padronizada e geram arquivos auxiliares de metadados.

No repositório, os scripts estão na pasta `scripts/`:

- `scriptsempresa.pq`
- `scriptscondominio.pq`
- `batempresa.pq`
- `batcondominio.pq`

### 3. Arquivos ATUAL e ANTERIOR

- **ATUAL:** base usada para a distribuição do dia.
- **ANTERIOR:** snapshot usado para identificar se uma proposta já existia no ciclo anterior.

Essa separação permite classificar propostas como novas ou retornadas.

### 4. Metadados

Os metadados registram informações como:

- nome original do arquivo;
- data de origem;
- data de escrita;
- modo de seleção;
- referência do arquivo anterior.

Eles ajudam a dar rastreabilidade ao processo.

### 5. Power Query

O Power Query centraliza:

- limpeza de campos;
- padronização de tipos;
- identificação da data de referência;
- joins com tabelas auxiliares;
- aplicação das regras de elegibilidade;
- redistribuição por ausência;
- geração da tabela fato final.

As queries ficam em `power-query/`.

### 6. Power BI

O Power BI consome a base final e apresenta a visão operacional, com filtros por status, responsável, unidade, atividade e data.

As imagens demonstrativas ficam em `assets/`.
