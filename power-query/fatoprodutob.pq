// =============================================
// DISTRIBUIR PRODUTO_B — FATO (Produto B) — versão anonimizada
// =============================================
let
  // ==== Funções utilitárias (FUNCOES_COMPARTILHADAS) ====
  fxSPFileBin      = FUNCOES_COMPARTILHADAS[fxSPFileBin],
  fxTrimAll        = FUNCOES_COMPARTILHADAS[fxTrimAll],
  fxNormalize      = FUNCOES_COMPARTILHADAS[fxNormalize],
  fxBlankLike      = FUNCOES_COMPARTILHADAS[fxBlankLike],
  fxToDate         = FUNCOES_COMPARTILHADAS[fxToDate],
  fxCleanUnidade    = FUNCOES_COMPARTILHADAS[fxCleanUnidade],
  fxPickWeighted   = FUNCOES_COMPARTILHADAS[fxPickWeighted],

  // ==== Helpers locais seguros ====
  NormText  = (x as any) as text => Text.Upper(Text.Trim( try Text.From(x) otherwise "" )),
  SafeText  = (x as any) as nullable text => try fxTrimAll(Text.From(x)) otherwise null,
  SafeUpper = (x as any) as text => Text.Upper( fxTrimAll( try Text.From(x) otherwise "" ) ),
  IsUserLogin = (t as nullable text) as logical =>
                  let s = SafeUpper(t) in s <> "" and (Text.StartsWith(s, "SYS_A") or Text.StartsWith(s, "SYS_B")),

  // ==== Âncora temporal D-1 (fuso RJ) ====
  NowRJ        = DateTimeZone.SwitchZone(DateTimeZone.UtcNow(), -3),
  D1Calendar   = Date.AddDays(Date.From(DateTimeZone.RemoveZone(NowRJ)), -1),
  DATASET_DATE = D1Calendar,
  DBG_SOURCE   = "CALENDAR.D-1",

  // ==== TXT ATUAL ====
  Bin_ATUAL = fxSPFileBin("TXT_PRODUTO_B","ARQUIVO_PRODUTO_B_ATUAL.txt"),
  TXT_src   =
    if Bin_ATUAL <> null
    then Csv.Document(
           Bin_ATUAL,
           [
             Delimiter=";", Columns=58, Encoding=1252,
             CsvStyle=CsvStyle.QuoteAfterDelimiter, QuoteStyle=QuoteStyle.Csv,
             ExtraValues=ExtraValues.Ignore
           ])
    else #table({"Column1"}, {}),

  TXT_typ   = Table.TransformColumnTypes(TXT_src, List.Transform({1..58}, each {"Column" & Text.From(_), type text})),
  TXT_hdr   = Table.PromoteHeaders(TXT_typ, [PromoteAllScalars=true]),

  // ==== Detectar coluna de data + auditoria ====
  FindDateCol = (cols as list) as nullable text =>
    let
      aliases = {
        "DATA_TRANS","DATA TRANS","DATATRANS","DATA","DATA_PROPOSTA","DATA DA PROPOSTA","DT_PROPOSTA",
        "DT TRANS","DT_TRANSACAO","DATA TRANSACAO","DATA DA TRANSACAO"
      },
      norm = (t as text) as text => fxNormalize( fxTrimAll( Text.Replace(Text.Replace(t,"_"," "),"-"," ") ), true ),
      colsN = List.Transform(cols, each [Orig=_, N=norm(Text.From(_))]),
      aliN  = List.Transform(aliases, each norm(_)),
      hit   = List.First(List.Select(colsN, each List.Contains(aliN, _[N])), null)
    in if hit=null then null else hit[Orig],

  DataColName = FindDateCol(Table.ColumnNames(TXT_hdr)),
  TXT_dbg     = Table.AddColumn(TXT_hdr, "DBG_DATA_COL", each DataColName, type text),

  // ==== Aliases de endereço/identificação ====
  PickFirstExisting = (cols as list, candidates as list) as nullable text =>
    let hit = List.Intersect({cols, candidates}) in if List.Count(hit)>0 then hit{0} else null,

  EnderecoCol    = PickFirstExisting(Table.ColumnNames(TXT_dbg), {"ENDERECO","LOGRADOURO","END"}),
  NumeroCol      = PickFirstExisting(Table.ColumnNames(TXT_dbg), {"NUMERO","NUM"}),
  ComplementoCol = PickFirstExisting(Table.ColumnNames(TXT_dbg), {"COMPLEMENTO","COMP_END","COMP"}),
  CepCol         = PickFirstExisting(Table.ColumnNames(TXT_dbg), {"CEP"}),
  CpfCnpjCol     = PickFirstExisting(Table.ColumnNames(TXT_dbg), {"ID_CLIENTE","ID_CLIENTE","ID_CLIENTE"}),
  PremioCol      = PickFirstExisting(Table.ColumnNames(TXT_dbg), {"VALOR_PREMIO"}),

  // ==== Guard-clause de campos essenciais ====
  MustHave_Cond = {"ID_PROPOSTA","USUARIO_ORIGEM","UNIDADE","FLAG_JANELA","FLAG_PRIORIDADE_A","FLAG_PRIORIDADE_B","VALOR_PREMIO_LIQUIDO","DESC_CATEGORIA"},
  OptionalAddr  = List.RemoveNulls({CepCol, EnderecoCol, NumeroCol, ComplementoCol, CpfCnpjCol, PremioCol}),
  BaseCols      = List.Intersect({Table.ColumnNames(TXT_dbg), MustHave_Cond}),
  TXT_sel       =
    if List.Count(BaseCols) >= 6
    then Table.SelectColumns(TXT_dbg, List.Union({{"ID_PROPOSTA"}, BaseCols, {DataColName}, OptionalAddr}), MissingField.Ignore)
    else error "TXT_PRODUTO_B: colunas essenciais ausentes. Verifique cabeçalhos.",

  // ==== Renomeia aliases para padrão ====
  Renames = List.RemoveNulls({
              if EnderecoCol    <> null and EnderecoCol    <> "ENDERECO"          then {EnderecoCol,    "ENDERECO"}          else null,
              if NumeroCol      <> null and NumeroCol      <> "NUMERO"            then {NumeroCol,      "NUMERO"}            else null,
              if ComplementoCol <> null and ComplementoCol <> "COMPLEMENTO"       then {ComplementoCol, "COMPLEMENTO"}       else null,
              if CepCol         <> null and CepCol         <> "CEP"               then {CepCol,         "CEP"}               else null,
              if CpfCnpjCol     <> null and CpfCnpjCol     <> "ID_CLIENTE"  then {CpfCnpjCol,     "ID_CLIENTE"}  else null,
              if PremioCol      <> null and PremioCol      <> "VALOR_PREMIO"            then {PremioCol,      "VALOR_PREMIO"}            else null
            }),
  TXT_ren  = if List.Count(Renames)>0 then Table.RenameColumns(TXT_sel, Renames, MissingField.Ignore) else TXT_sel,

  // ==== Tipos + DATA_PROPOSTA (+ textual) ====
  TXT_cast  = Table.TransformColumnTypes(
                TXT_ren,
                {
                  {"ID_PROPOSTA", type text},{"USUARIO_ORIGEM", type text},{"UNIDADE", type text},
                  {"ENDERECO", type text},{"NUMERO", type text},{"COMPLEMENTO", type text},
                  {"CEP", type text},{"ID_CLIENTE", type text}
                }
              ),
  TXT_dt    = if DataColName<>null
              then Table.AddColumn(TXT_cast, "DATA_PROPOSTA", each fxToDate(Record.Field(_, DataColName)), type date)
              else Table.AddColumn(TXT_cast, "DATA_PROPOSTA", each null, type date),
  TXT_dttxt = Table.AddColumn(TXT_dt, "DATA_PROPOSTA_TXT",
                each if [DATA_PROPOSTA] = null then null else Date.ToText([DATA_PROPOSTA], "dd/MM/yyyy","pt-BR"), type text),
  TXT_fil   = Table.TransformColumns(TXT_dttxt, {{"UNIDADE", each if _=null then null else fxCleanUnidade(_), type text}}),

  // ==== ATIVIDADE (fallback de DESC_CATEGORIA) ====
  AtvSrc =
    if List.Contains(Table.ColumnNames(TXT_fil), "ATIVIDADE")   then "ATIVIDADE"
    else if List.Contains(Table.ColumnNames(TXT_fil), "DESC_CATEGORIA") then "DESC_CATEGORIA"
    else null,
  TXT_withAtv =
    if      AtvSrc<>null and AtvSrc<>"ATIVIDADE" then Table.AddColumn(TXT_fil, "ATIVIDADE", each try Record.Field(_, AtvSrc) otherwise null, type text)
    else if AtvSrc=null                           then Table.AddColumn(TXT_fil, "ATIVIDADE", each null, type text)
    else                                               TXT_fil,

  // ==== Index/ocorrência por ID_PROPOSTA (estabilidade) ====
  TXT_RowId = Table.AddIndexColumn(TXT_withAtv, "ROW_ID", 1, 1, Int64.Type),
  TXT_GroupedForOcc =
    Table.Group(TXT_RowId, {"ID_PROPOSTA"},
      {{"T", (tbl) => Table.AddIndexColumn(tbl, "OCORR_ID_PROPOSTA", 1, 1, Int64.Type), type table}}),
  _innerCols       = Table.ColumnNames(TXT_RowId),
  _expandColsBase  = List.RemoveItems(_innerCols, {"ID_PROPOSTA"}),
  _expandCols      = List.Combine({_expandColsBase, {"OCORR_ID_PROPOSTA"}}),
  TXT_readyForMerge = Table.ExpandTableColumn(TXT_GroupedForOcc, "T", _expandCols, _expandCols),

  // ==== ATRIBUIR (ID_PROPOSTA) ====
  AtribUnica = Table.Buffer(ATRIBUIR_PRODUTO_B_UNICA),
  MergeAtrib = Table.NestedJoin(TXT_readyForMerge, {"ID_PROPOSTA"}, AtribUnica, {"ID_PROPOSTA"}, "ATRIB", JoinKind.LeftOuter),
  ExpAtrib   = Table.ExpandTableColumn(MergeAtrib, "ATRIB", {"RESPONSAVEL_AJUSTADO"}),

  // ==== MAP: UNIDADE → RESPONSAVEL (consolidação 1:1 segura) ====
  MAP_cols   = Table.TransformColumnNames(UNIDADERESPONSAVEL_PRODUTO_B_SPO, each Text.Trim(Text.Replace(_, "  ", " "))),
  MAP_clean  = Table.TransformColumns(MAP_cols, {{"UNIDADE", each fxCleanUnidade(_), type text},{"RESPONSAVEL", each fxTrimAll(_), type text}}),
  MAP_idx    = Table.AddIndexColumn(MAP_clean, "_IX", 1, 1, Int64.Type),
  MAP_sort   = Table.Sort(MAP_idx, {{"_IX", Order.Ascending}}),
  MAP_unica  = Table.Group(MAP_sort, {"UNIDADE"}, {{"RESPONSAVEL", each List.Last(List.RemoveNulls([RESPONSAVEL])), type text}}),
  GLOBAL_PADRAO =
    let lst = List.RemoveNulls(MAP_sort[RESPONSAVEL]) in if List.Count(lst)>0 then fxTrimAll(List.Last(lst)) else "RESPONSAVEL_PADRAO",

  MergeMap   = Table.NestedJoin(ExpAtrib, {"UNIDADE"}, MAP_unica, {"UNIDADE"}, "MAP", JoinKind.LeftOuter),
  ExpMap     = Table.ExpandTableColumn(MergeMap, "MAP", {"RESPONSAVEL"}, {"RESPONSAVEL_MAP"}),

  // ==== Lookups auxiliares de fallback ====
  GetMapForUnidade = (fil as any) as nullable text =>
    let f = fxCleanUnidade(fil),
        r = try Table.SelectRows(MAP_unica, (x)=> x[UNIDADE] = f){0}[RESPONSAVEL] otherwise null
    in SafeText(r),

  GetAtribForProposta = (pol as any) as nullable text =>
    let p = fxTrimAll(Text.From(pol)),
        r = try Table.SelectRows(AtribUnica, (x)=> fxTrimAll(Text.From(x[ID_PROPOSTA])) = p){0}[RESPONSAVEL_AJUSTADO] otherwise null
    in SafeText(r),

  // ==== Responsável destino (cadeia completa, evitando prefixos técnicos e null) ====
  AddDestino =
    Table.AddColumn(
      ExpMap, "RESPONSAVEL_DESTINO",
      each
        let
          adj = SafeText( try [RESPONSAVEL_AJUSTADO] otherwise null ),
          map = SafeText( try [RESPONSAVEL_MAP]      otherwise null ),
          usr = SafeText( try [USUARIO_ORIGEM]             otherwise null ),
          fil = SafeText( try [UNIDADE]              otherwise null ),
          pol = SafeText( try [ID_PROPOSTA]              otherwise null ),

          mapLookup   = SafeText( try GetMapForUnidade(fil)   otherwise null ),
          atribLookup = SafeText( try GetAtribForProposta(pol) otherwise null ),

          pick =
            if adj<>null and adj<>"" then adj
            else if map<>null and map<>"" then map
            else if usr<>null and usr<>"" and not IsUserLogin(usr) then usr
            else if mapLookup<>null and mapLookup<>"" then mapLookup
            else if atribLookup<>null and atribLookup<>"" then atribLookup
            else GLOBAL_PADRAO
        in pick,
      type text
    ),

  // ==== DATASET_DATE (D) ====
  AddDatasetDate = Table.AddColumn(AddDestino, "DATASET_DATE", each DATASET_DATE, type date),

