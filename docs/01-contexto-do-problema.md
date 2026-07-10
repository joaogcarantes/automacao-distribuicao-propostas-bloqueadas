# 01\. Contexto do problema

O processo original era uma rotina operacional diária de distribuição de propostas bloqueadas. A atividade parecia simples na superfície, mas concentrava várias decisões manuais: escolher o arquivo correto do dia, abrir a base em planilha, comparar com o ciclo anterior, aplicar regras de elegibilidade, consultar exceções, verificar responsáveis, tratar ausências e gerar uma base final para acompanhamento.

Na prática, a rotina dependia muito de quem executava o processo. O conhecimento ficava distribuído entre planilhas, filtros, fórmulas, arquivos salvos em pastas e decisões operacionais tomadas caso a caso. Isso tornava o processo vulnerável a erro humano, retrabalho e perda de rastreabilidade.

A automação foi criada para transformar esse fluxo manual em uma rotina padronizada, auditável e mais simples de sustentar.

\---

## 1\. Processo anterior

Antes da automação, a distribuição era feita com forte dependência de planilhas e conferências manuais.

A rotina envolvia etapas como:

* localizar o arquivo diário correto;
* abrir a base extraída em formato de planilha ou TXT;
* identificar se a base correspondia ao dia esperado;
* comparar a base atual com a base do ciclo anterior;
* aplicar filtros por regras de bloqueio;
* criar ou revisar fórmulas de busca;
* identificar propostas novas e retornadas;
* consultar responsável padrão por unidade;
* verificar exceções de atribuição manual;
* conferir responsáveis ausentes;
* redistribuir casos quando alguém estava de férias ou indisponível;
* revisar inconsistências antes de liberar a base;
* salvar e compartilhar o resultado final.

Esse processo funcionava, mas funcionava porque havia atenção manual constante. A rotina exigia conhecimento do fluxo, cuidado com filtros, domínio das regras e memória operacional sobre exceções.

\---

## 2\. Por que o processo era problemático

O problema não era apenas o tempo gasto. A principal fragilidade era a combinação de **tempo, dependência manual e baixa rastreabilidade**.

Quando uma rotina depende de planilhas abertas manualmente, filtros aplicados na hora e fórmulas revisadas caso a caso, pequenos desvios podem gerar impacto direto na distribuição final. Um filtro esquecido, uma base errada, uma data fora da janela, uma fórmula arrastada incorretamente ou uma ausência não considerada poderiam alterar o responsável final de uma proposta.

Além disso, a lógica do processo ficava pouco visível. Muitas regras estavam implícitas na execução:

* qual arquivo deveria ser usado;
* qual data representava o ciclo correto;
* quais flags tornavam uma proposta elegível;
* como comparar com o ciclo anterior;
* quando manter uma proposta sem data;
* quando considerar uma proposta nova ou retornada;
* como tratar ausência de responsável;
* como redistribuir casos entre substitutos;
* como registrar exceções manuais.

Essa falta de explicitação dificultava auditoria, continuidade e transferência de conhecimento.

\---

## 3\. Dores principais

As principais dores do processo anterior eram:

### Dependência de execução manual

A rotina dependia de uma pessoa saber exatamente o que extrair, abrir, filtrar, comparar e ajustar. Isso criava risco operacional em caso de ausência, troca de responsável ou necessidade de repasse do processo.

### Alto risco de inconsistência

Como a execução passava por planilhas, filtros e fórmulas, havia margem para diferenças entre um ciclo e outro. A mesma regra poderia ser aplicada de forma ligeiramente diferente dependendo da base, do arquivo ou da pessoa executando.

### Baixa rastreabilidade

Sem metadados claros, era mais difícil responder perguntas como:

* qual arquivo foi usado;
* qual era a data de referência;
* qual base serviu como anterior;
* quando a rotina foi executada;
* por que uma proposta foi classificada como nova ou retornada;
* por que um responsável foi substituído.

