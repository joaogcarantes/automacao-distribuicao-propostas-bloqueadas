# 04. Modelo de dados

A solução utiliza uma tabela fato principal e tabelas auxiliares simples. O modelo foi pensado para ser operacional, direto e fácil de auditar.

## 1. Tabela fato: distribuição

A tabela fato representa a saída final da automação. Cada linha corresponde a uma proposta elegível para distribuição.

| Campo | Tipo | Descrição |
|---|---|---|
| `ID_PROPOSTA` | Texto | Identificador fictício da proposta |
| `DATASET_DATE` | Data | Data de referência da distribuição |
| `DATA_PROPOSTA` | Data | Data original da proposta |
| `DATA_PROPOSTA_TXT` | Texto | Data formatada para conferência |
| `STATUS_FINAL` | Texto | Classificação operacional final |
| `UNIDADE` | Texto | Unidade ou região associada à proposta |
| `ATIVIDADE` | Texto | Categoria operacional da proposta |
| `RESPONSAVEL_ANTERIOR` | Texto | Responsável identificado no snapshot anterior |
| `RESPONSAVEL_AJUSTADO` | Texto | Responsável definido manualmente, quando houver |
| `RESPONSAVEL_MAP` | Texto | Responsável padrão vindo do mapa de unidade |
| `RESPONSAVEL_DESTINO` | Texto | Responsável calculado antes da redistribuição |
| `RESPONSAVEL_REDIS` | Texto | Responsável substituto em caso de ausência |
| `RESPONSAVEL_FINAL` | Texto | Responsável final após todas as regras |
| `DESTINO_EM_AUSENCIAS` | Lógico | Indica se o responsável destino estava ausente |
| `FLAG_JANELA` | Texto | Indicador genérico de regra por janela |
| `FLAG_PRIORIDADE_A` | Texto | Indicador genérico de prioridade A |
| `FLAG_PRIORIDADE_B` | Texto | Indicador genérico de prioridade B |
| `FLAG_PRIORIDADE_C` | Texto | Indicador genérico de prioridade C |
| `FLAG_PRIORIDADE_D` | Texto | Indicador genérico de prioridade D |
| `VALOR_PREMIO` | Número | Valor financeiro fictício |
| `VALOR_PREMIO_LIQUIDO` | Número | Valor líquido fictício |
| `VALOR_RISCO` | Número | Valor de risco fictício |
| `LB_DATE` | Data | Data-base do snapshot anterior |

## 2. Tabelas auxiliares

### 2.1. Unidade responsável

Define o responsável padrão de cada unidade.

Exemplo de campos:

| Campo | Descrição |
|---|---|
| `UNIDADE` | Unidade ou regional |
| `RESPONSAVEL` | Responsável padrão |
| `REGIAO` | Agrupamento regional, quando aplicável |

No repositório, essa lógica aparece em arquivos como:

- `filialempresa.pq`
- `filial_responsavel_exemplo.csv`

### 2.2. Atribuição manual

Permite sobrescrever a distribuição padrão de uma proposta específica.

| Campo | Descrição |
|---|---|
| `ID_PROPOSTA` | Identificador da proposta |
| `RESPONSAVEL_AJUSTADO` | Responsável definido manualmente |

Arquivos relacionados:

- `atribuidoresempresa.pq`
- `atribuidorescondominio.pq`

### 2.3. Ausências

Registra períodos em que um responsável não deve receber propostas.

| Campo | Descrição |
|---|---|
| `RESPONSAVEL` | Responsável ausente |
| `INICIO` | Data inicial da ausência |
| `FIM` | Data final da ausência |

Arquivos relacionados:

- `feriasempresa.pq`
- `feriascondominio.pq`
- `ferias_exemplo.csv`

### 2.4. Redistribuição de ausências

Define substitutos possíveis e pesos de redistribuição.

| Campo | Descrição |
|---|---|
| `RESPONSAVEL_ORIGINAL` | Responsável ausente |
| `RESPONSAVEL_SUBSTITUTO` | Responsável substituto |
| `PESO` | Peso usado na distribuição |

Arquivo de exemplo:

- `redistribuicao_ferias_exemplo.csv`

## 3. Separação por fluxo

O projeto mantém dois fluxos principais:

- Empresa;
- Condomínio.

A separação permite preservar diferenças de arquivo, regras e tratamento, sem misturar a lógica dos dois processos.
