# 02\. Arquitetura da solução

A solução do Distribuidor de Propostas Bloqueadas foi estruturada para transformar arquivos operacionais diários em uma base final de distribuição, pronta para consumo no Power BI.

O objetivo da arquitetura não foi criar uma solução complexa, mas sim organizar uma rotina diária de forma confiável, rastreável e fácil de operar. A automação substitui uma sequência manual de abertura de arquivos, filtros, comparações, PROCVs, conferências e redistribuições por um fluxo padronizado com scripts, metadados, Power Query, tabelas auxiliares e uma fato final de distribuição.

A arquitetura é aplicada em dois fluxos semelhantes:

* **Produto A**: fluxo principal de distribuição de propostas bloqueadas de uma frente operacional.
* **Produto B**: fluxo equivalente, com adaptações de estrutura, campos disponíveis e regras específicas.

Em ambos os casos, a essência é a mesma: arquivos TXT alimentam uma camada de preparação, o Power Query aplica as transformações e integra as tabelas auxiliares, e a fato final sustenta a visão operacional no Power BI.

As regras detalhadas de elegibilidade, ausências, redistribuição, snapshot anterior e classificação final estão documentadas em [`03-regras-de-negocio.md`](03-regras-de-negocio.md).

\---

## 1\. Visão geral da arquitetura

```text
Arquivo TXT diário
→ Scripts de cópia
→ Arquivos ATUAL / ANTERIOR
→ Arquivos de metadados
→ Power Query
→ Funções compartilhadas
→ Tabelas auxiliares
→ Fato de distribuição
→ Power BI
```

A solução trabalha com duas referências principais:

* **ATUAL**: base usada para a distribuição do ciclo vigente.
* **ANTERIOR**: snapshot usado para identificar se uma proposta já existia no ciclo anterior.

Essa separação permite que a fato final diferencie propostas novas, propostas retornadas, propostas atribuídas manualmente e propostas redistribuídas por ausência.

\---

## 2\. Camada de entrada

A camada de entrada é composta por arquivos TXT diários extraídos de uma fonte operacional.

No repositório público, os arquivos reais foram substituídos por nomes genéricos, como:

* `ARQUIVO\_PRODUTO\_A\_ATUAL.TXT`
* `ARQUIVO\_PRODUTO\_A\_ANTERIOR.TXT`
* `ARQUIVO\_PRODUTO\_B\_ATUAL.txt`
* `ARQUIVO\_PRODUTO\_B\_ANTERIOR.txt`

A base **ATUAL** representa o arquivo usado na distribuição do ciclo. A base **ANTERIOR** representa o arquivo usado como fotografia do ciclo anterior.

A arquitetura não depende apenas da leitura do arquivo atual. Ela também compara a base atual com a base anterior para identificar continuidade operacional, retorno de propostas e mudança de responsável.

\---

## 3\. Camada de scripts

A camada de scripts prepara os arquivos antes da leitura pelo Power Query.

Os scripts têm quatro responsabilidades principais:

1. localizar o arquivo correto na origem;
2. copiar o arquivo para uma pasta padronizada;
3. gerar o arquivo `ATUAL`;
4. gerar o arquivo `ANTERIOR` e os respectivos metadados.

Essa camada reduz a dependência manual porque o usuário não precisa escolher, renomear ou copiar arquivos todos os dias. O Power Query passa a consumir nomes fixos e previsíveis.

No repositório, os scripts ficam na pasta `scripts/`.

\---

## 4\. Camada de metadados

Os arquivos de metadados registram informações de auditoria sobre os arquivos usados no ciclo.

Eles podem registrar informações como:

* nome original do arquivo;
* data de referência da origem;
* data e hora de escrita;
* modo de seleção do arquivo;
* arquivo usado como referência do dia anterior;
* diferenças entre a data esperada e a data realmente encontrada.

Essa camada é importante porque a rotina diária depende da escolha correta dos arquivos. A automação não apenas gera os arquivos padronizados; ela também registra evidências para rastrear a origem do ciclo processado.

\---

## 5\. Camada de funções compartilhadas

A solução utiliza uma camada de funções auxiliares para evitar repetição de lógica e aumentar a robustez da transformação.

As funções compartilhadas cobrem tarefas como:

* leitura de arquivos no repositório sincronizado;
* leitura de arquivos de metadados no formato chave/valor;
* extração de data a partir do nome do arquivo;
* conversão segura de datas;
* remoção de espaços invisíveis;
* normalização de textos;
* remoção de acentos;
* identificação de campos em branco ou equivalentes a vazio;
* padronização de unidade/filial;
* escolha ponderada de substituto em redistribuição;
* busca flexível de nomes de colunas;
* criação de tabelas vazias com estrutura esperada.

Essa camada reduz risco de erro porque centraliza tratamentos técnicos usados em diferentes queries.

\---

## 6\. Camada Power Query

O Power Query é o centro da arquitetura. Ele transforma os arquivos padronizados em uma fato final de distribuição.

As principais responsabilidades dessa camada são:

* ler arquivos TXT atuais e anteriores;
* promover cabeçalhos;
* aplicar tipagem segura;
* detectar coluna de data da proposta;
* calcular a data de referência do ciclo;
* padronizar unidade/filial;
* selecionar colunas essenciais;
* integrar tabelas auxiliares;
* comparar a base atual com o snapshot anterior;
* calcular responsáveis intermediários e finais;
* enriquecer a base com dados complementares;
* gerar a fato final usada pelo Power BI.

As regras específicas aplicadas nessa camada estão detalhadas no documento de regras de negócio. O papel deste documento é explicar como as camadas se conectam e como a fato é construída.

\---

## 7\. Tabelas auxiliares

A arquitetura usa tabelas auxiliares para separar regra operacional de dado bruto.

