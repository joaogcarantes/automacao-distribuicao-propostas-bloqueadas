## Automação de Distribuição de Propostas Bloqueadas

Case de portfólio sobre automação de um processo operacional diário de distribuição de demandas. O projeto substitui uma rotina manual baseada em planilhas, filtros e conferências por um fluxo estruturado com scripts, Power Query, regras de negócio, snapshots diários e visualização em Power BI.

**Observação de anonimização:** este repositório usa nomes, caminhos, arquivos e estruturas fictícias. A solução foi inspirada em uma experiência corporativa real, mas não contém links privados, caminhos de rede reais, nomes internos de áreas, dados de clientes, nomes de pessoas ou materiais confidenciais.

\---

### 1\. Contexto

Em uma operação de análise/subscrição, propostas bloqueadas precisam ser distribuídas diariamente para subscritores responsáveis de acordo com regras de negócio, unidade, histórico, exceções manuais e ausências.

Antes da automação, o processo dependia de etapas manuais como abertura de arquivos, identificação da base do dia, comparação com o dia anterior, PROCVs, filtros por regra de bloqueio, tratamento de exceções e redistribuição quando um responsável estava ausente.

O objetivo do projeto foi criar um fluxo mais confiável, rastreável e simples de operar, reduzindo dependência manual e melhorando a consistência da distribuição diária.

\---

## Impacto

A automação reduziu uma rotina operacional que levava cerca de **30 minutos** para **menos de 30 segundos**, representando uma redução aproximada de **98,33% no tempo de execução** e tornando o processo cerca de **60x mais rápido**.

Além do ganho de tempo, o fluxo também melhorou a rastreabilidade, reduziu dependência manual e padronizou a aplicação das regras de distribuição.

### 2\. Solução

A solução foi organizada em quatro camadas:

* **Entrada de dados:** arquivos TXT diários contendo propostas bloqueadas para dois grupos operacionais fictícios: Produto A e Produto B.
* **Preparação operacional:** scripts PowerShell e arquivos BAT copiam os arquivos de origem, padronizam os nomes de saída e geram arquivos de metadados `.meta` para auditoria da data de referência.
* **Transformação em Power Query:** queries em M fazem limpeza, tipagem, elegibilidade, comparação com snapshot anterior, aplicação de atribuições manuais, mapeamento de responsáveis e redistribuição por ausência.
* **Consumo analítico:** a base final pode alimentar um modelo em Power BI com visão operacional, filtros e segmentações por responsável, status, unidade, data e regra.

Fluxo resumido:

```text
Arquivo TXT diário
→ Scripts de cópia
→ Arquivo ATUAL / ANTERIOR + metadados
→ Power Query
→ Regras de elegibilidade
→ Snapshot e comparação histórica
→ Responsável final
→ Base FATO
→ Power BI
```

\---

### 3\. Principais funcionalidades

* Leitura automática de arquivos TXT diários.
* Geração de base atual e snapshot anterior.
* Registro de metadados com nome original, data de origem e modo de execução.
* Classificação de propostas como novas ou retornadas.
* Aplicação de regras de elegibilidade por flags e janela de datas.
* Mapeamento de responsável por unidade.
* Sobrescrita por atribuição manual quando necessário.
* Redistribuição automática quando o responsável original está ausente (férias, por exemplo).
* Separação lógica entre Produto A e Produto B.
* Padronização de funções compartilhadas em Power Query.
* Preparação de base final para modelo operacional (dashboard) em Power BI.

\---

### 4\. Tecnologias utilizadas

* Power BI
* Power Query M
* PowerShell
* Batch script
* Excel
* TXT / CSV
* SharePoint / OneDrive como camada de arquivos
* Modelagem de dados operacional

\---

### 5\. Resultado esperado

O projeto entrega uma base final de distribuição com propostas elegíveis e seus respectivos responsáveis, considerando:

* data de referência;
* histórico anterior;
* regra de elegibilidade;
* atribuição manual;
* unidade responsável;
* ausência do responsável;
* redistribuição ponderada;
* status final da proposta.

Exemplo de campos de saída:

|Campo|Descrição|
|-|-|
|`ID\\\_PROPOSTA`|Identificador fictício da proposta|
|`DATASET\\\_DATE`|Data de referência da distribuição|
|`STATUS\\\_FINAL`|Classificação final da proposta|
|`DATA\\\_PROPOSTA`|Data original da proposta|
|`UNIDADE`|Unidade ou região responsável|
|`ATIVIDADE`|Tipo de atividade/categoria|
|`RESPONSAVEL\\\_ANTERIOR`|Responsável identificado no snapshot anterior|
|`RESPONSAVEL\\\_AJUSTADO`|Responsável informado manualmente, quando houver|
|`RESPONSAVEL\\\_DESTINO`|Responsável calculado antes da redistribuição|
|`RESPONSAVEL\\\_FINAL`|Responsável final após regras e exceções|
|`DESTINO\\\_EM\\\_AUSENCIAS`|Indica se o responsável destino estava ausente|
|`FLAG\\\_JANELA`|Indicador genérico de regra por janela|
|`FLAG\\\_PRIORIDADE\\\_A`|Indicador genérico de regra prioritária A|
|`FLAG\\\_PRIORIDADE\\\_B`|Indicador genérico de regra prioritária B|
|`VALOR\\\_PREMIO`|Valor financeiro fictício da proposta|
|`LB\\\_DATE`|Data-base do snapshot anterior|

\---

### 6\. Governança e anonimização

Este repositório foi preparado para demonstrar raciocínio técnico, arquitetura de dados e automação operacional sem expor informações internas.

Foram removidos ou substituídos:

* URLs reais de SharePoint;
* caminhos UNC internos;
* nomes de organização, áreas e bibliotecas;
* nomes técnicos de arquivos internos;
* códigos internos de regras;
* nomes de campos sensíveis;
* referências a clientes, documentos ou pessoas;
* prints e evidências visuais com elementos internos.

A lógica foi preservada de forma conceitual para fins de portfólio.

\---

### 7\. Aprendizados

Este projeto demonstra competências em:

* automação de rotinas operacionais;
* tratamento e padronização de arquivos;
* modelagem em Power Query;
* criação de regras de negócio auditáveis;
* desenho de snapshots e comparação histórica;
* governança de dados;
* preparação de bases para dashboards em Power BI.

