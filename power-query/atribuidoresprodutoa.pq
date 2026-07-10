// =====================================================
// Query 1: Fonte auxiliar de atribuição manual de propostas
// =====================================================
let
    Site   = "https://tenant.sharepoint.com/sites/projeto",
    Root   = SharePoint.Contents(Site, [ApiVersion=15]),
    Lib    = Root{[Name="Shared Documents"]}[Content],
    Auto   = Lib{[Name="Automacao Produto A"]}[Content],
    Pasta  = Auto{[Name="ATRIBUIR_PROPOSTA"]}[Content],

    // Se houver múltiplas versões, filtre pelo nome
    Arq    = Table.SelectRows(Pasta, each [Name] = "ATRIBUIR_PROPOSTA.xlsx"){0},
    Bin    = Arq[Content],
    Fonte  = Excel.Workbook(Bin, null, true),
    Plan   = Fonte{[Item="Planilha1",Kind="Sheet"]}[Data],
    Cab    = Table.PromoteHeaders(Plan, [PromoteAllScalars=true]),

    // Mantém apenas as colunas essenciais
    Sel    = Table.SelectColumns(Cab, {"ID_PROPOSTA", "RESPONSAVEL_AJUSTADO"}, MissingField.Ignore),
    Types  = Table.TransformColumnTypes(Sel, {{"ID_PROPOSTA", type text}, {"RESPONSAVEL_AJUSTADO", type text}})
in
    Types


// =====================================================
// Query 2: Consolidação da atribuição manual por proposta
// =====================================================
let
    FonteBase = ATRIBUIR_PROPOSTA_SPO,

    // Mantém apenas as colunas necessárias
    Sel = Table.SelectColumns(FonteBase, {"ID_PROPOSTA", "RESPONSAVEL_AJUSTADO"}, MissingField.Ignore),

    // Limpeza mínima
    Norm = Table.TransformColumns(
        Sel,
        {
            {"ID_PROPOSTA", each Text.Trim(Text.From(_)), type text},
            {"RESPONSAVEL_AJUSTADO", each Text.Trim(Text.From(_)), type text}
        }
    ),

    // Em caso de duplicidade de proposta, pega a última ocorrência
    AddIdx = Table.AddIndexColumn(Norm, "_idx", 1, 1, Int64.Type),
    Grouped = Table.Group(
        AddIdx,
        {"ID_PROPOSTA"},
        {
            {"RESPONSAVEL_AJUSTADO", each List.Last(List.RemoveNulls([RESPONSAVEL_AJUSTADO])), type text},
            {"_idx", each List.Max([_idx]), Int64.Type}
        }
    ),

    // Ordenação opcional
    Out = Table.Sort(Grouped, {{"_idx", Order.Ascending}}),

    // Remove o auxiliar
    Final = Table.RemoveColumns(Out, {"_idx"})
in
    Final

// =====================================================
// Query: Fonte auxiliar de atribuição manual de propostas com limpeza básica
// =====================================================
let
  Site = "https://tenant.sharepoint.com/sites/projeto",
  Root = SharePoint.Contents(Site, [ApiVersion=15]),
  Lib  = Root{[Name="Shared Documents"]}[Content],
  Auto = Lib{[Name="Automacao Produto A"]}[Content],
  Pasta= Auto{[Name="ATRIBUIR_PROPOSTA"]}[Content],

  // Seleciona o arquivo exato
  Arq   = Table.SelectRows(Pasta, each [Name] = "ATRIBUIR_PROPOSTA.xlsx"){0},
  Bin   = Arq[Content],
  Fonte = Excel.Workbook(Bin, null, true),

  // Planilha
  Plan  = Fonte{[Item="Planilha1",Kind="Sheet"]}[Data],
  Cab   = Table.PromoteHeaders(Plan, [PromoteAllScalars=true]),

  // Mantém apenas o necessário
  Sel   = Table.SelectColumns(Cab, {"ID_PROPOSTA","RESPONSAVEL_AJUSTADO"}, MissingField.Ignore),

  // Limpeza simples
  Trim  = Table.TransformColumns(
            Sel,
            {
              {"ID_PROPOSTA", each Text.Trim(Text.From(_)), type text},
              {"RESPONSAVEL_AJUSTADO", each Text.Trim(Text.From(_)), type text}
            }
          ),

  // Remove linhas totalmente vazias, opcional e seguro
  Clean = Table.SelectRows(
            Trim,
            each ([ID_PROPOSTA] <> null and [ID_PROPOSTA] <> "")
              or ([RESPONSAVEL_AJUSTADO] <> null and [RESPONSAVEL_AJUSTADO] <> "")
          )
in
  Clean