As principais tabelas auxiliares são:

### Atribuição manual

Tabela usada para direcionar uma proposta específica para um responsável específico.

### Unidade responsável

Tabela que mapeia unidade/filial para responsável padrão.

### Ausências/férias

Tabela que registra responsáveis indisponíveis em determinado intervalo.

### Redistribuição de ausências

Tabela que define substitutos possíveis e pesos de redistribuição para cada responsável ausente.

\---

## 8\. Fato de distribuição

A fato de distribuição é a tabela final produzida pelo Power Query. Cada linha representa uma proposta elegível para distribuição no ciclo do dia.

Ela consolida informações de várias camadas:

* dados da proposta no arquivo atual;
* data de referência do ciclo;
* informações da base anterior;
* responsável ajustado manualmente, quando houver;
* responsável mapeado pela unidade;
* responsável de destino calculado;
* responsável redistribuído, quando aplicável;
* responsável final;
* indicadores de ausência;
* informações de parceiro;
* informações de atividade e valor;
* classificação final da proposta.

A fato não é apenas uma cópia do TXT. Ela é o resultado da integração entre arquivos diários, metadados, funções compartilhadas, tabelas auxiliares e regras de negócio.

\---

## 9\. Construção da fato a partir do arquivo atual

A primeira parte da fato lê o arquivo `ATUAL` e prepara a base do ciclo.

Essa etapa executa atividades como:

* leitura do TXT padronizado;
* promoção de cabeçalhos;
* seleção de colunas essenciais;
* conversão de tipos;
* identificação da data da proposta;
* padronização da unidade;
* criação da data de referência do ciclo;
* criação de chaves internas para comparação e enriquecimento.

O arquivo atual é a base principal da distribuição. A partir dele, a query decide quais propostas seguem para a fato final e quais serão descartadas conforme as regras documentadas no `03-regras-de-negocio.md`.

\---

## 10\. Construção do snapshot anterior

A segunda parte da fato lê o arquivo `ANTERIOR` e cria um snapshot resumido do ciclo anterior.

Esse snapshot não tem o mesmo papel da base atual. Ele serve para recuperar informações de continuidade, principalmente:

* se a proposta já existia antes;
* qual era o responsável anterior;
* qual era a data-base do ciclo anterior.

Depois de tratado, o snapshot é reduzido para uma visão por proposta e integrado à base atual por meio do identificador da proposta.

Essa etapa é o que permite separar propostas novas de propostas retornadas.

\---

## 11\. Integração com atribuição, unidade e ausências

A fato integra três camadas de decisão operacional:

1. **Atribuição manual**: trata exceções específicas por proposta.
2. **Unidade responsável**: define o responsável padrão quando não há atribuição manual.
3. **Ausências e redistribuição**: ajusta o responsável final quando o destino está indisponível.

A lógica detalhada de prioridade e redistribuição fica no documento de regras de negócio, mas arquiteturalmente essas três camadas são responsáveis por transformar uma proposta bruta em uma proposta com responsável final definido.

\---

## 12\. Enriquecimento por parceiro e atividade

Além da distribuição em si, a fato também pode ser enriquecida com informações complementares.

A camada de parceiro/carteirização traz informações como:

* código de parceiro normalizado;
* nome do parceiro;
* segmentação;
* indicador de correspondência.

A camada de atividade e valor adiciona informações relacionadas a regras de negócio aplicadas sobre atividade, valor em risco, nova regra e inspeção.

Esses enriquecimentos tornam a fato mais útil para análise no Power BI, sem transformar a fonte bruta em uma base manualmente tratada.

\---

## 13\. Saída final da fato

A saída final da fato reúne os campos necessários para operação e análise.

Exemplos de campos finais:

* `ID\_PROPOSTA`;
* `DATASET\_DATE`;
* `STATUS\_FINAL`;
* `DATA\_PROPOSTA`;
* `UNIDADE`;
* `NOME\_PARCEIRO`;
* `COD\_PARCEIRO`;
* `SEGMENTACAO\_PARCEIRO`;
* `MATCH\_CARTEIRIZACAO`;
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
* campos de valor;
* campos de regra de atividade;
* `LB\_DATE`.

Essa tabela é a base principal consumida pelo Power BI.

\---

## 14\. Camada visual Power BI

O Power BI consome a fato final para apresentar a visão operacional da distribuição.

A camada visual pode responder perguntas como:

* quantas propostas entraram no ciclo;
* quantas propostas são novas;
* quantas propostas retornaram;
* quais responsáveis receberam propostas;
* quais propostas foram redistribuídas por ausência;
* quais unidades concentram mais volume;
* quais parceiros ou segmentações aparecem na base;
* quais atividades seguem nova regra;
* quais atividades exigem inspeção.

A visualização é consequência da fato. A regra principal está concentrada no Power Query.

\---

## 15\. Síntese da arquitetura

A arquitetura pode ser resumida assim:

```text
TXT ATUAL
→ leitura e padronização
→ data de referência
→ integração com tabelas auxiliares
→ cálculo do responsável final
→ enriquecimento por parceiro e atividade
→ fato final

TXT ANTERIOR
→ leitura e padronização
→ snapshot por proposta
→ responsável anterior
→ comparação com base atual

Fato final
→ status final
→ responsável final
→ classificação nova/retornada
→ flags operacionais
→ base para Power BI
```

A solução funciona porque separa cada responsabilidade em uma camada clara: scripts preparam os arquivos, metadados auditam a origem, funções compartilhadas padronizam tratamentos, Power Query integra e transforma os dados, e Power BI apresenta a leitura final.

As decisões operacionais detalhadas estão documentadas em [`03-regras-de-negocio.md`](03-regras-de-negocio.md).