### Tratamento manual de ausências

A redistribuição por férias ou ausência era um ponto sensível. Quando um responsável estava indisponível, era necessário consultar exceções e redistribuir os casos manualmente ou com apoio de planilhas auxiliares.

Isso aumentava o risco de direcionar propostas para alguém ausente ou de concentrar redistribuições de forma desigual.

### Dificuldade de manutenção

Como a lógica estava espalhada entre arquivos, fórmulas e conhecimento operacional, qualquer mudança exigia cuidado adicional. Alterar uma regra, uma janela de data, um mapeamento de unidade ou uma tabela de substitutos poderia gerar impacto em várias partes do processo.

\---

## 4\. Por que precisava mudar

A rotina precisava deixar de ser uma sequência de ações manuais e passar a ser um fluxo estruturado.

O objetivo não era apenas acelerar a execução. A mudança era necessária para tornar o processo:

* mais confiável;
* mais auditável;
* mais simples de operar;
* menos dependente de conhecimento individual;
* mais fácil de documentar;
* mais seguro para continuidade operacional;
* mais consistente na aplicação das regras.

Com a automação, a regra deixa de depender de filtros e fórmulas montadas no momento da execução. Ela passa a estar documentada e implementada no Power Query, com apoio de tabelas auxiliares controladas.

\---

## 5\. Solução proposta

A solução foi estruturar a rotina em camadas:

```text
Arquivos operacionais diários
→ Scripts de preparação
→ Arquivos ATUAL / ANTERIOR padronizados
→ Metadados de auditoria
→ Power Query
→ Tabelas auxiliares
→ Regras de negócio
→ Fato final de distribuição
→ Power BI
```

A automação passou a centralizar decisões que antes eram manuais:

* identificação do arquivo atual e anterior;
* definição da data de referência;
* aplicação das regras de elegibilidade;
* comparação com o snapshot anterior;
* identificação de propostas novas e retornadas;
* aplicação de atribuição manual;
* mapeamento de responsável por unidade;
* verificação de ausências;
* redistribuição ponderada;
* geração do status final da proposta.

O resultado é uma fato final pronta para consumo operacional e analítico.

\---

## 6\. Ganho prático

A automação reduziu uma rotina que levava cerca de **30 minutos** para **menos de 30 segundos**.

Isso representa uma redução aproximada de **98,33% no tempo de execução** e tornou o processo cerca de **60x mais rápido**.

Mais importante do que o ganho de tempo, a automação também melhorou a qualidade do processo:

* as regras passaram a ser aplicadas sempre da mesma forma;
* a base atual passou a ser comparada com o snapshot anterior de forma padronizada;
* as ausências passaram a ser tratadas automaticamente;
* as redistribuições passaram a seguir pesos definidos;
* os metadados passaram a dar rastreabilidade ao arquivo usado;
* a base final passou a sair pronta para visualização no Power BI.

\---

## 7\. Escopo do case

Este repositório demonstra a solução de forma anonimizada, usando dois grupos operacionais fictícios:

* **Produto A**;
* **Produto B**.

Esses nomes representam segmentos distintos do fluxo, com estruturas semelhantes, mas arquivos, campos e regras organizados separadamente.

O objetivo do case não é reproduzir um ambiente corporativo real, mas demonstrar a arquitetura, a lógica de automação, a modelagem em Power Query e a documentação de um processo operacional complexo de forma segura para portfólio público.

\---

## 8\. Síntese do problema

O problema original pode ser resumido assim:

```text
Antes:
processo manual, dependente de planilhas, filtros, fórmulas e conhecimento individual.

Depois:
fluxo automatizado, rastreável, padronizado e sustentado por scripts, Power Query, tabelas auxiliares e Power BI.
```

A principal mudança foi transformar uma rotina operacional frágil e repetitiva em uma solução documentada, reutilizável e preparada para continuidade.

