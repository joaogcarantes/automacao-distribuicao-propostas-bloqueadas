// =====================================================
// Query 1: Fonte auxiliar de ausências dos responsáveis - Produto B
// =====================================================
let
    Site = "https://tenant.sharepoint.com/sites/projeto",
    fxTrimAll = FUNCOES_COMPARTILHADAS[fxTrimAll],

    // Parser forçado em dd/MM/yyyy
    fxParseDateDMY = (v as any) as nullable date =>
        let
            raw = try Text.Trim(Text.From(v)) otherwise null,
            txt = if raw = "" then null else raw,

            // Se já vier no formato dd/MM/yyyy ou d/M/yyyy
            bySlash =
                if txt <> null and Text.Contains(txt, "/") then
                    let
                        parts = List.Transform(Text.Split(txt, "/"), each try Number.FromText(_) otherwise null)
                    in
                        if List.Count(parts) = 3
                           and parts{0} <> null
                           and parts{1} <> null
                           and parts{2} <> null
                        then
                            try #date(parts{2}, parts{1}, parts{0}) otherwise null
                        else
                            null
                else
                    null,

            // Se já vier como date/datetime real
            direct =
                if bySlash <> null
                then bySlash
                else try Date.From(v) otherwise null
        in
            direct,

    Root = SharePoint.Contents(Site, [ApiVersion=15]),
    Lib = Root{[Name="Shared Documents"]}[Content],
    Dist = Lib{[Name="Distribuicao Produto B"]}[Content],
    Pasta = Dist{[Name="AUSENCIAS"]}[Content],
    Arq = Table.SelectRows(Pasta, each [Name] = "AUSENCIAS.xlsx"){0},
    Bin = Arq[Content],
    Xls = Excel.Workbook(Bin, null, true),
    Plan = Xls{[Item="Planilha1",Kind="Sheet"]}[Data],
    Cab = Table.PromoteHeaders(Plan, [PromoteAllScalars=true]),

    Sel =
        Table.SelectColumns(
            Cab,
            {"RESPONSAVEL","INICIO","FIM"},
            MissingField.Ignore
        ),

    CleanText =
        Table.TransformColumns(
            Sel,
            {
                {"RESPONSAVEL", each try fxTrimAll(Text.From(_)) otherwise null, type text}
            }
        ),

    ConvDates =
        Table.TransformColumns(
            CleanText,
            {
                {"INICIO", each fxParseDateDMY(_), type date},
                {"FIM", each fxParseDateDMY(_), type date}
            }
        ),

    CleanRows =
        Table.SelectRows(
            ConvDates,
            each [RESPONSAVEL] <> null and [RESPONSAVEL] <> ""
              and [INICIO] <> null
              and [FIM] <> null
        )
in
    CleanRows


// =====================================================
// Query 2: Fonte auxiliar de redistribuição por ausência - Produto B
// =====================================================
let
  Site   = "https://tenant.sharepoint.com/sites/projeto",
  Root   = SharePoint.Contents(Site, [ApiVersion=15]),
  Lib    = Root{[Name="Shared Documents"]}[Content],
  Dist   = Lib{[Name="Distribuicao Produto B"]}[Content],
  Pasta  = Dist{[Name="AUSENCIAS"]}[Content],
  Arq    = Table.SelectRows(Pasta, each [Name] = "REDISTRIBUICAO_AUSENCIAS.xlsx"){0},
  Bin    = Arq[Content],
  Xls    = Excel.Workbook(Bin, null, true),
  Plan   = Xls{[Item="Planilha1",Kind="Sheet"]}[Data],
  Cab    = Table.PromoteHeaders(Plan, [PromoteAllScalars=true]),
  Typ    = Table.TransformColumnTypes(
             Cab,
             {
               {"RESPONSAVEL_ORIGINAL", type text},
               {"RESPONSAVEL_SUBSTITUTO", type text},
               {"PESO", Int64.Type}
             }
           )
in
    Typ
