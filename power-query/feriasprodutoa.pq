// =====================================================
// Query 1: Fonte auxiliar de ausências dos responsáveis
// =====================================================
let
    Site   = "https://tenant.sharepoint.com/sites/projeto",
    Root   = SharePoint.Contents(Site, [ApiVersion=15]),
    Lib    = Root{[Name="Shared Documents"]}[Content],
    Auto   = Lib{[Name="Automacao Produto A"]}[Content],
    Pasta  = Auto{[Name="AUSENCIAS"]}[Content],
    Arq    = Table.SelectRows(Pasta, each [Name] = "AUSENCIAS.xlsx"){0},
    Bin    = Arq[Content],
    Fonte  = Excel.Workbook(Bin, null, true),
    Plan   = Fonte{[Item="Planilha1",Kind="Sheet"]}[Data],
    Cab    = Table.PromoteHeaders(Plan, [PromoteAllScalars=true]),
    Types  = Table.TransformColumnTypes(
                Cab,
                {
                    {"RESPONSAVEL", type text},
                    {"INICIO", type date},
                    {"FIM", type date}
                }
             )
in
    Types


// =====================================================
// Query 2: Fonte auxiliar de redistribuição por ausência
// =====================================================
let
    Site   = "https://tenant.sharepoint.com/sites/projeto",
    Root   = SharePoint.Contents(Site, [ApiVersion=15]),
    Lib    = Root{[Name="Shared Documents"]}[Content],
    Auto   = Lib{[Name="Automacao Produto A"]}[Content],
    Pasta  = Auto{[Name="AUSENCIAS"]}[Content],
    Arq    = Table.SelectRows(Pasta, each [Name] = "REDISTRIBUICAO_AUSENCIAS.xlsx"){0},
    Bin    = Arq[Content],
    Fonte  = Excel.Workbook(Bin, null, true),
    Plan   = Fonte{[Item="Planilha1",Kind="Sheet"]}[Data],
    Cab    = Table.PromoteHeaders(Plan, [PromoteAllScalars=true]),
    Types  = Table.TransformColumnTypes(
                Cab,
                {
                    {"RESPONSAVEL_ORIGINAL", type text},
                    {"RESPONSAVEL_SUBSTITUTO", type text},
                    {"PESO", Int64.Type}
                }
             ),
    CleanEmpty = Table.SelectRows(
                    Types,
                    each
                        ([RESPONSAVEL_ORIGINAL] <> null and Text.Trim([RESPONSAVEL_ORIGINAL]) <> "") or
                        ([RESPONSAVEL_SUBSTITUTO] <> null and Text.Trim([RESPONSAVEL_SUBSTITUTO]) <> "")
                 ),
    CleanPeso  = Table.SelectRows(CleanEmpty, each try [PESO] > 0 otherwise false)
in
    CleanPeso
