# 04. Modelo de dados

A solução utiliza uma tabela fato principal e um conjunto de tabelas auxiliares para transformar arquivos operacionais diários em uma base final de distribuição.

O modelo foi pensado para ser **operacional, direto e auditável**. A ideia não é criar um modelo dimensional complexo, mas sim organizar as regras necessárias para responder, com consistência, três perguntas centrais:

```text
1. Esta proposta deve entrar na distribuição do ciclo?
2. Quem deveria receber esta proposta?
3. O responsável final mudou por regra, exceção, ausência ou histórico anterior?
```

A tabela fato concentra o resultado final da automação. As tabelas auxiliares guardam regras, exceções e parâmetros que podem mudar sem alterar a estrutura principal da query.

---

## 1. Visão geral do modelo

```text
TXT ATUAL
→ Fato de distribuição
← Snapshot anterior
← Atribuições manuais
← Unidade responsável
← Ausências/férias
← Redistribuição por ausência
← Carteirização de parceiro
← Regras de atividade e valor
```

A fato final é o ponto de consolidação do processo. Ela recebe dados do arquivo atual, compara com o arquivo anterior e incorpora informações das tabelas auxiliares para gerar a distribuição final.

---

## 2. Tabela fato: distribuição

A tabela fato representa a saída final da automação. Cada linha corresponde a uma proposta elegível para distribuição no ciclo de referência.

Ela não é apenas uma cópia do TXT diário. Ela já contém o resultado das principais regras do processo:

- elegibilidade;
- comparação com snapshot anterior;
- atribuição manual;
- mapeamento por unidade;
- ausência/férias;
- redistribuição ponderada;
- enriquecimento por parceiro;
- classificação final.

---

## 3. Principais campos da fato

| Campo | Tipo | Descrição |
|---|---|---|
| `ID_PROPOSTA` | Texto | Identificador fictício da proposta |
| `DATASET_DATE` | Data | Data de referência do ciclo de distribuição |
| `STATUS_FINAL` | Texto | Classificação operacional final da proposta |
| `DATA_PROPOSTA` | Data | Data original da proposta |
| `DATA_PROPOSTA_TXT` | Texto | Data original formatada para conferência |
| `UNIDADE` | Texto | Unidade, filial ou região associada à proposta |
| `ATIVIDADE` | Texto | Categoria ou atividade operacional da proposta |
| `NOME_PARCEIRO` | Texto | Nome fictício do parceiro/corretor, quando disponível |
| `COD_PARCEIRO` | Texto | Código fictício e normalizado do parceiro |
| `SEGMENTACAO_PARCEIRO` | Texto | Segmentação fictícia do parceiro |
| `MATCH_CARTEIRIZACAO` | Texto | Indica se houve correspondência na base de carteirização |
| `RESPONSAVEL_ANTERIOR` | Texto | Responsável identificado no snapshot anterior |
| `RESPONSAVEL_AJUSTADO` | Texto | Responsável definido manualmente, quando houver exceção |
| `RESPONSAVEL_MAP` | Texto | Responsável padrão vindo do mapa de unidade |
| `RESPONSAVEL_DESTINO` | Texto | Responsável calculado antes da verificação de ausência |
| `RESPONSAVEL_REDIS` | Texto | Responsável substituto definido pela redistribuição |
| `RESPONSAVEL_FINAL` | Texto | Responsável final após todas as regras |
| `DESTINO_EM_AUSENCIAS` | Lógico | Indica se o responsável destino estava ausente no ciclo |
| `AUSENCIA_ANTERIOR` | Lógico | Indica se o responsável anterior estava ausente no ciclo |
| `AUSENCIA_DESTINO` | Lógico | Indica se o responsável destino estava ausente no ciclo |
| `FLAG_JANELA` | Texto | Indicador genérico de regra por janela |
| `FLAG_PRIORIDADE_A` | Texto | Indicador genérico de prioridade A |
| `FLAG_PRIORIDADE_B` | Texto | Indicador genérico de prioridade B |
| `FLAG_PRIORIDADE_C` | Texto | Indicador genérico de prioridade C |
| `FLAG_PRIORIDADE_D` | Texto | Indicador genérico de prioridade D |
| `VALOR_PREMIO` | Número | Valor financeiro fictício da proposta |
| `VALOR_PREMIO_LIQUIDO` | Número | Valor líquido fictício, quando aplicável |
| `VALOR_RISCO` | Número | Valor de risco fictício |
| `VALOR_RISCO_START` | Número | Valor de referência usado na regra de atividade/valor |
| `REGRA_VALOR_RISCO` | Texto | Classificação da regra de valor/atividade |
| `LB_DATE` | Data | Data-base do snapshot anterior |

