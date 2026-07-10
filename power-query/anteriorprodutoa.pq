let
    // ---- Funções utilitárias compartilhadas ----
    fxSPFileBin    = FUNCOES_COMPARTILHADAS[fxSPFileBin],
    fxReadMetaKV   = FUNCOES_COMPARTILHADAS[fxReadMetaKV_Bin],
    fxExtractName  = FUNCOES_COMPARTILHADAS[fxExtractDateFromFileName_Local],
    fxSafeToDate   = FUNCOES_COMPARTILHADAS[fxSafeToDate],
    fxTrimAll      = FUNCOES_COMPARTILHADAS[fxTrimAll],
    fxNormalize    = FUNCOES_COMPARTILHADAS[fxNormalize],
    fxCleanFilial  = FUNCOES_COMPARTILHADAS[fxCleanFilial],
    fxToDate       = FUNCOES_COMPARTILHADAS[fxToDate],

    // ---- TXT ANTERIOR ----
    Bin_Ant = fxSPFileBin("TXT_PRODUTO_A", "ARQUIVO_PRODUTO_A_ANTERIOR.TXT"),
    TXT_ant_src =
        if Bin_Ant <> null
        then Csv.Document(
               Bin_Ant,
               [Delimiter=";", Columns=58, Encoding=1252,
                CsvStyle=CsvStyle.QuoteAfterDelimiter, QuoteStyle=QuoteStyle.Csv,
                ExtraValues=ExtraValues.Ignore]
             )
        else #table({"Column1"},{}),
    TXT_ant_typ = Table.TransformColumnTypes(TXT_ant_src, List.Transform({1..58}, each {"Column" & Text.From(_), type text})),
    TXT_ant_hdr = Table.PromoteHeaders(TXT_ant_typ, [PromoteAllScalars=true]),

    // ---- Detectar coluna de data no TXT (fallback para âncora) ----
    DataAliasesAnt = {
        "DATA_TRANS","DATA TRANS","DATATRANS","DATA","DATA_PROPOSTA",
        "DATA DA PROPOSTA","DATA DA TRANS","DATA TRANSACAO","DATA DA TRANSACAO",
        "DT_TRANS","DT TRANS","DT_TRANSACAO","DT PROPOSTA","DT_PROPOSTA"
    },
    // Se você já tiver fxFindCol, pode usar. Aqui, segue um detect simples:
    FindCol = (cols as list, aliases as list) as nullable text =>
        let norm = (s as text) => Text.Upper(fxTrimAll(Text.Replace(Text.Replace(s,"_"," "),"-"," "))),
            colsN = List.Transform(cols, each [Orig=_, N=norm(Text.From(_))]),
            aliN  = List.Transform(aliases, each norm(_)),
            hit   = List.First(List.Select(colsN, each List.Contains(aliN, _[N])), null)
        in if hit=null then null else hit[Orig],
    DataColAnt = FindCol(Table.ColumnNames(TXT_ant_hdr), DataAliasesAnt),

    TXT_ant_withData =
        if DataColAnt <> null
        then Table.AddColumn(TXT_ant_hdr, "_DATA_", each fxToDate(Record.Field(_, DataColAnt)), type date)
        else TXT_ant_hdr,
    Fallback_MaxData =
        if DataColAnt <> null
        then let vals = List.RemoveNulls(TXT_ant_withData[_DATA_]) in if List.Count(vals)>0 then List.Max(vals) else null
        else null,

    // ---- META ANTERIOR (governança da janela pelo META) ----
    Bin_MetaAnt   = fxSPFileBin("TXT_PRODUTO_A", "ARQUIVO_PRODUTO_A_ANTERIOR_META.txt"),
    MetaAntRec    = fxReadMetaKV(Bin_MetaAnt),

    RefD1Txt      = try Text.From(Record.Field(MetaAntRec,"ReferenceD1SourceDate")) otherwise null,
    SrcTxt        = try Text.From(Record.Field(MetaAntRec,"SourceDate"))            otherwise null,
    NomeOriginalAnt = try Text.From(Record.Field(MetaAntRec,"NomeOriginal"))        otherwise null,

    RefD1         = try Date.FromText(RefD1Txt) otherwise null,
    SrcD          = fxSafeToDate(SrcTxt),
    D2FromName    = if NomeOriginalAnt<>null then fxExtractName(NomeOriginalAnt) else null,

    // Ordem de prioridade para âncora do D-1:
    // 1) ReferenceD1SourceDate (META)
    // 2) SourceDate + 1 (META)
    // 3) Max(DATA_TRANS) + 1 (TXT)
    // 4) Calendário D-1 (UTC-3), fallback final
    Snapshot_D1 =
        if SrcD <> null then SrcD
        else if D2FromName <> null then D2FromName
        else if Fallback_MaxData <> null then Fallback_MaxData
        else Date.AddDays(Date.From(DateTimeZone.RemoveZone(DateTimeZone.SwitchZone(DateTimeZone.UtcNow(), -3))), -2),

    // ---- Base mínima + data da proposta e unidade ----
    Ant_MustHave  = {"ID_PROPOSTA","USUARIO_ORIGEM","UNIDADE","FLAG_JANELA","FLAG_PRIORIDADE_A","FLAG_PRIORIDADE_B","FLAG_PRIORIDADE_C","FLAG_PRIORIDADE_D","VALOR_PREMIO","DESC_CATEGORIA","VALOR_RISCO","DATA_TRANS"},
    Ant_BaseCols  = List.Intersect({Table.ColumnNames(TXT_ant_hdr), Ant_MustHave}),
    Ant_sel       = if List.Count(Ant_BaseCols)>=1
                    then Table.SelectColumns(TXT_ant_hdr, List.Union({{"ID_PROPOSTA"}, Ant_BaseCols}))
                    else Table.SelectColumns(TXT_ant_hdr, {"ID_PROPOSTA"}),

    Ant_dt        = if List.Contains(Table.ColumnNames(Ant_sel),"DATA_TRANS")
                    then Table.AddColumn(Ant_sel,"DATA_PROPOSTA", each fxToDate([DATA_TRANS]), type date)
                    else Table.AddColumn(Ant_sel,"DATA_PROPOSTA", each null, type date),

    Ant_fil       = Table.TransformColumns(Ant_dt, {{"UNIDADE", each if _=null then null else fxCleanFilial(_), type text}}),

    // ---- Atribuição manual + mapa de unidade para responsável ----
    MergeAtrib    = Table.NestedJoin(Ant_fil, {"ID_PROPOSTA"}, ATRIBUIR_PROPOSTA_UNICA, {"ID_PROPOSTA"}, "ATRIB", JoinKind.LeftOuter),
    ExpAtrib      = Table.ExpandTableColumn(MergeAtrib, "ATRIB", {"RESPONSAVEL_AJUSTADO"}),

    MAP_cols      = Table.TransformColumnNames(UNIDADE_RESPONSAVEL, each Text.Trim(Text.Replace(_, "  ", " ")) ),
    MAP_clean     = Table.TransformColumns(MAP_cols, {{"UNIDADE", each if _=null then null else fxCleanFilial(_), type text},{"RESPONSAVEL", each fxTrimAll(_), type text}}),
    MAP_idx       = Table.AddIndexColumn(MAP_clean, "_IDX", 1, 1, Int64.Type),
    MAP_sort      = Table.Sort(MAP_idx, {{"_IDX", Order.Ascending}}),
    MAP_unica     = Table.Group(MAP_sort, {"UNIDADE"}, {{"RESPONSAVEL", each List.Last([RESPONSAVEL]), type text}}),

    Ant_mergeMap  = Table.NestedJoin(ExpAtrib, {"UNIDADE"}, MAP_unica, {"UNIDADE"}, "MAP", JoinKind.LeftOuter),
    Ant_expMap    = Table.ExpandTableColumn(Ant_mergeMap, "MAP", {"RESPONSAVEL"}, {"RESPONSAVEL_MAP"}),

    Ant_destino   = Table.AddColumn(
                        Ant_expMap, "RESPONSAVEL_DESTINO",
                        each let adj = fxTrimAll(try [RESPONSAVEL_AJUSTADO] otherwise ""),
                                 map = fxTrimAll(try [RESPONSAVEL_MAP]      otherwise ""),
                                 base= fxTrimAll(try [USUARIO_ORIGEM]       otherwise "")
                             in if adj<>"" then adj else if map<>"" then map else base, type text),

    // ---- Elegibilidade fixa no Snapshot_D1, com getters seguros ----
    Ant_eleg =
        Table.AddColumn(
          Table.AddColumn(Ant_destino, "DATASET_DATE", each Snapshot_D1, type date),
          "ELEGIVEL",
          (r) =>
            let
              refDate  = r[DATASET_DATE],
              winStart = if refDate = null then null else Date.AddDays(refDate, -14),
              winEnd   = if refDate = null then null else Date.AddDays(refDate, -12),

              get  = (rec as record, c as text) => try Record.Field(rec, c) otherwise null,
              norm = (x   as any   ) as text  => let t = try Text.From(x) otherwise "", u = Text.Upper(fxTrimAll(t)) in u,

              isPriorA = norm(get(r,"FLAG_PRIORIDADE_A")) = "S",
              isPriorB = norm(get(r,"FLAG_PRIORIDADE_B")) = "S",
              isPriorC = norm(get(r,"FLAG_PRIORIDADE_C")) = "S",
              isPriorD = norm(get(r,"FLAG_PRIORIDADE_D")) = "S",
              isJanela = norm(get(r,"FLAG_JANELA"      )) = "S",

              isPrior = isPriorA or isPriorB or isPriorC or isPriorD,

              dt = try Date.From(get(r,"DATA_PROPOSTA")) otherwise null,

              inJan    = isJanela and (dt <> null) and (winStart <> null and winEnd <> null) and (dt >= winStart) and (dt <= winEnd),
              semDat   = isJanela and (dt = null),
              isDMinus11 = isJanela and (not isPrior) and (dt <> null) and (winEnd <> null) and (dt = Date.AddDays(winEnd, 1))
            in
              if isPrior or inJan or semDat or isDMinus11 then "Manter" else "Excluir",
          type text
        ),

    // ---- Filtra somente elegíveis, mantendo governança da janela ----
    Ant_keep = Table.SelectRows(Ant_eleg, each try [ELEGIVEL] = "Manter" otherwise false),

    // ---- Snapshot final D-1, uma linha por proposta ----
    Ant_snapshot_base = Table.SelectColumns(Ant_keep, {"ID_PROPOSTA","RESPONSAVEL_DESTINO","DATASET_DATE"}),
    Ant_snapshot  = Table.Group(Ant_snapshot_base, {"ID_PROPOSTA"},
                        {{"RESPONSAVEL_ANTERIOR", each List.First([RESPONSAVEL_DESTINO]), type text},
                         {"LB_DATE",              each List.First([DATASET_DATE]),      type date}})
in
    Ant_snapshot
