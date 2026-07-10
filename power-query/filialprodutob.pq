let
    Site   = "https://tenant.sharepoint.com/sites/projeto",
    Root   = SharePoint.Contents(Site, [ApiVersion=15]),
    Docs   = Root{[Name="Shared Documents"]}[Content],
    Auto   = Docs{[Name="Automacao Produto A"]}[Content],
    Pasta  = Auto{[Name="UNIDADE_RESPONSAVEL"]}[Content],
    Arq    = Table.SelectRows(Pasta, each [Name] = "UNIDADE_RESPONSAVEL.xlsx"){0},
    Bin    = Arq[Content],
    Fonte  = Excel.Workbook(Bin, null, true),
    Plan   = Fonte{[Item="Planilha1",Kind="Sheet"]}[Data],
    Prom   = Table.PromoteHeaders(Plan, [PromoteAllScalars=true]),
    ColsNorm = Table.TransformColumnNames(Prom, each Text.Trim(Text.Replace(_, "  ", " "))),
    Ren    = Table.RenameColumns(
                ColsNorm,
                {
                    {"Responsavel", "RESPONSAVEL"},
                    {"UNIDADE", "UNIDADE"},
                    {"REGIAO", "REGIAO"}
                },
                MissingField.Ignore
             ),
    Padrao = Table.TransformColumns(
                Ren,
                {
                    {"UNIDADE", each if _=null then null else Text.Upper(Text.Trim(_)), type text},
                    {"RESPONSAVEL", each if _=null then null else Text.Trim(_), type text}
                }
             ),
    Types  = Table.TransformColumnTypes(
                Padrao,
                {
                    {"REGIAO", type text},
                    {"UNIDADE", type text},
                    {"RESPONSAVEL", type text}
                }
             )
in
    Types