// ==== Elegibilidade (Produto B) — versão reforçada ====
// Garante que prioridades A/B sempre entram; FLAG_JANELA só por janela/sem data; leitura "S/N" robusta
normSN = (x as any) as text =>
  let
    t0 = try Text.From(x) otherwise "",
    // remove NBSP, NNBSP e outros espaços invisíveis
    t1 = Text.Select(t0, {"A".."Z","a".."z","0".."9"}),
    up = Text.Upper(fxTrimAll(t1))
  in up,

AddElegivel =
  Table.AddColumn(
    AddDatasetDate, "ELEGIVEL",
    (r) =>
      let
        refDate  = r[DATASET_DATE],
        winStart = Date.AddDays(refDate, -14),
        winEnd   = Date.AddDays(refDate, -12),

        isFlagPrioridadeA = normSN( try r[#"FLAG_PRIORIDADE_A"] otherwise "" ) = "S",
        isFlagPrioridadeB = normSN( try r[#"FLAG_PRIORIDADE_B"] otherwise "" ) = "S",
        isFlagJanela  = normSN( try r[#"FLAG_JANELA" ] otherwise "" ) = "S",

        // PRIORITÁRIAS entram SEMPRE
        isPrior = isFlagPrioridadeA or isFlagPrioridadeB,

        dt = try Date.From( r[DATA_PROPOSTA] ) otherwise null,

        inJanela  = isFlagJanela and (dt <> null) and (dt >= winStart) and (dt <= winEnd),
        semData   = isFlagJanela and (dt = null),

        // --- (Opcional) corte de finalizadas se você tiver a coluna STATUS_PROCESSAMENTO:
        // isEmitida = normSN( try r[STATUS_PROCESSAMENTO] otherwise "" ) = "EMITIDA",

        eleg =
          try
            if isPrior then "Manter"                      // blindagem
            else if inJanela or semData then "Manter"     // FLAG_JANELA dentro da regra
            else "Excluir"
          otherwise "Excluir"
      in eleg,
    type text
  ),
  // ==== Ausências + Redistribuição ====

// Base de ausências com cultura pt-BR
FER_typ =
    Table.TransformColumnTypes(
        AUSENCIAS_PRODUTO_B_SPO,
        {{"RESPONSAVEL", type text}, {"INICIO", type date}, {"FIM", type date}},
        "pt-BR"
    ),

// Remove linhas vazias / lixo
FER_CLEAN =
    Table.SelectRows(
        FER_typ,
        each [RESPONSAVEL] <> null
          and Text.Trim(Text.From([RESPONSAVEL])) <> ""
          and [INICIO] <> null
          and [FIM] <> null
    ),

// Só ausências ativas na DATASET_DATE
FER_ATIVAS =
    Table.SelectRows(
        FER_CLEAN,
        each [INICIO] <= DATASET_DATE and [FIM] >= DATASET_DATE
    ),

// Normaliza os nomes em ausências
FER_ATIVAS_N =
    Table.TransformColumns(
        FER_ATIVAS,
        {{"RESPONSAVEL", each fxNormalize(Text.From(_), true), type text}}
    ),

SUBS_AUSENCIAS =
    if Table.RowCount(FER_ATIVAS_N) = 0
    then {}
    else List.RemoveNulls(FER_ATIVAS_N[RESPONSAVEL]),

// Normaliza destino uma única vez
AddDestinoNorm =
    Table.AddColumn(
        AddElegivel,
        "RESPONSAVEL_DESTINO_NORM",
        each fxNormalize(fxTrimAll(try [RESPONSAVEL_DESTINO] otherwise ""), true),
        type text
    ),

// Marca destino em ausências sem join, direto pela lista
AddDestinoAusencias =
    Table.AddColumn(
        AddDestinoNorm,
        "DESTINO_EM_AUSENCIAS",
        each
            let
                destNorm = try [RESPONSAVEL_DESTINO_NORM] otherwise ""
            in
                destNorm <> "" and List.Contains(SUBS_AUSENCIAS, destNorm),
        type logical
    ),

// Base para redistribuição só quando destino está em ausências
AddBaseRedis =
    Table.AddColumn(
        AddDestinoAusencias,
        "RESPONSAVEL_BASE_REDIS",
        each if (try [DESTINO_EM_AUSENCIAS] otherwise false) then [RESPONSAVEL_DESTINO] else null,
        type text
    ),

// --- Redistribuição: limpar e manter só colunas úteis ---
DistColsUpper =
    Table.TransformColumnNames(
        REDISTRIBUICAO_AUSENCIAS_PRODUTO_B_SPO,
        each Text.Upper(Text.Trim(_))
    ),

REDIST_FIX =
    Table.RenameColumns(
        DistColsUpper,
        {{"ORIGEM","RESPONSAVEL_ORIGINAL"},{"SUBS","RESPONSAVEL_SUBSTITUTO"},{"SUBST","RESPONSAVEL_SUBSTITUTO"}},
        MissingField.Ignore
    ),

REDIST_KEEP =
    Table.SelectColumns(
        REDIST_FIX,
        {"RESPONSAVEL_ORIGINAL","RESPONSAVEL_SUBSTITUTO","PESO"},
        MissingField.Ignore
    ),

REDIST_CLEAN =
    Table.SelectRows(
        Table.TransformColumns(
            REDIST_KEEP,
            {
                {"RESPONSAVEL_ORIGINAL", each try Text.Trim(Text.From(_)) otherwise null, type text},
                {"RESPONSAVEL_SUBSTITUTO", each try Text.Trim(Text.From(_)) otherwise null, type text},
                {"PESO", each try Number.From(_) otherwise null, Int64.Type}
            }
        ),
        each [RESPONSAVEL_ORIGINAL] <> null and [RESPONSAVEL_ORIGINAL] <> ""
          and [RESPONSAVEL_SUBSTITUTO] <> null and [RESPONSAVEL_SUBSTITUTO] <> ""
          and [PESO] <> null and [PESO] > 0
    ),

HasAllCols =
    List.AllTrue(
        List.Transform(
            {"RESPONSAVEL_ORIGINAL","RESPONSAVEL_SUBSTITUTO","PESO"},
            each List.Contains(Table.ColumnNames(REDIST_CLEAN), _)
        )
    ),

// ==== RESPONSAVEL_REDIS ====
AddREDIS =
    Table.AddColumn(
        AddBaseRedis,
        "RESPONSAVEL_REDIS",
        each
            try
                let
                    bRaw = try [RESPONSAVEL_BASE_REDIS] otherwise "",
                    b = fxTrimAll(bRaw),
                    pol = fxTrimAll(try [ID_PROPOSTA] otherwise "")
                in
                    if b <> "" and HasAllCols
                    then fxTrimAll(try fxPickWeighted(b, pol, REDIST_CLEAN) otherwise null)
                    else null
            otherwise null,
        type text
    ),

// ==== RESPONSAVEL_FINAL ====
AddFinal =
    Table.AddColumn(
        AddREDIS,
        "RESPONSAVEL_FINAL",
        each
            try
                let
                    red = SafeText(try [RESPONSAVEL_REDIS] otherwise null),
                    adj = SafeText(try [RESPONSAVEL_AJUSTADO] otherwise null),
                    map = SafeText(try [RESPONSAVEL_MAP] otherwise null),
                    usr = SafeText(try [USUARIO_ORIGEM] otherwise null),
                    fil = SafeText(try [UNIDADE] otherwise null),
                    pol = SafeText(try [ID_PROPOSTA] otherwise null),
                    mapLookup = SafeText(try GetMapForUnidade(fil) otherwise null),
                    atribLookup = SafeText(try GetAtribForProposta(pol) otherwise null),
                    pick =
                        if red <> null and red <> "" then red
                        else if adj <> null and adj <> "" then adj
                        else if map <> null and map <> "" then map
                        else if usr <> null and usr <> "" and not IsUserLogin(usr) then usr
                        else if mapLookup <> null and mapLookup <> "" then mapLookup
                        else if atribLookup <> null and atribLookup <> "" then atribLookup
                        else GLOBAL_PADRAO
                in
                    pick
            otherwise GLOBAL_PADRAO,
        type text
    ),
    // 0.1) Se a base tiver coluna ELEGIVEL e não estiver filtrada, filtra agora
BaseFatoForJoin =
    let
        t = AddFinal
    in
        if Table.HasColumns(t, {"ELEGIVEL"})
           then Table.SelectRows(t, each [ELEGIVEL] = "Manter")
           else t,

// 1) Função para normalizar a chave ID_PROPOSTA (trim + upper + remove invisíveis)
NormalizeKey = (t as table, col as text) as table =>
    Table.TransformColumns(
        t,
        {
            { col,
              each Text.Upper(
                     fxTrimAll(
                       Text.Select( try Text.From(_) otherwise "", {"0".."9","A".."Z","a".."z"})
                     )
                   ),
              type text
            }
        }
    ),

// 2) Normaliza as chaves na base do FATO e no snapshot (ANTERIOR)
Fato_ForJoin_Norm = NormalizeKey(BaseFatoForJoin, "ID_PROPOSTA"),
Snap_Norm         = NormalizeKey(#"SNAPSHOT_HISTORICO_ANTERIOR", "ID_PROPOSTA"),

// 3) Join (LeftOuter) e marca presença sem depender do texto expandido
MergeAntD1 =
    Table.NestedJoin(
        Fato_ForJoin_Norm, {"ID_PROPOSTA"},
        Snap_Norm,         {"ID_PROPOSTA"},
        "ANT_D1", JoinKind.LeftOuter
    ),

WithHasAnt =
    Table.AddColumn(
        MergeAntD1, "HAS_ANT",
        each try Table.RowCount([ANT_D1]) > 0 otherwise false,
        type logical
    ),

// 4) Expande as colunas necessárias do snapshot
ExpAntD1 =
    Table.ExpandTableColumn(
        WithHasAnt,
        "ANT_D1",
        {"RESPONSAVEL_ANTERIOR","LB_DATE","DATA_PROPOSTA_TXT"},
        {"RESPONSAVEL_ANTERIOR","LB_DATE","DATA_PROPOSTA_TXT_ANT"}
    ),

// 5) RETORNO com fallback em HAS_ANT (se veio linha no join, não é NOVO)
AddRetorno =
    Table.AddColumn(
        ExpAntD1, "RETORNO",
        each
            let
                antRaw = try [RESPONSAVEL_ANTERIOR] otherwise null,
                finRaw = try [RESPONSAVEL_FINAL]    otherwise null,

                antTx  = Text.Upper(fxTrimAll( try Text.From(antRaw) otherwise "" )),
                finTx  = Text.Upper(fxTrimAll( try Text.From(finRaw) otherwise "" )),
                hasAnt = try [HAS_ANT] otherwise false,

                isNovo =
                    // Se a string do anterior vier vazia mas houve linha no join,
                    // tratamos como "tem anterior" (não é NOVO).
                    if antTx = "" and hasAnt then false else (antTx = "")
            in
                if isNovo then "NOVO"
                else if antTx = finTx then "RETORNO (MESMO SUB)"
                else "RETORNO (OUTRO SUB)",
        type text
    ),

// 6) STATUS_ALOCACAO (mantido, apenas consumindo o RETORNO calculado acima)
AddStatusAlloc =
    Table.AddColumn(
        AddRetorno, "STATUS_ALOCACAO",
        each
            try
                let
                    finalV = try [RESPONSAVEL_FINAL]    otherwise null,
                    redV   = try [RESPONSAVEL_REDIS]    otherwise null,
                    antV   = try [RESPONSAVEL_ANTERIOR] otherwise null,
                    retV   = try [RETORNO]             otherwise null,

                    final = if finalV=null then "" else Text.Trim(Text.From(finalV)),
                    red   = if redV=null   then "" else Text.Trim(Text.From(redV)),
                    ant   = if antV=null   then "" else Text.Trim(Text.From(antV)),
                    ret   = if retV=null   then "" else Text.Upper(Text.Trim(Text.From(retV))),
                    isNovo= ret = "NOVO"
                in
                    if final = red and red <> "" then "REDISTRIBUÍDO (AUSÊNCIAS)"
                    else if ant <> "" and final = ant then "RETORNO (MANTIDO)"
                    else if isNovo then "NOVO"
                    else "DESTINO (SEM AUSÊNCIAS/SEM MUDANÇA)"
            otherwise "DESTINO (SEM AUSÊNCIAS/SEM MUDANÇA)",
        type text
    ),

  // ==== Flags de ausências (anterior/destino) — alinhadas ====
  AddFlagsOut =
    Table.AddColumn(
      Table.AddColumn(AddStatusAlloc, "AUSENCIAS_ANTERIOR",
        each
          try
            let ant = try [RESPONSAVEL_ANTERIOR] otherwise null
            in
              if ant = null or Text.Trim(Text.From(ant)) = "" then false
              else List.Contains(SUBS_AUSENCIAS, fxNormalize(Text.From(ant), true))
          otherwise false,
        type logical
      ),
      "AUSENCIAS_DESTINO",
        each try [DESTINO_EM_AUSENCIAS] otherwise false,
        type logical
    ),

  // ==== Coerções de tipos ====
  DateColsWanted     = {"DATA_PROPOSTA","DATASET_DATE","LB_DATE"},
  ExistingDateCols   = List.Intersect({Table.ColumnNames(AddFlagsOut), DateColsWanted}),
  CoerceDates        = Table.TransformColumns(
                         AddFlagsOut,
                         List.Transform(
                           ExistingDateCols,
                           each {_, each try Date.From(_) otherwise try Date.FromText(_, "pt-BR") otherwise null, type date}
                         )
                       ),

  NumberColsWanted   = {"VALOR_PREMIO","VALOR_PREMIO_LIQUIDO"},
  ExistingNumberCols = List.Intersect({Table.ColumnNames(CoerceDates), NumberColsWanted}),
  CoerceNumbers      = Table.TransformColumns(
                         CoerceDates,
                         List.Transform(
                           ExistingNumberCols,
                           each {_, each try Number.FromText(Text.From(_), "pt-BR") otherwise null, type number}
                         )
                       ),

  ExistingLogicalCols = List.Intersect({Table.ColumnNames(CoerceNumbers), {"DESTINO_EM_AUSENCIAS","AUSENCIAS_ANTERIOR","AUSENCIAS_DESTINO"}}),
  CoerceLogicals      = Table.TransformColumns(
                          CoerceNumbers,
                          List.Transform(
                            ExistingLogicalCols,
                            each {_, each try Logical.From(_) otherwise false, type logical}
                          )
                        ),

  // ==== STATUS_FINAL (usa DESTINO_EM_AUSENCIAS com fallback para AUSENCIAS_DESTINO) ====
  AddStatusFinal =
    Table.AddColumn(
      CoerceLogicals, "STATUS_FINAL",
      each
        try
          let
            antV = try [RESPONSAVEL_ANTERIOR] otherwise null,
            isNova =
              if antV = null then true
              else Text.Trim(Text.From(antV)) = "",

            ajV  = try [RESPONSAVEL_AJUSTADO] otherwise null,
            atribuida = ajV <> null and Text.Trim(Text.From(ajV)) <> "",

            destAus = try [DESTINO_EM_AUSENCIAS] otherwise null,
            finalAus = try [AUSENCIAS_DESTINO]    otherwise null,
            ausencias = (destAus = true) or (finalAus = true)
          in
            if isNova and atribuida and ausencias then "NOVA (ATRIBUÍDA AUSÊNCIAS)"
            else if isNova and atribuida       then "NOVA (ATRIBUÍDA)"
            else if isNova and ausencias          then "NOVA (AUSÊNCIAS)"
            else if isNova                     then "NOVA"
            else if (not isNova) and atribuida and ausencias then "RETORNADA (AUSÊNCIAS ATRIBUÍDA)"
            else if (not isNova) and atribuida           then "RETORNADA (ATRIBUÍDA)"
            else if (not isNova) and ausencias              then "RETORNADA (AUSÊNCIAS)"
            else "RETORNADA"
        otherwise "NOVA",
      type text
    ),

  // ==== Seleção final (mantendo colunas pedidas) ====
  ColsEssenciais = {
    "ID_PROPOSTA","DATASET_DATE","STATUS_FINAL","DATA_PROPOSTA","DATA_PROPOSTA_TXT",
    "UNIDADE","ATIVIDADE",
    "RESPONSAVEL_ANTERIOR","RESPONSAVEL_AJUSTADO","RESPONSAVEL_MAP",
    "RESPONSAVEL_DESTINO","RESPONSAVEL_REDIS","RESPONSAVEL_FINAL",
    "DESTINO_EM_AUSENCIAS","AUSENCIAS_ANTERIOR","AUSENCIAS_DESTINO",
    "FLAG_JANELA","FLAG_PRIORIDADE_A","FLAG_PRIORIDADE_B",
    // Endereço/identificação
    "CEP","ENDERECO","NUMERO","COMPLEMENTO","ID_CLIENTE",
    // Valores
    "VALOR_PREMIO","VALOR_PREMIO_LIQUIDO",
    // Snapshot D-1
    "LB_DATE"
  },
  Minimized = Table.SelectColumns(AddStatusFinal, ColsEssenciais, MissingField.Ignore),

  // ==== Remoção de supérfluas (debug/intermediárias) ====
  ColsRemover = {
    "ELEGIVEL","DBG_DATA_COL","DBG_DATE_SOURCE",
    "RESPONSAVEL_VISUAL","RESPONSAVEL_BASE_REDIS",
    "RETORNO","STATUS_ALOCACAO",
    "DEBUG_DATAS","DESC_CATEGORIA","RESPONSAVEL_DESTINO_NORM"
  },
  SemSuperfluas = Table.RemoveColumns(Minimized, List.Intersect({Table.ColumnNames(Minimized), ColsRemover})),

  Out_FATO =
    Table.ReorderColumns(
      SemSuperfluas,
      {
        "ID_PROPOSTA","DATASET_DATE","STATUS_FINAL","DATA_PROPOSTA","DATA_PROPOSTA_TXT",
        "UNIDADE","ATIVIDADE",
        "RESPONSAVEL_ANTERIOR","RESPONSAVEL_AJUSTADO","RESPONSAVEL_MAP",
        "RESPONSAVEL_DESTINO","RESPONSAVEL_REDIS","RESPONSAVEL_FINAL",
        "DESTINO_EM_AUSENCIAS","AUSENCIAS_ANTERIOR","AUSENCIAS_DESTINO",
        "FLAG_JANELA","FLAG_PRIORIDADE_A","FLAG_PRIORIDADE_B",
        "CEP","ENDERECO","NUMERO","COMPLEMENTO","ID_CLIENTE",
        "VALOR_PREMIO","VALOR_PREMIO_LIQUIDO",
        "LB_DATE"
      },
      MissingField.Ignore
    ),
    #"Colunas Renomeadas" = Table.RenameColumns(Out_FATO,{{"ID_CLIENTE", "ID_CLIENTE"}})
in
    #"Colunas Renomeadas"
