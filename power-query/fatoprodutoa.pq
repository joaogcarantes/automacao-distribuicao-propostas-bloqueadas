// ============================
// DISTRIBUIR PRODUTO_A (FATO) — versão SPO (CORRIGIDA: COD_PARCEIRO + SEGMENTAÇÃO + NOME_PARCEIRO)
// ============================
let
    // ==== Funções utilitárias (da sua FUNCOES_COMPARTILHADAS) ====
    fxSPFileBin = FUNCOES_COMPARTILHADAS[fxSPFileBin],
    fxReadMetaKV = FUNCOES_COMPARTILHADAS[fxReadMetaKV_Bin],
    fxExtractName = FUNCOES_COMPARTILHADAS[fxExtractDateFromFileName_Local],
    fxSafeToDate = FUNCOES_COMPARTILHADAS[fxSafeToDate],
    fxTrimAll = FUNCOES_COMPARTILHADAS[fxTrimAll],
    fxNormalize = FUNCOES_COMPARTILHADAS[fxNormalize],
    fxBlankLike = FUNCOES_COMPARTILHADAS[fxBlankLike],
    fxCleanFilial = FUNCOES_COMPARTILHADAS[fxCleanFilial],
    fxPickWeighted = FUNCOES_COMPARTILHADAS[fxPickWeighted],
    fxToDate = FUNCOES_COMPARTILHADAS[fxToDate],
    fxFindCol = FUNCOES_COMPARTILHADAS[fxFindCol],
    fxAsBusinessDay = FUNCOES_COMPARTILHADAS[fxAsBusinessDay], // (importada, não utilizada na âncora)

    // ==== Helper local: normaliza COD_PARCEIRO (só dígitos + remove zeros à esquerda) ====
    fxCodKey = (x as nullable any) as nullable text =>
        let
            t0 = try Text.From(x) otherwise null,
            t1 = if t0 = null then null else Text.Trim(t0),
            // mata casos tipo "12345.0"
            t2 = if t1 = null then null else if Text.End(t1, 2) = ".0" then Text.Start(t1, Text.Length(t1)-2) else t1,
            digits = if t2 = null then null else Text.Select(t2, {"0".."9"}),
            noLeftZeros = if digits = null then null else Text.TrimStart(digits, {"0"}),
            out = if noLeftZeros = "" then null else noLeftZeros
        in
            out,

    // ==== ATUAL: TXT + META lidos da pasta "TXT_PRODUTO_A" no SharePoint ====
    Bin_ATUAL = fxSPFileBin("TXT_PRODUTO_A","ARQUIVO_PRODUTO_A_ATUAL.TXT"),
    TXT_src =
        if Bin_ATUAL <> null
        then Csv.Document(
            Bin_ATUAL,
            [
                Delimiter = ";",
                Columns = 58,
                Encoding = 1252,
                CsvStyle = CsvStyle.QuoteAfterDelimiter,
                QuoteStyle = QuoteStyle.Csv,
                ExtraValues = ExtraValues.Ignore
            ]
        )
        else #table({"Column1"}, {}),

    TXT_typ = Table.TransformColumnTypes(
        TXT_src,
        List.Transform({1..58}, each {"Column" & Text.From(_), type text})
    ),
    TXT_hdr = Table.PromoteHeaders(TXT_typ, [PromoteAllScalars = true]),

    Bin_META_ATUAL = fxSPFileBin("TXT_PRODUTO_A","ARQUIVO_PRODUTO_A_ATUAL_META.txt"),
    MetaRec = fxReadMetaKV(Bin_META_ATUAL),
    NomeOriginal = try Text.From(Record.Field(MetaRec, "NomeOriginal")) otherwise null,
    SourceDateTxt = try Text.From(Record.Field(MetaRec, "SourceDate")) otherwise null,
    SourceDate = fxSafeToDate(SourceDateTxt),
    DataTXT_D1_FromName = if NomeOriginal <> null then fxExtractName(NomeOriginal) else null,

    // ===== DATASET_DATE (origens da data do TXT para auditoria)
    DataAliases = {
        "DATA_TRANS","DATA TRANS","DATATRANS","DATA","DATA_PROPOSTA",
        "DATA DA PROPOSTA","DATA DA TRANS","DATA TRANSACAO","DATA DA TRANSACAO",
        "DT_TRANS","DT TRANS","DT_TRANSACAO","DT PROPOSTA","DT_PROPOSTA"
    },
    DataColName = fxFindCol(Table.ColumnNames(TXT_hdr), DataAliases),
    TXT_withData =
        if DataColName <> null
        then Table.AddColumn(TXT_hdr, "_DATA_", each fxToDate(Record.Field(_, DataColName)), type date)
        else TXT_hdr,

    Fallback_D1 =
        if DataColName <> null
        then
            let vals = List.RemoveNulls(TXT_withData[_DATA_])
            in if List.Count(vals) > 0 then List.Max(vals) else null
        else null,

    // Mantém cálculo da "data do arquivo" apenas para telemetria (NÃO vai ancorar a janela)
    DataTXT_D1 =
        if DataTXT_D1_FromName <> null then DataTXT_D1_FromName
        else if SourceDate <> null then SourceDate
        else Fallback_D1,

    // ====== ÂNCORA CORRIGIDA DO D (SEM blindagem: segunda cai para domingo D-1) ======
    // D-1 do calendário no fuso RJ
    NowRJ = DateTimeZone.SwitchZone(DateTimeZone.UtcNow(), -3),
    D1Calendar = Date.AddDays(Date.From(DateTimeZone.RemoveZone(NowRJ)), -1),
    // Usar D-1 "cru": se hoje é segunda, D-1 é domingo → mantém domingo.
    DATASET_DATE = D1Calendar,
    DBG_SOURCE = "CALENDAR.D-1",

    // ===== Base ATUAL: tipos, data proposta, filial, atividade
    TXT_dbg = Table.AddColumn(TXT_hdr, "DBG_DATA_COL", each DataColName, type text),

    // >>>>> AJUSTE: incluir NOME_PARCEIRO e COD_PARCEIRO no fluxo (se existirem no TXT)
    MustHave = {
        "ID_PROPOSTA","USUARIO_ORIGEM","UNIDADE","NOME_PARCEIRO","COD_PARCEIRO","CEP","ENDERECO","NUMERO","COMPLEMENTO",
        "ID_CLIENTE","VALOR_PREMIO","714","1701","2279","8030","8027","VL_VALOR_PREMIO","DESC_CATEGORIA","VL_RISCO"
    },
    BaseCols = List.Intersect({Table.ColumnNames(TXT_dbg), MustHave}),

    SelCols =
        if List.Contains(Table.ColumnNames(TXT_dbg), "DATA_TRANS")
        then List.Combine({BaseCols, {"DATA_TRANS","DBG_DATA_COL"}})
        else List.Combine({BaseCols, {"DBG_DATA_COL"}}),

    TXT_sel =
        if List.Count(BaseCols) >= 6
        then Table.SelectColumns(TXT_dbg, SelCols)
        else error "TXT ATUAL: colunas essenciais ausentes. Verifique cabeçalhos.",

    // Tipagem blindada (só transforma o que existir no TXT)
    TXT_cast =
        let
            cols = Table.ColumnNames(TXT_sel),
            typePairs = List.RemoveNulls({
                if List.Contains(cols, "ID_PROPOSTA") then {"ID_PROPOSTA", type text} else null,
                if List.Contains(cols, "UNIDADE") then {"UNIDADE", type text} else null,
                if List.Contains(cols, "USUARIO_ORIGEM") then {"USUARIO_ORIGEM", type text} else null,
                if List.Contains(cols, "NOME_PARCEIRO") then {"NOME_PARCEIRO", type text} else null,
                if List.Contains(cols, "COD_PARCEIRO") then {"COD_PARCEIRO", type text} else null
            })
        in
            Table.TransformColumnTypes(TXT_sel, typePairs),

    TXT_dt =
        if List.Contains(Table.ColumnNames(TXT_cast), "DATA_TRANS")
        then Table.AddColumn(TXT_cast, "DATA_PROPOSTA", each fxToDate([DATA_TRANS]), type date)
        else Table.AddColumn(TXT_cast, "DATA_PROPOSTA", each null, type date),

    TXT_dttxt = Table.AddColumn(
        TXT_dt, "DATA_PROPOSTA_TXT",
        each if [DATA_PROPOSTA] = null then null else Date.ToText([DATA_PROPOSTA], "dd/MM/yyyy","pt-BR"),
        type text
    ),

    TXT_fil = Table.TransformColumns(TXT_dttxt, {{"UNIDADE", each if _ = null then null else fxCleanFilial(_), type text}}),

    // ATIVIDADE (fallback de DESC_CATEGORIA)
    AtvSrc =
        if List.Contains(Table.ColumnNames(TXT_fil), "ATIVIDADE") then "ATIVIDADE"
        else if List.Contains(Table.ColumnNames(TXT_fil), "DESC_CATEGORIA") then "DESC_CATEGORIA"
        else null,

    TXT_withAtv =
        if AtvSrc <> null and AtvSrc <> "ATIVIDADE" then
            Table.AddColumn(TXT_fil, "ATIVIDADE", each try Record.Field(_, AtvSrc) otherwise null, type text)
        else if AtvSrc = null then
            Table.AddColumn(TXT_fil, "ATIVIDADE", each null, type text)
        else TXT_fil,

    // Index/ocorrência por ID_PROPOSTA
    TXT_RowId = Table.AddIndexColumn(TXT_withAtv, "ROW_ID", 1, 1, Int64.Type),
    TXT_GroupedForOcc =
        Table.Group(
            TXT_RowId,
            {"ID_PROPOSTA"},
            {{"T", (tbl) => Table.AddIndexColumn(tbl, "OCORR_ID_PROPOSTA", 1, 1, Int64.Type), type table}}
        ),

    _innerCols = Table.ColumnNames(TXT_RowId),
    _expandColsBase = List.RemoveItems(_innerCols, {"ID_PROPOSTA"}),
    _expandCols = List.Combine({_expandColsBase, {"OCORR_ID_PROPOSTA"}}),
    TXT_readyForMerge = Table.ExpandTableColumn(TXT_GroupedForOcc, "T", _expandCols, _expandCols),

    // === ATRIBUIR PROPOSTA (consulta auxiliar SPO)
    MergeAtrib = Table.NestedJoin(TXT_readyForMerge, {"ID_PROPOSTA"}, ATRIBUIR_PROPOSTA_UNICA, {"ID_PROPOSTA"}, "ATRIBUIR_PROPOSTA", JoinKind.LeftOuter),
    ExpAtrib = Table.ExpandTableColumn(MergeAtrib, "ATRIBUIR_PROPOSTA", {"RESPONSAVEL_AJUSTADO"}),

    // === UNIDADE -> RESPONSAVEL (consulta auxiliar SPO: UNIDADERESPONSAVEL)
    MAP_cols = Table.TransformColumnNames(UNIDADERESPONSAVEL, each Text.Trim(Text.Replace(_, " ", " "))),
    MAP_clean = Table.TransformColumns(MAP_cols, {{"UNIDADE", each if _ = null then null else fxCleanFilial(_), type text},{"RESPONSAVEL", each fxTrimAll(_), type text}}),
    MAP_idx = Table.AddIndexColumn(MAP_clean, "_IDX", 1, 1, Int64.Type),
    MAP_sort = Table.Sort(MAP_idx, {{"_IDX", Order.Ascending}}),
    MAP_unica = Table.Group(MAP_sort, {"UNIDADE"}, {{"RESPONSAVEL", each List.Last([RESPONSAVEL]), type text}}),

    MergeMap = Table.NestedJoin(ExpAtrib, {"UNIDADE"}, MAP_unica, {"UNIDADE"}, "MAP", JoinKind.LeftOuter),
    ExpMap = Table.ExpandTableColumn(MergeMap, "MAP", {"RESPONSAVEL"}, {"RESPONSAVEL_MAP"}),

    // === Subscritor destino base
    AddDestino =
        Table.AddColumn(
            ExpMap, "RESPONSAVEL_DESTINO",
            each
                let
                    adj  = fxTrimAll(try [RESPONSAVEL_AJUSTADO] otherwise ""),
                    map  = fxTrimAll(try [RESPONSAVEL_MAP] otherwise ""),
                    base = fxTrimAll(try [USUARIO_ORIGEM] otherwise "")
                in
                    if adj <> "" then adj else if map <> "" then map else base,
            type text
        ),

    // === DATASET_DATE (D) no ATUAL
    AddDatasetDate = Table.AddColumn(AddDestino, "DATASET_DATE", each DATASET_DATE, type date),

    // === ELEGIBILIDADE (fixa no DATASET_DATE)
    AddElegivel =
        Table.AddColumn(
            AddDatasetDate, "ELEGIVEL",
            (r) =>
                let
                    refDate  = r[DATASET_DATE],
                    winStart = Date.AddDays(refDate, -14),
                    winEnd   = Date.AddDays(refDate, -12),
                    norm = (x as any) as text =>
                        let t = try Text.From(x) otherwise "", u = Text.Upper(fxTrimAll(t)) in u,

                    is1701 = norm(r[#"1701"]) = "S",
                    is2279 = norm(r[#"2279"]) = "S",
                    is8027 = norm(r[#"8027"]) = "S",
                    is8030 = norm(r[#"8030"]) = "S",
                    is714  = norm(r[#"714" ]) = "S",

                    isPrior = is1701 or is2279 or is8027 or is8030,
                    dt = try Date.From(r[DATA_PROPOSTA]) otherwise null,

                    inJanela = is714 and (dt <> null) and (dt >= winStart) and (dt <= winEnd),
                    semData  = is714 and (dt = null),

                    // >>> Tolerância para D-11 (um dia após winEnd) quando só 714
                    isDMinus11 = is714 and (not isPrior) and (dt <> null) and (dt = Date.AddDays(winEnd, 1)),

                    eleg = try if isPrior or inJanela or semData or isDMinus11 then "Manter" else "Excluir" otherwise "Excluir"
                in
                    eleg,
            type text
        ),

    // --- Ausências + Redistribuição (consultas auxiliares SPO: FERIAS, REDISTRIBUICAO_FERIAS) ---
    FER_typ = Table.TransformColumnTypes(FERIAS, {{"RESPONSAVEL", type text}, {"INICIO", type date}, {"FIM", type date}}),
    FER_ATIVAS = Table.SelectRows(FER_typ, each [INICIO] <= DATASET_DATE and [FIM] >= DATASET_DATE),
    FER_ATIVAS_N = Table.TransformColumns(FER_ATIVAS, {{"RESPONSAVEL", each fxNormalize(_, true), type text}}),
    SUBS_FERIAS = FER_ATIVAS_N[RESPONSAVEL],

    AddNorms = Table.TransformColumns(AddElegivel, {{"RESPONSAVEL_DESTINO", each fxTrimAll(_), type text}}),
    AddFlagsFerias = Table.AddColumn(AddNorms, "DESTINO_EM_FERIAS", each List.Contains(SUBS_FERIAS, fxNormalize([RESPONSAVEL_DESTINO], true)), type logical),
    AddBaseRedis = Table.AddColumn(AddFlagsFerias, "RESPONSAVEL_BASE_REDIS", each if (try [DESTINO_EM_FERIAS] otherwise false) then [RESPONSAVEL_DESTINO] else null, type text),

    AddREDIS =
        Table.AddColumn(
            AddBaseRedis, "RESPONSAVEL_REDIS",
            each
                let bRaw = try [RESPONSAVEL_BASE_REDIS] otherwise "", b = fxTrimAll(bRaw)
                in if b <> "" then fxPickWeighted(b, [ID_PROPOSTA], REDISTRIBUICAO_FERIAS) else null,
            type text
        ),

    AddFinal =
        Table.AddColumn(
            AddREDIS, "RESPONSAVEL_FINAL",
            each
                let red = fxTrimAll(try [RESPONSAVEL_REDIS] otherwise ""), dest = fxTrimAll(try [RESPONSAVEL_DESTINO] otherwise "")
                in if red <> "" then red else dest,
            type text
        ),

    // === Chaves de join + filtra ELEGÍVEL (Manter)
    AddKeysForJoin = Table.TransformColumns(
        AddFinal,
        {
            {"ID_PROPOSTA", each if _ = null then null else fxTrimAll(Text.From(_)), type text},
            {"RESPONSAVEL_FINAL", each if _ = null then null else fxTrimAll(Text.From(_)), type text}
        }
    ),
    SomenteManter = Table.SelectRows(AddKeysForJoin, each [ELEGIVEL] = "Manter"),

    // ======== ANTERIOR: TXT + META (Snapshot D-1) lidos do SharePoint ========
    Bin_ANT = fxSPFileBin("TXT_PRODUTO_A","ARQUIVO_PRODUTO_A_ANTERIOR.TXT"),
    TXT_ant_src =
        if Bin_ANT <> null
        then Csv.Document(
            Bin_ANT,
            [
                Delimiter = ";",
                Columns = 58,
                Encoding = 1252,
                CsvStyle = CsvStyle.QuoteAfterDelimiter,
                QuoteStyle = QuoteStyle.Csv,
                ExtraValues = ExtraValues.Ignore
            ]
        )
        else #table({"Column1"}, {}),

    TXT_ant_typ = Table.TransformColumnTypes(
        TXT_ant_src,
        List.Transform({1..58}, each {"Column" & Text.From(_), type text})
    ),
    TXT_ant_hdr = Table.PromoteHeaders(TXT_ant_typ, [PromoteAllScalars = true]),

    Bin_META_ANT = fxSPFileBin("TXT_PRODUTO_A","ARQUIVO_PRODUTO_A_ANTERIOR_META.txt"),
    MetaAntRec = fxReadMetaKV(Bin_META_ANT),
    NomeOriginalAnt = try Text.From(Record.Field(MetaAntRec, "NomeOriginal")) otherwise null,
    SourceDateAntTxt = try Text.From(Record.Field(MetaAntRec, "SourceDate")) otherwise null,
    SourceDateAnt = fxSafeToDate(SourceDateAntTxt),
    DataTXT_D2_FromName = if NomeOriginalAnt <> null then fxExtractName(NomeOriginalAnt) else null,
    FileDate_D2 = if DataTXT_D2_FromName <> null then DataTXT_D2_FromName else SourceDateAnt,
    Snapshot_D1 = if FileDate_D2 = null then null else Date.AddDays(FileDate_D2, 1),

    // Colunas mínimas + DATA_PROPOSTA no ANTERIOR
    Ant_MustHave = {"ID_PROPOSTA","USUARIO_ORIGEM","UNIDADE","714","1701","2279","8027","8030","VL_VALOR_PREMIO","DESC_CATEGORIA","VL_RISCO","DATA_TRANS"},
    Ant_BaseCols = List.Intersect({Table.ColumnNames(TXT_ant_hdr), Ant_MustHave}),
    Ant_sel =
        if List.Count(Ant_BaseCols) >= 1
        then Table.SelectColumns(TXT_ant_hdr, List.Union({{"ID_PROPOSTA"}, Ant_BaseCols}))
        else Table.SelectColumns(TXT_ant_hdr, {"ID_PROPOSTA"}),

    Ant_dt =
        if List.Contains(Table.ColumnNames(Ant_sel), "DATA_TRANS")
        then Table.AddColumn(Ant_sel, "DATA_PROPOSTA", each fxToDate([DATA_TRANS]), type date)
        else Table.AddColumn(Ant_sel, "DATA_PROPOSTA", each null, type date),

    Ant_fil = Table.TransformColumns(Ant_dt, {{"UNIDADE", each if _ = null then null else fxCleanFilial(_), type text}}),

    // ATRIB + MAP no ANTERIOR (usando consultas auxiliares SPO)
    Ant_mergeAtrib = Table.NestedJoin(Ant_fil, {"ID_PROPOSTA"}, ATRIBUIR_PROPOSTA_UNICA, {"ID_PROPOSTA"}, "ATRIB", JoinKind.LeftOuter),
    Ant_expAtrib = Table.ExpandTableColumn(Ant_mergeAtrib, "ATRIB", {"RESPONSAVEL_AJUSTADO"}),

    Ant_mergeMap = Table.NestedJoin(Ant_expAtrib, {"UNIDADE"}, MAP_unica, {"UNIDADE"}, "MAP", JoinKind.LeftOuter),
    Ant_expMap = Table.ExpandTableColumn(Ant_mergeMap, "MAP", {"RESPONSAVEL"}, {"RESPONSAVEL_MAP"}),

    Ant_destino =
        Table.AddColumn(
            Ant_expMap, "RESPONSAVEL_DESTINO",
            each
                let
                    adj  = fxTrimAll(try [RESPONSAVEL_AJUSTADO] otherwise ""),
                    map  = fxTrimAll(try [RESPONSAVEL_MAP] otherwise ""),
                    base = fxTrimAll(try [USUARIO_ORIGEM] otherwise "")
                in
                    if adj <> "" then adj else if map <> "" then map else base,
            type text
        ),

    // Elegibilidade no ANTERIOR (fixa no Snapshot_D1)
    Ant_eleg =
        Table.AddColumn(
            Table.AddColumn(Ant_destino, "DATASET_DATE", each Snapshot_D1, type date),
            "ELEGIVEL",
            (r) =>
                let
                    refDate  = r[DATASET_DATE],
                    winStart = Date.AddDays(refDate, -14),
                    winEnd   = Date.AddDays(refDate, -12),
                    norm = (x as any) as text =>
                        let t = try Text.From(x) otherwise "", u = Text.Upper(fxTrimAll(t)) in u,

                    is1701 = norm(r[#"1701"]) = "S",
                    is2279 = norm(r[#"2279"]) = "S",
                    is8027 = norm(r[#"8027"]) = "S",
                    is8030 = norm(r[#"8030"]) = "S",
                    is714  = norm(r[#"714" ]) = "S",

                    isPrior = is1701 or is2279 or is8027 or is8030,
                    dt = try Date.From(r[DATA_PROPOSTA]) otherwise null,

                    inJanela = is714 and (dt <> null) and (dt >= winStart) and (dt <= winEnd),
                    semData  = is714 and (dt = null)
                in
                    if isPrior or inJanela or semData then "Manter" else "Excluir",
            type text
        ),

    Ant_keep = Table.SelectRows(Ant_eleg, each [ELEGIVEL] = "Manter"),

    // Snapshot D-1 (uma linha por ID_PROPOSTA)
    Ant_snapshot_base = Table.SelectColumns(Ant_keep, {"ID_PROPOSTA","RESPONSAVEL_DESTINO","DATASET_DATE"}),
    Ant_snapshot =
        Table.Group(
            Ant_snapshot_base, {"ID_PROPOSTA"},
            {
                {"RESPONSAVEL_ANTERIOR", each List.First([RESPONSAVEL_DESTINO]), type text},
                {"LB_DATE", each List.First([DATASET_DATE]), type date}
            }
        ),

    // Merge ATUAL (SomenteManter) x snapshot D-1
    MergeAntD1 = Table.NestedJoin(SomenteManter, {"ID_PROPOSTA"}, Ant_snapshot, {"ID_PROPOSTA"}, "ANT_D1", JoinKind.LeftOuter),
    ExpAntD1 = Table.ExpandTableColumn(MergeAntD1, "ANT_D1", {"RESPONSAVEL_ANTERIOR","LB_DATE"}, {"RESPONSAVEL_ANTERIOR","LB_DATE"}),

    // Categorização (RETORNO / NOVO / REDISTRIBUÍDO)
    ExpAnt_SubText = Table.TransformColumns(ExpAntD1, {{"RESPONSAVEL_ANTERIOR", each if _ = null then null else Text.From(_), type text}}),
    AddRetorno =
        Table.AddColumn(
            ExpAnt_SubText, "RETORNO",
            each
                let
                    ant = fxTrimAll(try [RESPONSAVEL_ANTERIOR] otherwise ""),
                    fin = fxTrimAll(try [RESPONSAVEL_FINAL] otherwise "")
                in
                    if fxBlankLike(ant) then "NOVO"
                    else if Text.Upper(ant) = Text.Upper(fin) then "RETORNO (MESMO SUB)"
                    else "RETORNO (OUTRO SUB)",
            type text
        ),

    AddVisual = Table.AddColumn(AddRetorno, "RESPONSAVEL_VISUAL", each [RESPONSAVEL_FINAL], type text),

    AddStatus =
        Table.AddColumn(
            AddVisual, "STATUS_ALOCACAO",
            each
                let
                    final = fxTrimAll(try [RESPONSAVEL_FINAL] otherwise ""),
                    red   = fxTrimAll(try [RESPONSAVEL_REDIS] otherwise ""),
                    ant   = fxTrimAll(try [RESPONSAVEL_ANTERIOR] otherwise ""),
                    isNovo= (try [RETORNO] otherwise "") = "NOVO"
                in
                    if final = red and red <> "" then "REDISTRIBUÍDO (FÉRIAS)"
                    else if ant <> "" and final = ant then "RETORNO (MANTIDO)"
                    else if isNovo then "NOVO"
                    else "DESTINO (SEM FÉRIAS/SEM MUDANÇA)",
            type text
        ),

    // Flags (ausências anterior/destino)
    AddFlagsOut =
        Table.AddColumn(
            Table.AddColumn(AddStatus, "FERIAS_ANTERIOR", each List.Contains(SUBS_FERIAS, fxNormalize(try [RESPONSAVEL_ANTERIOR] otherwise "", true)), type logical),
            "FERIAS_DESTINO", each List.Contains(SUBS_FERIAS, fxNormalize(try [RESPONSAVEL_DESTINO] otherwise "", true)), type logical
        ),

    // Coerção de tipos
    DateColsWanted = {"DATA_PROPOSTA","DATASET_DATE","LB_DATE"},
    ExistingDateCols = List.Intersect({Table.ColumnNames(AddFlagsOut), DateColsWanted}),
    CoerceDates = Table.TransformColumns(
        AddFlagsOut,
        List.Transform(
            ExistingDateCols,
            each {_, each try Date.From(_) otherwise try Date.FromText(_, "pt-BR") otherwise null, type date}
        )
    ),

    NumberColsWanted = {"VALOR_PREMIO","VL_VALOR_PREMIO","VL_RISCO"},
    ExistingNumberCols = List.Intersect({Table.ColumnNames(CoerceDates), NumberColsWanted}),
    CoerceNumbers = Table.TransformColumns(
        CoerceDates,
        List.Transform(
            ExistingNumberCols,
            each {_, each try Number.FromText(Text.From(_), "pt-BR") otherwise null, type number}
        )
    ),

    ExistingLogicalCols = List.Intersect({Table.ColumnNames(CoerceNumbers), {"DESTINO_EM_FERIAS","FERIAS_ANTERIOR","FERIAS_DESTINO"}}),
    CoerceLogicals = Table.TransformColumns(
        CoerceNumbers,
        List.Transform(
            ExistingLogicalCols,
            each {_, each try Logical.From(_) otherwise null, type logical}
        )
    ),

    // >>>>> AJUSTE: incluir SEGMENTACAO_PARCEIROA e NOME_PARCEIRO como texto (para não cair fora na coerção)
    TextColsWanted = {
        "DATA_PROPOSTA_TXT","DATA_TRANS","714","1701","2279","8027","8030",
        "ID_PROPOSTA","UNIDADE","NOME_PARCEIRO","COD_PARCEIRO","SEGMENTACAO_PARCEIROA","DESC_CATEGORIA","ATIVIDADE",
        "RESPONSAVEL_AJUSTADO","RESPONSAVEL_MAP","RESPONSAVEL_DESTINO","RESPONSAVEL_ANTERIOR",
        "RESPONSAVEL_REDIS","RESPONSAVEL_FINAL",
        "ELEGIVEL","CEP","ENDERECO","NUMERO","COMPLEMENTO",
        "ID_CLIENTE","VALOR_PREMIO","VL_VALOR_PREMIO","VL_RISCO","DATASET_DATE","STATUS_ALOCACAO","RETORNO"
    },

    ExistingTextCols = List.Difference(
        List.Intersect({Table.ColumnNames(CoerceLogicals), TextColsWanted}),
        List.Combine({ExistingDateCols, ExistingNumberCols, ExistingLogicalCols})
    ),

    SafeScalars = Table.TransformColumns(
        CoerceLogicals,
        List.Transform(ExistingTextCols, each {_, each try Text.From(_) otherwise null, type text})
    ),

    WithDbgSource = Table.AddColumn(SafeScalars, "DBG_DATE_SOURCE", each DBG_SOURCE, type text),

    // ======================================================
    // (NOVO) ENRIQUECIMENTO: CARTEIRIZACAO_PARCEIROS
    // - Join por COD_PARCEIRO normalizado (sem zeros à esquerda)
    // - NOME_PARCEIRO prioriza carteirização quando houver match
    // - COD_PARCEIRO do output também é normalizado
    // ======================================================
    SomenteManterFinal0 = Table.SelectRows(WithDbgSource, each [ELEGIVEL] = "Manter"),

    FatoComKey = Table.AddColumn(
        SomenteManterFinal0,
        "COD_PARCEIRO_KEY",
        each fxCodKey(try [COD_PARCEIRO] otherwise null),
        type text
    ),

    Cart0 = CARTEIRIZACAO_PARCEIROS,
    CartCols = Table.ColumnNames(Cart0),

    CartCodCol =
        if List.Contains(CartCols, "COD_PARCEIRO") then "COD_PARCEIRO"
        else if List.Contains(CartCols, "MEDIADOR") then "MEDIADOR"
        else if List.Contains(CartCols, "CODIGO_PARCEIRO") then "CODIGO_PARCEIRO"
        else "COD_PARCEIRO",

    CartSegCol =
        if List.Contains(CartCols, "SEGMENTAÇÃO") then "SEGMENTAÇÃO"
        else if List.Contains(CartCols, "SEGMENTACAO") then "SEGMENTACAO"
        else if List.Contains(CartCols, "SEGMENTACAO_PARCEIROA") then "SEGMENTACAO_PARCEIROA"
        else "SEGMENTAÇÃO",

CartNomCol =
    if List.Contains(CartCols, "NOME_PARCEIRO") then "NOME_PARCEIRO"
    else if List.Contains(CartCols, "NOME_PARCEIRO") then "NOME_PARCEIRO"
    else if List.Contains(CartCols, "NOME_PARCEIROA") then "NOME_PARCEIROA"
    else if List.Contains(CartCols, "PARCEIRO") then "PARCEIRO"
    else "NOME_PARCEIRO",

    CartKey =
        let
            t1 = Table.AddColumn(Cart0, "COD_PARCEIRO_KEY", each fxCodKey(try Record.Field(_, CartCodCol) otherwise null), type text),
            t2 = Table.SelectRows(t1, each [COD_PARCEIRO_KEY] <> null),
            t3 = Table.Group(
                t2,
                {"COD_PARCEIRO_KEY"},
                {
                    {"SEGMENTACAO_CART", (tbl) => try List.Last(List.RemoveNulls(Table.Column(tbl, CartSegCol))) otherwise null, type any},
                    {"NOME_PARCEIRO_CART", (tbl) => try List.Last(List.RemoveNulls(Table.Column(tbl, CartNomCol))) otherwise null, type any}
                }
            ),
            t4 = Table.TransformColumnTypes(t3, {{"SEGMENTACAO_CART", type text}, {"NOME_PARCEIRO_CART", type text}})
        in
            t4,

    MergeCart = Table.NestedJoin(
        FatoComKey,
        {"COD_PARCEIRO_KEY"},
        CartKey,
        {"COD_PARCEIRO_KEY"},
        "CART",
        JoinKind.LeftOuter
    ),

    ExpCart = Table.ExpandTableColumn(
        MergeCart,
        "CART",
        {"SEGMENTACAO_CART","NOME_PARCEIRO_CART"},
        {"SEGMENTACAO_PARCEIROA","NOME_PARCEIRO_CART"}
    ),

    FixNomCorretor = Table.AddColumn(
        ExpCart,
        "NOME_PARCEIRO_FIX",
        each
            let
                a = fxTrimAll(try [NOME_PARCEIRO_CART] otherwise ""),
                b = fxTrimAll(try [NOME_PARCEIRO] otherwise "")
            in
                if a <> "" then a else b,
        type text
    ),

FixCodCorretor =
let
    T = FixNomCorretor,
    has = List.Contains(Table.ColumnNames(T), "COD_PARCEIRO"),
    Out =
        if has then
            Table.TransformColumns(
                T,
                {{"COD_PARCEIRO", (v) => fxCodKey(v), type text}}
            )
        else
            T
in
    Out,


    DropOldNom = Table.RemoveColumns(
        FixCodCorretor,
        List.Intersect({Table.ColumnNames(FixCodCorretor), {"NOME_PARCEIRO","NOME_PARCEIRO_CART"}})
    ),

 RenameNom = Table.RenameColumns(
    DropOldNom,
    {{"NOME_PARCEIRO_FIX","NOME_PARCEIRO"}},
    MissingField.Ignore
),

// ===== FLAG MATCH CARTEIRIZACAO (pra mapear "SEM MATCH") =====
AddMatchCarteirizacao =
    Table.AddColumn(
        RenameNom,
        "MATCH_CARTEIRIZACAO",
        each
            let seg = try [SEGMENTACAO_PARCEIROA] otherwise null
            in if seg = null or fxBlankLike(Text.From(seg)) then "SEM MATCH" else "OK",
        type text
    ),

// STATUS_FINAL — usando D-1
AddStatusFinal =
    Table.AddColumn(
        AddMatchCarteirizacao,
        "STATUS_FINAL",
        (r) =>
        let
            isNova = fxBlankLike(try r[RESPONSAVEL_ANTERIOR] otherwise null),
            atribuida = fxTrimAll(try r[RESPONSAVEL_AJUSTADO] otherwise "") <> "",
            ferias = try Logical.From(r[FERIAS_DESTINO]) otherwise false,
            base =
                if isNova and atribuida and ferias then "NOVA (ATRIBUÍDA FÉRIAS)"
                else if isNova and atribuida then "NOVA (ATRIBUÍDA)"
                else if isNova and ferias then "NOVA (FÉRIAS)"
                else if isNova then "NOVA"
                else if (not isNova) and atribuida and ferias then "RETORNADA (FÉRIAS ATRIBUÍDA)"
                else if (not isNova) and atribuida then "RETORNADA (ATRIBUÍDA)"
                else if (not isNova) and ferias then "RETORNADA (FÉRIAS)"
                else "RETORNADA"
        in
            base,
        type text
    ),

    // Seleção mínima para modelo (mesma ordem da sua FATO antiga)
    ColsEssenciais = {
        "ID_PROPOSTA","DATASET_DATE","STATUS_FINAL","DATA_PROPOSTA","DATA_PROPOSTA_TXT",
        "UNIDADE","NOME_PARCEIRO","COD_PARCEIRO","SEGMENTACAO_PARCEIROA","MATCH_CARTEIRIZACAO","ATIVIDADE",
        "RESPONSAVEL_ANTERIOR","RESPONSAVEL_AJUSTADO","RESPONSAVEL_MAP",
        "RESPONSAVEL_DESTINO","RESPONSAVEL_REDIS","RESPONSAVEL_FINAL",
        "DESTINO_EM_FERIAS","FERIAS_ANTERIOR","FERIAS_DESTINO",
        "714","1701","2279","8027","8030","CEP","ENDERECO","NUMERO","COMPLEMENTO",
        "ID_CLIENTE","VALOR_PREMIO","VL_VALOR_PREMIO","VL_RISCO",
        "LB_DATE"
    },

    Minimized = Table.SelectColumns(AddStatusFinal, ColsEssenciais, MissingField.Ignore),

    // Remove colunas redundantes e de debug (seguindo sua FATO antiga)
    ColsRemover = {
        "ELEGIVEL","DBG_DATA_COL","DBG_DATE_SOURCE",
        "RESPONSAVEL_VISUAL","RESPONSAVEL_BASE_REDIS",
        "RETORNO","STATUS_ALOCACAO",
        "DEBUG_DATAS","DESC_CATEGORIA"
    },

    SemSuperfluas = Table.RemoveColumns(Minimized, List.Intersect({Table.ColumnNames(Minimized), ColsRemover})),

    // ============================
    // START INSPEÇÃO (DE/PARA) — PATCH CASAMENTO FORTE
    // ============================
    BaseParaStart0 = SemSuperfluas,
    BaseParaStart = Table.AddIndexColumn(BaseParaStart0, "__IDX__", 1, 1, Int64.Type),

    // ---------- (0) TRIM HARD local (reforça ainda mais além do fxTrimAll) ----------
    fxTrimHard = (x as nullable any) as text =>
        let
            t0 = if x=null then "" else Text.From(x),
            // remove NBSP e whitespace "esquisito"
            r1 = Text.Replace(t0, Character.FromNumber(160), " "),
            r2 = Text.Replace(r1, Character.FromNumber(9), " "),
            r3 = Text.Replace(r2, Character.FromNumber(10), " "),
            r4 = Text.Replace(r3, Character.FromNumber(13), " "),
            r5 = Text.Replace(r4, Character.FromNumber(8232), " "),
            r6 = Text.Replace(r5, Character.FromNumber(8233), " "),
            r7 = Text.Replace(r6, Character.FromNumber(8203), ""),
            r8 = Text.Replace(r7, Character.FromNumber(65279), ""),
            out = Text.Trim(r8)
        in
            out,

    // ---------- (1) Normalização comum (pontuação/hífens/&/abreviações) ----------
    fxCleanCommon = (t as nullable text) as nullable text =>
        let
            s0 = if t=null then null else fxTrimHard(t),
            s1 = if s0=null then null else Text.Upper(s0),

            // Expansões simples de abreviação (ajudam MUITO no seu caso)
            repl = {
                {"DISTRIB.", "DISTRIBUICAO"},
                {"DIST.", "DISTRIBUICAO"},
                {"ART.", "ARTIGO"},
                {"ART ", "ARTIGO "},
                {"EXC.", "EXCETO"},
                {"EXC ", "EXCETO "},
                {"SUBST.", "SUBSTANCIAS"},
                {"SUBST ", "SUBSTANCIAS "},
                {"C/", "COM "},
                {"S/", "SEM "},
                {"PROIBIDO", "PROIBIDO"},
                {"1°", "1"},
                {"2°", "2"},
                {"3°", "3"}
            },
            s1b = if s1=null then null else List.Accumulate(repl, s1, (st, p) => Text.Replace(st, p{0}, p{1})),

            // Normaliza hífens e barras e "&"
            s2 = if s1b=null then null else
                Text.Replace(
                    Text.Replace(
                        Text.Replace(
                            Text.Replace(
                                Text.Replace(s1b, "–", "-"),
                            "—", "-"),
                        "/", " "),
                    "\\", " "),
                "&", " E "),

            // Remove pontuação comum (vira espaço)
            punct = {",",".",";"," :",":","\","'","""","`","´","^","~","!","?","*","#","@","$","%","¨","=","+","<",">"},
            s3 = if s2=null then null else List.Accumulate(punct, s2, (st, p) => Text.Replace(st, p, " ")),

            // Remove parênteses/colchetes/chaves (mantém conteúdo)
            s4 = if s3=null then null else List.Accumulate({"(",")","[","]","{","}"}, s3, (st, p) => Text.Replace(st, p, " ")),

            // Remove acentos (usa sua função)
            s5 = if s4=null then null else fxNormalize(s4, true),

            // Colapsa espaços múltiplos
            parts = if s5=null then {} else List.Select(Text.Split(s5, " "), each _ <> ""),
            out = if s5=null then null else Text.Combine(parts, " ")
        in
            out,

    // ---------- (2) LOOSE: remove stopwords ----------
    fxCleanLoose = (t as nullable text) as nullable text =>
        let
            base = fxCleanCommon(t),
            stop = {" DE "," DA "," DO "," DAS "," DOS "," E "," EM "," NO "," NA "," NOS "," NAS "," PARA "," POR "," COM "," AO "," AOS "," AS "," OS "," O "," A "},
            pad0 = if base=null then null else " " & base & " ",
            pad1 = if pad0=null then null else List.Accumulate(stop, pad0, (st, w) => Text.Replace(st, w, " ")),
            parts = if pad1=null then {} else List.Select(Text.Split(pad1, " "), each _ <> ""),
            out = if pad1=null then null else Text.Combine(parts, " ")
        in
            out,

    // ---------- (3) STEM: singularização SEGURA (só OS/AS/US) ----------
    fxSingularTokenSafe = (w as text) as text =>
        let
            W = w,
            last2 = if Text.Length(W) >= 2 then Text.End(W, 2) else ""
        in
            if Text.Length(W) <= 4 then W
            else if List.Contains({"OS","AS","US"}, last2) then Text.Start(W, Text.Length(W)-1) // remove só o "S"
            else W,

    fxCleanStem = (t as nullable text) as nullable text =>
        let
            base = fxCleanCommon(t),
            toks = if base=null then {} else List.Select(Text.Split(base, " "), each _ <> ""),
            toks2 = List.Transform(toks, each fxSingularTokenSafe(_)),
            out = if base=null then null else Text.Combine(toks2, " ")
        in
            out,

    // ---------- (4) FATO: cria chaves ----------
    FatoKey =
        Table.AddColumn(
            Table.AddColumn(
                Table.AddColumn(BaseParaStart, "ATIVIDADE_KEY_STRICT", each fxCleanCommon(try [ATIVIDADE] otherwise null), type text),
                "ATIVIDADE_KEY_LOOSE", each fxCleanLoose(try [ATIVIDADE] otherwise null), type text
            ),
            "ATIVIDADE_KEY_STEM", each fxCleanStem(try [ATIVIDADE] otherwise null), type text
        ),

    // ---------- (5) DE/PARA: NOVO START ----------
    StartRaw0 = #"NOVO START",

    // Corrige header com espaço final
    StartRaw =
        if List.Contains(Table.ColumnNames(StartRaw0), "NOVO VL_RISCO ")
        then Table.RenameColumns(StartRaw0, {{"NOVO VL_RISCO ", "NOVO VL_RISCO"}}, MissingField.Ignore)
        else StartRaw0,

    StartKey =
        Table.AddColumn(
            Table.AddColumn(
                Table.AddColumn(StartRaw, "ATIVIDADE_KEY_STRICT", each fxCleanCommon(try [ATIVIDADE] otherwise null), type text),
                "ATIVIDADE_KEY_LOOSE", each fxCleanLoose(try [ATIVIDADE] otherwise null), type text
            ),
            "ATIVIDADE_KEY_STEM", each fxCleanStem(try [ATIVIDADE] otherwise null), type text
        ),

    // Uma linha por chave — pega a última ocorrência não nula
    StartStrict =
        Table.Group(
            StartKey,
            {"ATIVIDADE_KEY_STRICT"},
            {{"START_ANTIGO", each List.Last(List.RemoveNulls([VL_RISCO])), type number},
             {"START_NOVO", each List.Last(List.RemoveNulls([NOVO VL_RISCO])), type number}}
        ),

    StartLoose =
        Table.Group(
            StartKey,
            {"ATIVIDADE_KEY_LOOSE"},
            {{"START_ANTIGO_L", each List.Last(List.RemoveNulls([VL_RISCO])), type number},
             {"START_NOVO_L", each List.Last(List.RemoveNulls([NOVO VL_RISCO])), type number}}
        ),

    StartStem =
        Table.Group(
            StartKey,
            {"ATIVIDADE_KEY_STEM"},
            {{"START_ANTIGO_T", each List.Last(List.RemoveNulls([VL_RISCO])), type number},
             {"START_NOVO_T", each List.Last(List.RemoveNulls([NOVO VL_RISCO])), type number}}
        ),

    // ---------- (6) Merge STRICT ----------
    MergeStrict =
        Table.NestedJoin(FatoKey, {"ATIVIDADE_KEY_STRICT"}, StartStrict, {"ATIVIDADE_KEY_STRICT"}, "LKP_S", JoinKind.LeftOuter),
    ExpStrict =
        Table.ExpandTableColumn(MergeStrict, "LKP_S", {"START_ANTIGO","START_NOVO"}, {"START_ANTIGO","START_NOVO"}),

    // ---------- (7) Merge LOOSE (fallback) ----------
    NeedLoose =
        Table.SelectRows(ExpStrict, each (try [START_NOVO] otherwise null) = null and (try [START_ANTIGO] otherwise null) = null),

    MergeLoose =
        Table.NestedJoin(NeedLoose, {"ATIVIDADE_KEY_LOOSE"}, StartLoose, {"ATIVIDADE_KEY_LOOSE"}, "LKP_L", JoinKind.LeftOuter),
    ExpLoose =
        Table.ExpandTableColumn(MergeLoose, "LKP_L", {"START_ANTIGO_L","START_NOVO_L"}, {"START_ANTIGO_L","START_NOVO_L"}),

    KeptStrict =
        Table.SelectRows(ExpStrict, each not ((try [START_NOVO] otherwise null)=null and (try [START_ANTIGO] otherwise null)=null)),
    Recomb1 = Table.Combine({KeptStrict, ExpLoose}),

    // ---------- (8) Merge STEM (fallback final) ----------
    NeedStem =
        Table.SelectRows(
            Recomb1,
            each
                (try [START_NOVO] otherwise null) = null and (try [START_ANTIGO] otherwise null) = null and
                (try [START_NOVO_L] otherwise null) = null and (try [START_ANTIGO_L] otherwise null) = null
        ),

    MergeStem =
        Table.NestedJoin(NeedStem, {"ATIVIDADE_KEY_STEM"}, StartStem, {"ATIVIDADE_KEY_STEM"}, "LKP_T", JoinKind.LeftOuter),
    ExpStem =
        Table.ExpandTableColumn(MergeStem, "LKP_T", {"START_ANTIGO_T","START_NOVO_T"}, {"START_ANTIGO_T","START_NOVO_T"}),

    Kept12 =
        Table.SelectRows(
            Recomb1,
            each not (
                (try [START_NOVO] otherwise null)=null and (try [START_ANTIGO] otherwise null)=null and
                (try [START_NOVO_L] otherwise null)=null and (try [START_ANTIGO_L] otherwise null)=null
            )
        ),

    Recombined0 = Table.Combine({Kept12, ExpStem}),

    // ---------- (9) Coalesce (STRICT > LOOSE > STEM) ----------
    AddFixA =
        Table.AddColumn(
            Recombined0,
            "START_ANTIGO_FIX",
            each
                let a  = try [START_ANTIGO] otherwise null,
                    al = try [START_ANTIGO_L] otherwise null,
                    at = try [START_ANTIGO_T] otherwise null
                in if a<>null then a else if al<>null then al else at,
            type number
        ),

    AddFixN =
        Table.AddColumn(
            AddFixA,
            "START_NOVO_FIX",
            each
                let n  = try [START_NOVO] otherwise null,
                    nl = try [START_NOVO_L] otherwise null,
                    nt = try [START_NOVO_T] otherwise null
                in if n<>null then n else if nl<>null then nl else nt,
            type number
        ),

    // Threshold efetivo (novo se existir; senão antigo)
    AddVLIncendStart =
        Table.AddColumn(
            AddFixN,
            "VL_RISCO_START",
            each
                let sN = try Number.From([START_NOVO_FIX]) otherwise null,
                    sA = try Number.From([START_ANTIGO_FIX]) otherwise null
                in if sN <> null then sN else sA,
            type number
        ),

    // Mensagem “NOVA REGRA” vs “SEM ALTERAÇÃO”
    AddNovoRegra =
        Table.AddColumn(
            AddVLIncendStart,
            "NOVO VL_RISCO",
            each
                let
                    vRisco = try Number.From([VL_RISCO]) otherwise null,
                    sA = try Number.From([START_ANTIGO_FIX]) otherwise null,
                    sN = try Number.From([START_NOVO_FIX]) otherwise null,
                    start = try Number.From([VL_RISCO_START]) otherwise null
                in
                    if vRisco = null or start = null then null
                    else if sA <> null and sN <> null and sA = sN then "SEM ALTERAÇÃO"
                    else if vRisco > start then "INSPEÇÃO (NOVA REGRA)"
                    else "EMITE DIRETO (NOVA REGRA)",
            type text
        ),

    // Limpa colunas auxiliares e restaura ordem original
    CleanAux =
        Table.RemoveColumns(
            AddNovoRegra,
            List.Intersect(
                {Table.ColumnNames(AddNovoRegra),
                 {"ATIVIDADE_KEY_STRICT","ATIVIDADE_KEY_LOOSE","ATIVIDADE_KEY_STEM",
                  "START_ANTIGO_L","START_NOVO_L","START_ANTIGO_T","START_NOVO_T",
                  "START_ANTIGO_FIX","START_NOVO_FIX"}}
            )
        ),

    BackToOrder = Table.Sort(CleanAux, {{"__IDX__", Order.Ascending}}),
    FinalBase = Table.RemoveColumns(BackToOrder, {"__IDX__"}),

    // >>>>> AJUSTE: garantir SEGMENTACAO_PARCEIROA na ordenação final
    Out_FATO =
        Table.ReorderColumns(
            FinalBase,
            {
                "ID_PROPOSTA","DATASET_DATE","STATUS_FINAL","DATA_PROPOSTA","DATA_PROPOSTA_TXT",
                "UNIDADE","NOME_PARCEIRO","COD_PARCEIRO","SEGMENTACAO_PARCEIROA","MATCH_CARTEIRIZACAO","ATIVIDADE",
                "RESPONSAVEL_ANTERIOR","RESPONSAVEL_AJUSTADO","RESPONSAVEL_MAP",
                "RESPONSAVEL_DESTINO","RESPONSAVEL_REDIS","RESPONSAVEL_FINAL",
                "DESTINO_EM_FERIAS","FERIAS_ANTERIOR","FERIAS_DESTINO",
                "714","1701","2279","8027","8030","CEP","ENDERECO","NUMERO","COMPLEMENTO",
                "ID_CLIENTE","VALOR_PREMIO","VL_VALOR_PREMIO","VL_RISCO",
                "VL_RISCO_START","START_ANTIGO","START_NOVO","NOVO VL_RISCO",
                "LB_DATE"
            },
            MissingField.Ignore
        ),
    #"Colunas Renomeadas" = Table.RenameColumns(Out_FATO,{{"SEGMENTACAO_PARCEIROA", "SEGMENTAÇÃO"}, {"NOME_PARCEIRO", "NOME PARCEIRO"}, {"ID_CLIENTE", "CPF/CNPJ"}})
in
    #"Colunas Renomeadas"