---

## 4. Papel da fato no processo

A fato é a camada que transforma o processo operacional em uma base analítica.

Ela permite responder perguntas como:

- quais propostas entraram no ciclo;
- quais propostas foram consideradas elegíveis;
- quais propostas são novas;
- quais propostas retornaram do ciclo anterior;
- qual era o responsável anterior;
- qual responsável foi calculado inicialmente;
- qual responsável recebeu a proposta após as regras;
- quais propostas sofreram redistribuição por ausência;
- quais propostas tiveram atribuição manual;
- quais unidades ou parceiros concentram mais volume.

Por isso, a fato é o centro do modelo. As demais tabelas servem para alimentar suas regras.

---

## 5. Tabela auxiliar: unidade responsável

A tabela de unidade responsável define o responsável padrão para cada unidade, filial ou regional.

Exemplo de estrutura:

| Campo | Descrição |
|---|---|
| `UNIDADE` | Unidade, filial ou regional |
| `RESPONSAVEL` | Responsável padrão da unidade |
| `REGIAO` | Agrupamento regional, quando aplicável |

Uso no modelo:

```text
UNIDADE → RESPONSAVEL_MAP
```

Essa tabela é usada quando a proposta não possui atribuição manual. Ela evita que a regra de responsável fique fixa dentro da query principal.

---

## 6. Tabela auxiliar: atribuição manual

A tabela de atribuição manual permite sobrescrever o responsável padrão de uma proposta específica.

Exemplo de estrutura:

| Campo | Descrição |
|---|---|
| `ID_PROPOSTA` | Identificador da proposta |
| `RESPONSAVEL_AJUSTADO` | Responsável definido manualmente |

Uso no modelo:

```text
Se ID_PROPOSTA existe na atribuição manual
→ usar RESPONSAVEL_AJUSTADO

Senão
→ usar responsável padrão da unidade
```

Essa tabela trata exceções sem alterar a lógica geral da distribuição.

---

## 7. Tabela auxiliar: ausências/férias

A tabela de ausências registra períodos em que um responsável não deve receber novas propostas.

Exemplo de estrutura:

| Campo | Descrição |
|---|---|
| `RESPONSAVEL` | Responsável ausente |
| `INICIO` | Data inicial da ausência |
| `FIM` | Data final da ausência |

Uso no modelo:

```text
Se INICIO <= DATASET_DATE <= FIM
→ responsável está ausente no ciclo
```

A tabela é usada para verificar se o `RESPONSAVEL_DESTINO` está indisponível. Quando isso acontece, a proposta segue para a redistribuição.

---

## 8. Tabela auxiliar: redistribuição de ausências

A tabela de redistribuição define os substitutos possíveis para cada responsável ausente.

Exemplo de estrutura:

| Campo | Descrição |
|---|---|
| `RESPONSAVEL_ORIGINAL` | Responsável ausente |
| `RESPONSAVEL_SUBSTITUTO` | Responsável substituto |
| `PESO` | Peso usado na redistribuição |

Uso no modelo:

```text
RESPONSAVEL_ORIGINAL + ID_PROPOSTA + PESO
→ RESPONSAVEL_SUBSTITUTO
```

A redistribuição é ponderada e determinística. Isso significa que propostas são distribuídas respeitando os pesos definidos, mas sem seleção aleatória a cada atualização.

---

## 9. Tabela auxiliar: snapshot anterior

O snapshot anterior é derivado do arquivo `ANTERIOR`.

Ele não é uma tabela manual, mas uma visão gerada pelo Power Query a partir da base anterior.

Exemplo de estrutura final:

| Campo | Descrição |
|---|---|
| `ID_PROPOSTA` | Identificador da proposta no ciclo anterior |
| `RESPONSAVEL_ANTERIOR` | Responsável calculado no ciclo anterior |
| `LB_DATE` | Data-base do snapshot anterior |

