# 03\. Regras de negócio

Este documento resume as regras utilizadas na versão demonstrativa do projeto.

As regras foram anonimizadas, mas mantêm a lógica central do processo: identificar propostas elegíveis, definir responsável, aplicar exceções e gerar uma classificação final.

## 1\. Elegibilidade

A proposta entra na distribuição se atender a critérios definidos por flags de bloqueio e janela de datas.

Na versão pública, os códigos originais foram substituídos por nomes genéricos:

|Flag pública|Função conceitual|
|-|-|
|`FLAG\\\_JANELA`|Regra condicionada por janela de data|
|`FLAG\\\_PRIORIDADE\\\_A`|Regra prioritária A|
|`FLAG\\\_PRIORIDADE\\\_B`|Regra prioritária B|
|`FLAG\\\_PRIORIDADE\\\_C`|Regra prioritária C|
|`FLAG\\\_PRIORIDADE\\\_D`|Regra prioritária D|

Exemplo conceitual:

* flags prioritárias entram automaticamente;
* flags condicionais entram apenas dentro da janela definida;
* propostas sem data podem seguir regra específica de exceção;
* registros fora da regra são removidos da base final.

## 2\. Responsável padrão

A primeira tentativa de distribuição usa o responsável padrão da unidade.



UNIDADE → RESPONSAVEL padrão



Essa relação é carregada por uma tabela auxiliar, representada no repositório por arquivos como `filialempresa.pq` e bases de exemplo em `sample-data/`.

## 3\. Atribuição manual

Quando existe uma atribuição explícita para uma proposta, essa atribuição tem prioridade sobre o mapeamento padrão.



se ID\_PROPOSTA existe em ATRIBUIR\_PROPOSTA:
usar RESPONSAVEL\_AJUSTADO
senão:
usar RESPONSAVEL padrão da UNIDADE



Essa regra permite tratar exceções sem alterar a lógica central da distribuição.

## 4\. Ausências

Se o responsável definido estiver ausente na data de referência, a proposta pode ser redirecionada para outro responsável.

Na versão pública, o termo `FERIAS` foi substituído por `AUSENCIAS`, para deixar a regra mais genérica.

## 5\. Redistribuição por peso

Quando há mais de um possível substituto, a redistribuição pode considerar pesos.

A lógica usa uma escolha determinística baseada na chave da proposta, evitando seleção aleatória a cada atualização.



RESPONSAVEL\_ORIGINAL + ID\_PROPOSTA + PESO → RESPONSAVEL\_SUBSTITUTO



## 6\. Snapshot anterior

A base anterior é usada para identificar se uma proposta já existia no ciclo anterior.

Isso permite classificar a proposta como:

* nova;
* retornada com mesmo responsável;
* retornada com outro responsável.

## 7\. Classificação final

A proposta recebe um status operacional, por exemplo:

* `NOVA`
* `RETORNADA`
* `NOVA (ATRIBUÍDA)`
* `RETORNADA (ATRIBUÍDA)`
* `NOVA (AUSÊNCIAS)`
* `RETORNADA (AUSÊNCIAS)`

Esses rótulos ajudam a operação a entender a origem da proposta e o motivo da distribuição final.

