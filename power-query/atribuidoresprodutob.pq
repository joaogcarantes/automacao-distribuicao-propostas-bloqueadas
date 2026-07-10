// =====================================================
// Query 1: Consolidação da atribuição manual por proposta - Produto B
// =====================================================
let
  Fonte = ATRIBUIR_PROPOSTA_SPO,
  Sel   = Table.SelectColumns(Fonte, {"ID_PROPOSTA","RESPONSAVEL_AJUSTADO"}, MissingField.Ignore),
  Norm  = Table.TransformColumns(
            Sel,
            {
              {"ID_PROPOSTA", each Text.Trim(Text.From(_)), type text},
              {"RESPONSAVEL_AJUSTADO", each Text.Trim(Text.From(_)), type text}
            }
          ),
  AddIx = Table.AddIndexColumn(Norm, "_idx", 1, 1, Int64.Type),
  Grp   = Table.Group(
            AddIx,
            {"ID_PROPOSTA"},
            {
              {"RESPONSAVEL_AJUSTADO", each List.Last(List.RemoveNulls([RESPONSAVEL_AJUSTADO])), type text},
              {"_idx", each List.Max([_idx]), Int64.Type}
            }
          ),
  Out   = Table.Sort(Grp, {{"_idx", Order.Ascending}}),
  Final = Table.RemoveColumns(Out, {"_idx"})
in
  Final


// =====================================================
// Query 2: Fonte auxiliar de atribuição manual de propostas - Produto B
// =====================================================
let
  Site   = "https://tenant.sharepoint.com/sites/projeto",
  Root   = SharePoint.Contents(Site, [ApiVersion=15]),
  Lib    = Root{[Name="Shared Documents"]}[Content],
  Dist   = Lib{[Name="Distribuicao Produto B"]}[Content],
  Pasta  = Dist{[Name="ATRIBUIR_PROPOSTA"]}[Content],
  Arq    = Table.SelectRows(Pasta, each [Name] = "ATRIBUIR_PROPOSTA.xlsx"){0},
  Bin    = Arq[Content],
  Xls    = Excel.Workbook(Bin, null, true),
  Plan   = Xls{[Item="Planilha1",Kind="Sheet"]}[Data],
  Cab    = Table.PromoteHeaders(Plan, [PromoteAllScalars=true]),
  Sel    = Table.SelectColumns(Cab, {"ID_PROPOSTA","RESPONSAVEL_AJUSTADO"}, MissingField.Ignore),
  Typ    = Table.TransformColumnTypes(Sel, {{"ID_PROPOSTA", type text},{"RESPONSAVEL_AJUSTADO", type text}})
in
  Typ