Uso no modelo:

```text
Base atual + Snapshot anterior
→ identificar NOVA ou RETORNADA
```

Essa camada permite classificar a proposta de acordo com seu histórico.

---

## 10. Tabela auxiliar: carteirização de parceiro

A tabela de carteirização enriquece a fato com informações de parceiro.

Exemplo de estrutura:

| Campo | Descrição |
|---|---|
| `COD_PARCEIRO` | Código do parceiro |
| `NOME_PARCEIRO` | Nome do parceiro |
| `SEGMENTACAO_PARCEIRO` | Segmentação do parceiro |

Antes do cruzamento, o código do parceiro é normalizado para evitar problemas com zeros à esquerda, formatação numérica ou caracteres não numéricos.

Uso no modelo:

```text
COD_PARCEIRO normalizado
→ NOME_PARCEIRO
→ SEGMENTACAO_PARCEIRO
→ MATCH_CARTEIRIZACAO
```

Quando não há correspondência, a fato pode marcar o registro como `SEM MATCH`.

---

## 11. Tabela auxiliar: regras de atividade e valor

A tabela de regras de atividade e valor permite classificar propostas de acordo com atividade e limites de referência.

Exemplo de estrutura conceitual:

| Campo | Descrição |
|---|---|
| `ATIVIDADE` | Atividade ou categoria operacional |
| `VALOR_RISCO_ANTIGO` | Valor de referência anterior |
| `VALOR_RISCO_NOVO` | Valor de referência novo |

A query cria chaves normalizadas para aumentar a taxa de correspondência entre a atividade da proposta e a tabela auxiliar.

Uso no modelo:

```text
ATIVIDADE + VALOR_RISCO
→ REGRA_VALOR_RISCO
```

Exemplos de saída:

- `SEM ALTERAÇÃO`;
- `INSPEÇÃO (NOVA REGRA)`;
- `EMITE DIRETO (NOVA REGRA)`.

---

## 12. Separação por fluxo

O projeto mantém dois fluxos principais:

- **Produto A**;
- **Produto B**.

A separação permite preservar diferenças de arquivo, campos e regras sem misturar a lógica dos dois processos.

Apesar da separação, os dois fluxos seguem o mesmo desenho conceitual:

```text
TXT diário
→ regras de elegibilidade
→ responsável destino
→ ausência/redistribuição
→ snapshot anterior
→ fato final
```

---

## 13. Relação entre fato e auxiliares

A relação entre as tabelas pode ser resumida assim:

```text
FATO_DISTRIBUICAO
├── ID_PROPOSTA → ATRIBUICAO_MANUAL
├── ID_PROPOSTA → SNAPSHOT_ANTERIOR
├── UNIDADE → UNIDADE_RESPONSAVEL
├── RESPONSAVEL_DESTINO → AUSENCIAS
├── RESPONSAVEL_DESTINO → REDISTRIBUICAO_AUSENCIAS
├── COD_PARCEIRO → CARTEIRIZACAO_PARCEIROS
└── ATIVIDADE → REGRAS_ATIVIDADE_VALOR
```

Essas relações são implementadas no Power Query por merges, agrupamentos e transformações, não necessariamente como relacionamentos físicos no modelo Power BI.

---

## 14. Decisão de modelagem

A solução prioriza uma fato final já tratada em vez de transferir toda a lógica para medidas no Power BI.

Essa decisão foi tomada porque a rotina é operacional. O mais importante é que a base final já saia com:

- proposta elegível;
- responsável final;
- status final;
- flags de ausência;
- histórico anterior;
- dados complementares de parceiro e regra.

Com isso, o Power BI fica responsável principalmente pela visualização e análise, enquanto o Power Query concentra a regra de preparação da base.

---

## 15. Síntese do modelo

O modelo de dados pode ser resumido assim:

```text
Tabela fato
→ consolida a distribuição final

Tabelas auxiliares
→ armazenam regras, exceções e parâmetros

Power Query
→ aplica as regras e gera a fato

Power BI
→ consome a fato final para visualização operacional
```

A principal vantagem dessa abordagem é tornar o processo mais rastreável, mais fácil de auditar e menos dependente de ajustes manuais na camada visual.
