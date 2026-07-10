# 03\. Regras de negócio

Este documento descreve as principais regras de negócio utilizadas na versão demonstrativa do Distribuidor de Propostas Bloqueadas.

As regras foram anonimizadas, mas preservam a lógica central do processo: identificar propostas elegíveis, definir o responsável correto, aplicar exceções operacionais, tratar ausências, redistribuir quando necessário, comparar com o ciclo anterior e gerar uma classificação final para consumo no Power BI.

A solução foi construída para dois fluxos semelhantes, representados neste repositório como **Produto A** e **Produto B**. A lógica geral é a mesma, com pequenas diferenças de campos disponíveis, tabelas auxiliares e critérios específicos de cada frente.

\---

## 1\. Data de referência do ciclo

A distribuição é orientada por uma data de referência chamada `DATASET\_DATE`.

Essa data representa o ciclo operacional da distribuição. Ela é usada como âncora para:

* aplicar a janela de elegibilidade;
* verificar responsáveis ausentes;
* comparar a base atual com o snapshot anterior;
* classificar propostas novas e retornadas;
* manter consistência entre arquivos de entrada e fato final.

Na versão demonstrativa, a data de referência é tratada como D-1 do calendário no fuso operacional de referência.

Conceitualmente:

```text
DATASET\_DATE = data operacional do ciclo de distribuição
```

\---

## 2\. Elegibilidade

Nem toda proposta presente no TXT diário entra na distribuição. A proposta precisa atender a critérios definidos por flags de bloqueio, janela de datas e exceções operacionais.

Na versão pública, os códigos originais foram substituídos por nomes genéricos:

|Flag pública|Função conceitual|
|-|-|
|`FLAG\_JANELA`|Regra condicionada por janela de data|
|`FLAG\_PRIORIDADE\_A`|Regra prioritária A|
|`FLAG\_PRIORIDADE\_B`|Regra prioritária B|
|`FLAG\_PRIORIDADE\_C`|Regra prioritária C|
|`FLAG\_PRIORIDADE\_D`|Regra prioritária D|

Regra conceitual:

```text
Se a proposta possui flag prioritária
→ manter

Se a proposta possui flag de janela e está dentro da janela válida
→ manter

Se a proposta possui flag de janela e não possui data
→ manter conforme exceção operacional

Se a proposta se enquadra em tolerância operacional prevista
→ manter

Caso contrário
→ excluir
```

O objetivo dessa regra é garantir que a fato final contenha apenas propostas relevantes para a distribuição do ciclo.

\---

## 3\. Janela de datas

A janela de datas é usada para avaliar propostas condicionadas à `FLAG\_JANELA`.

A lógica compara a `DATA\_PROPOSTA` com uma janela relativa à `DATASET\_DATE`.

De forma conceitual:

```text
DATASET\_DATE
→ calcula início da janela
→ calcula fim da janela
→ compara DATA\_PROPOSTA
```

Se a proposta estiver dentro da janela válida, ela entra na distribuição. Se estiver fora, ela é removida da base final, salvo quando existir exceção prevista.

\---

## 4\. Propostas sem data

Algumas propostas podem chegar sem data válida de proposta.

Quando a proposta possui uma flag condicional e a data está ausente, a regra permite manter o registro conforme exceção operacional.

Essa exceção evita descartar propostas que dependem de tratamento, mas chegaram com falha ou ausência no campo de data.

Conceitualmente:

```text
FLAG\_JANELA = sim
DATA\_PROPOSTA = vazia
→ manter conforme exceção
```

\---

## 5\. Responsável padrão por unidade

A primeira regra de distribuição usa o responsável padrão da unidade.

A relação é mantida em uma tabela auxiliar:

```text
UNIDADE → RESPONSAVEL padrão
```

Essa tabela permite que a lógica de distribuição seja ajustada sem alterar a fato principal. Se uma unidade mudar de responsável, a manutenção pode ser feita na tabela auxiliar.

No repositório, essa lógica é representada por queries e bases de exemplo relacionadas ao mapeamento de unidade/filial para responsável.

\---

## 6\. Atribuição manual

A atribuição manual permite direcionar uma proposta específica para um responsável específico.

Essa regra tem prioridade sobre o mapeamento padrão por unidade.

Conceitualmente:

```text
Se ID\_PROPOSTA existe na tabela de atribuição manual
→ usar RESPONSAVEL\_AJUSTADO

Senão
→ usar RESPONSAVEL padrão da UNIDADE
```

