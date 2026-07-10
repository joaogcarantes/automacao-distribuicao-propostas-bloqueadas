# Automação de Distribuição de Propostas Bloqueadas

Case de portfólio sobre automação de uma rotina operacional diária de distribuição de propostas bloqueadas. O projeto substitui um processo manual baseado em planilhas, filtros, conferências, PROCVs e redistribuições pontuais por um fluxo automatizado com **PowerShell**, **Power Query**, tabelas auxiliares, snapshots diários e visualização em **Power BI**.

A solução foi criada para transformar uma atividade repetitiva e dependente de intervenção manual em um processo mais rápido, padronizado, rastreável e menos sujeito a inconsistências.

O projeto contempla dois fluxos semelhantes:

* **Produto A**: fluxo principal de distribuição de propostas bloqueadas.
* **Produto B**: fluxo equivalente, com adaptações de estrutura, campos disponíveis e regras específicas.

> \*\*Observação de anonimização:\*\* este repositório usa dados fictícios, nomes genéricos, imagens anonimizadas e estruturas públicas. A solução foi inspirada em uma experiência corporativa real, mas não contém links privados, caminhos reais, nomes internos, nomes de pessoas, dados de clientes, protocolos reais ou informações confidenciais.

\---

## Impacto

A automação reduziu uma rotina operacional que levava cerca de **30 minutos** para **menos de 30 segundos**.

Isso representa uma redução aproximada de **98,33% no tempo de execução** e tornou o processo cerca de **60x mais rápido**.

Além do ganho de tempo, a solução também trouxe benefícios operacionais importantes:

* reduziu a dependência de execução manual;
* padronizou a aplicação das regras de distribuição;
* melhorou a rastreabilidade dos arquivos usados em cada ciclo;
* diminuiu o risco de erro em filtros, fórmulas e conferências;
* automatizou a comparação entre base atual e snapshot anterior;
* incorporou regras de ausência/férias e redistribuição ponderada;
* facilitou a continuidade operacional por meio de scripts, queries e documentação.

\---

## Objetivo

Transformar arquivos operacionais diários em uma base final de distribuição, permitindo acompanhar e operar:

* propostas elegíveis para o ciclo;
* propostas novas e retornadas;
* responsáveis finais por proposta;
* atribuições manuais;
* redistribuições por ausência/férias;
* unidades responsáveis;
* parceiro e segmentação;
* regras de atividade e valor;
* histórico anterior usado como snapshot.

\---

## Estrutura do repositório

```text
automacao-distribuicao-propostas-bloqueadas/
├── assets/
├── docs/
│   ├── 00-como-usar-este-repositorio.md
│   ├── 01-contexto-do-problema.md
│   ├── 02-arquitetura-da-solucao.md
│   ├── 03-regras-de-negocio.md
│   ├── 04-modelo-de-dados.md
├── power-query/
├── sample-data/
├── scripts/
├── LICENSE.md
└── README.md
```

\---

## Arquitetura resumida

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

O modelo separa duas referências operacionais:

* **Arquivo ATUAL**: base usada para a distribuição do ciclo vigente.
* **Arquivo ANTERIOR**: snapshot usado para identificar propostas que já existiam no ciclo anterior.

A explicação completa da arquitetura está em [`docs/02-arquitetura-da-solucao.md`](docs/02-arquitetura-da-solucao.md).

\---

## Principais funcionalidades

* Leitura automatizada de arquivos TXT diários.
* Geração de arquivos `ATUAL` e `ANTERIOR` padronizados.
* Registro de metadados para auditoria da origem dos arquivos.
* Aplicação de regra de elegibilidade por flags e janela de datas.
* Comparação da base atual com snapshot anterior.
* Identificação de propostas novas e retornadas.
* Mapeamento de responsável por unidade.
* Aplicação de atribuição manual por proposta.
* Verificação de responsáveis ausentes.
* Redistribuição ponderada por ausência/férias.
* Enriquecimento com parceiro, código e segmentação.
* Aplicação de regras de atividade e valor.
* Geração de fato final para consumo no Power BI.

As regras detalhadas estão em [`docs/03-regras-de-negocio.md`](docs/03-regras-de-negocio.md).

\---

## Fato de distribuição

A fato de distribuição é a tabela final gerada no Power Query. Cada linha representa uma proposta elegível para distribuição no ciclo do dia.

Ela consolida dados de várias camadas:

* arquivo atual;
* snapshot anterior;
* tabelas de atribuição manual;
* mapa de unidade responsável;
* tabela de ausências/férias;
* tabela de redistribuição;
* carteirização de parceiro;
* regras de atividade e valor.

Exemplos de campos finais:

|Campo|Descrição|
|-|-|
|`ID\_PROPOSTA`|Identificador fictício da proposta|
|`DATASET\_DATE`|Data de referência do ciclo de distribuição|
|`STATUS\_FINAL`|Classificação operacional final da proposta|
|`DATA\_PROPOSTA`|Data original da proposta|
|`UNIDADE`|Unidade ou região associada|
|`ATIVIDADE`|Tipo de atividade/categoria|
|`RESPONSAVEL\_ANTERIOR`|Responsável identificado no snapshot anterior|
|`RESPONSAVEL\_AJUSTADO`|Responsável definido manualmente, quando houver|
|`RESPONSAVEL\_DESTINO`|Responsável calculado antes da redistribuição|
|`RESPONSAVEL\_REDIS`|Responsável substituto em caso de ausência|
|`RESPONSAVEL\_FINAL`|Responsável final após regras e exceções|
|`DESTINO\_EM\_AUSENCIAS`|Indica se o responsável destino estava ausente|
|`SEGMENTACAO\_PARCEIRO`|Segmentação fictícia do parceiro|
|`MATCH\_CARTEIRIZACAO`|Indica se houve correspondência na carteirização|
|`LB\_DATE`|Data-base do snapshot anterior|

A documentação do modelo está em [`docs/04-modelo-de-dados.md`](docs/04-modelo-de-dados.md).

\---

## Tecnologias utilizadas

* Power BI
* Power Query M
* PowerShell
* Batch script
* Excel / CSV
* TXT
* SharePoint / OneDrive como camada de arquivos
* Modelagem de dados operacional
* Documentação técnica e conceitual

\---

## Como navegar

1. Comece por este `README.md` para entender o objetivo geral.
2. Leia [`docs/01-contexto-do-problema.md`](docs/01-contexto-do-problema.md) para entender a dor operacional.
3. Leia [`docs/02-arquitetura-da-solucao.md`](docs/02-arquitetura-da-solucao.md) para entender o desenho técnico.
4. Leia [`docs/03-regras-de-negocio.md`](docs/03-regras-de-negocio.md) para entender elegibilidade, atribuição, ausência, redistribuição e status final.
5. Leia [`docs/04-modelo-de-dados.md`](docs/04-modelo-de-dados.md) para entender a estrutura da fato e das tabelas auxiliares.
6. Consulte `power-query/` para ver as queries M anonimizadas.
7. Consulte `scripts/` para ver os scripts PowerShell/BAT anonimizados.
8. Consulte `sample-data/` para ver bases fictícias de exemplo.
9. Consulte `assets/` para ver imagens demonstrativas anonimizadas.

\---

## Aprendizados

Este projeto demonstra competências em:

* automação de rotinas operacionais;
* tratamento e padronização de arquivos;
* construção de fatos operacionais em Power Query;
* uso de snapshots para comparação histórica;
* aplicação de regras de negócio auditáveis;
* redistribuição ponderada por ausência;
* integração de tabelas auxiliares;
* preparação de bases para dashboards em Power BI;