Essa regra permite tratar exceções operacionais sem modificar a regra geral da distribuição.

\---

## 7\. Cálculo do responsável destino

O responsável destino é o primeiro resultado da regra de distribuição antes da verificação de ausências.

A prioridade é:

1. responsável ajustado manualmente;
2. responsável mapeado pela unidade;
3. responsável original da base, quando aplicável;
4. fallback operacional, quando necessário.

Conceitualmente:

```text
RESPONSAVEL\_DESTINO =
    se existe RESPONSAVEL\_AJUSTADO → usar RESPONSAVEL\_AJUSTADO
    senão se existe RESPONSAVEL\_MAP → usar RESPONSAVEL\_MAP
    senão usar responsável original da base
```

Essa regra separa a definição inicial do responsável da etapa posterior de redistribuição por ausência.

\---

## 8\. Ausências / férias

A tabela de ausências registra responsáveis indisponíveis em determinado intervalo.

Na documentação original, a regra aparece associada a férias. Na versão pública, o conceito pode ser descrito como **ausências**, para deixar a regra mais genérica.

A tabela possui, conceitualmente:

```text
RESPONSAVEL
INICIO
FIM
```

A regra verifica se a `DATASET\_DATE` está dentro do intervalo de ausência:

```text
Se INICIO <= DATASET\_DATE <= FIM
→ responsável está ausente no ciclo
```

A query normaliza os nomes dos responsáveis antes da comparação para evitar problemas com acentos, caixa alta/baixa, espaços extras ou caracteres invisíveis.

\---

## 9\. Destino em ausência

Depois de calcular o `RESPONSAVEL\_DESTINO`, a fato verifica se esse responsável está ausente na data de referência.

Se o responsável destino estiver ausente, a proposta passa para a etapa de redistribuição.

Conceitualmente:

```text
RESPONSAVEL\_DESTINO está na lista de ausências ativas?

Sim
→ DESTINO\_EM\_AUSENCIAS = verdadeiro
→ acionar redistribuição

Não
→ DESTINO\_EM\_AUSENCIAS = falso
→ manter destino original
```

Essa regra evita direcionar propostas para responsáveis indisponíveis.

\---

## 10\. Redistribuição por peso

Quando um responsável está ausente, a redistribuição usa uma tabela auxiliar de substitutos.

A tabela possui, conceitualmente:

```text
RESPONSAVEL\_ORIGINAL
RESPONSAVEL\_SUBSTITUTO
PESO
```

Quando há mais de um substituto possível, a seleção considera os pesos definidos.

A escolha é determinística, baseada na chave da proposta, para evitar que a distribuição mude aleatoriamente a cada atualização.

Conceitualmente:

```text
RESPONSAVEL\_ORIGINAL + ID\_PROPOSTA + PESO
→ RESPONSAVEL\_SUBSTITUTO
```

Fluxo da regra:

```text
Se RESPONSAVEL\_DESTINO não está ausente
→ RESPONSAVEL\_FINAL = RESPONSAVEL\_DESTINO

Se RESPONSAVEL\_DESTINO está ausente
→ buscar substitutos possíveis
→ aplicar regra ponderada
→ RESPONSAVEL\_FINAL = RESPONSAVEL\_SUBSTITUTO
```

Essa regra mantém previsibilidade e reduz redistribuições manuais.

\---

## 11\. Responsável final

O responsável final é o resultado consolidado da distribuição.

Ele considera:

* atribuição manual;
* responsável padrão por unidade;
* responsável original da base;
* ausências;
* redistribuição ponderada.

Conceitualmente:

```text
Se houve redistribuição por ausência
→ RESPONSAVEL\_FINAL = RESPONSAVEL\_REDIS

Caso contrário
→ RESPONSAVEL\_FINAL = RESPONSAVEL\_DESTINO
```

Esse campo é a principal referência para a visualização de distribuição no Power BI.

\---

## 12\. Snapshot anterior

A base anterior é usada para identificar se a proposta já existia no ciclo anterior.

O snapshot consolida uma linha por proposta e guarda, principalmente:

```text
ID\_PROPOSTA
RESPONSAVEL\_ANTERIOR
LB\_DATE
```

A base atual é cruzada com esse snapshot para classificar a proposta como nova ou retornada.

Essa regra é importante porque a distribuição do dia não depende apenas do estado atual. Ela também precisa entender continuidade operacional.

\---

## 13\. Nova vs retornada

A classificação nova/retornada é feita a partir do resultado do merge com o snapshot anterior.

Conceitualmente:

```text
Sem RESPONSAVEL\_ANTERIOR
→ NOVA

RESPONSAVEL\_ANTERIOR = RESPONSAVEL\_FINAL
→ RETORNADA com mesmo responsável

RESPONSAVEL\_ANTERIOR diferente de RESPONSAVEL\_FINAL
→ RETORNADA com outro responsável
```

Essa leitura ajuda a operação a entender se o volume do dia é composto por propostas novas ou por propostas que retornaram de ciclos anteriores.

\---

## 14\. Classificação final

A fato cria um `STATUS\_FINAL` para consolidar a interpretação operacional.

Esse status combina:

* proposta nova ou retornada;
* atribuição manual;
* ausência do responsável;
* redistribuição.

Exemplos de status finais na versão pública:

* `NOVA`
* `RETORNADA`
* `NOVA (ATRIBUÍDA)`
* `RETORNADA (ATRIBUÍDA)`
* `NOVA (AUSÊNCIAS)`
* `RETORNADA (AUSÊNCIAS)`
* `NOVA (ATRIBUÍDA AUSÊNCIAS)`
* `RETORNADA (AUSÊNCIAS ATRIBUÍDA)`

Esses rótulos facilitam a leitura no Power BI porque resumem várias regras em um único campo operacional.

\---

## 15\. Carteirização / parceiro 

A fato de um dos produtos é enriquecida com uma tabela auxiliar de carteirização.

Essa etapa usa uma chave normalizada de parceiro para buscar informações complementares, como:

* nome do parceiro;
* código do parceiro normalizado;
* segmentação;
* indicador de correspondência.

A chave é tratada para remover caracteres não numéricos e zeros à esquerda.

Quando não há correspondência, a fato marca o registro como `SEM MATCH`, permitindo identificar lacunas de cadastro ou divergências entre bases.

\---

## 16\. Tratamento de duplicidades

A fato usa estratégias para reduzir duplicidades indesejadas.

Exemplos:

* criação de índice por proposta;
* consolidação de uma linha por proposta no snapshot anterior;
* deduplicação de tabelas auxiliares por chave;
* uso da última ocorrência válida quando há mais de uma relação para a mesma chave.

Essa camada evita que duplicidades em arquivos auxiliares distorçam a distribuição final.

\---

## 17\. Tipagem e limpeza

A solução aplica coerções de tipo antes da saída final.

São tratados campos como:

* datas;
* números;
* textos;
* lógicos;
* flags;
* responsáveis;
* unidades;
* códigos de parceiro.

Essa etapa reduz erros no Power BI e melhora a consistência da modelagem.

\---

## 19\. Saída operacional

A saída final da regra de negócio é uma fato de distribuição com colunas prontas para análise.

Campos típicos:

* `ID\_PROPOSTA`;
* `DATASET\_DATE`;
* `STATUS\_FINAL`;
* `DATA\_PROPOSTA`;
* `UNIDADE`;
* `ATIVIDADE`;
* `RESPONSAVEL\_ANTERIOR`;
* `RESPONSAVEL\_AJUSTADO`;
* `RESPONSAVEL\_MAP`;
* `RESPONSAVEL\_DESTINO`;
* `RESPONSAVEL\_REDIS`;
* `RESPONSAVEL\_FINAL`;
* `DESTINO\_EM\_AUSENCIAS`;
* `AUSENCIA\_ANTERIOR`;
* `AUSENCIA\_DESTINO`;
* flags de elegibilidade;
* campos de parceiro;
* campos de valor;
* `LB\_DATE`.

\---

## 20\. Síntese das regras

O fluxo de decisão pode ser resumido assim:

```text
1. Ler arquivo atual
2. Calcular DATASET\_DATE
3. Aplicar elegibilidade
4. Definir responsável destino
5. Verificar ausência
6. Redistribuir, se necessário
7. Ler snapshot anterior
8. Classificar como nova ou retornada
9. Aplicar status final
10. Enriquecer com parceiro e regras de valor
11. Gerar fato final para Power BI
```

A força do modelo está em separar as exceções em tabelas auxiliares, mantendo a fato principal como uma consolidação rastreável das regras de distribuição.

