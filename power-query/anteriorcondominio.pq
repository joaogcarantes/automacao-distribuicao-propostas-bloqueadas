let
  // ===== Funções utilitárias compartilhadas =====
  fxSPFileBin      = FUNCOES_COMPARTILHADAS[fxSPFileBin],
  fxReadMetaKV_Bin = FUNCOES_COMPARTILHADAS[fxReadMetaKV_Bin],
  fxTrimAll        = FUNCOES_COMPARTILHADAS[fxTrimAll],
  fxNormalize      = FUNCOES_COMPARTILHADAS[fxNormalize],
  fxToDate         = FUNCOES_COMPARTILHADAS[fxToDate],
  fxCleanUnidade   = FUNCOES_COMPARTILHADAS[fxCleanUnidade],

  // ===== Helpers =====
  PickFirstExisting = (cols as list, candidates as list) as nullable text =>
    let hit = List.Intersect({cols, candidates}) in if List.Count(hit)>0 then hit{0} else null,

  IsUserLogin = (t as nullable text) as logical =>
    let s = fxTrimAll(try Text.Upper(Text.From(t)) otherwise "") in s<>"" and (Text.StartsWith(s, "SYS_A") or Text.StartsWith(s, "SYS_B")),

  // ===== TXT ANTERIOR =====
  Bin_Ant   = fxSPFileBin("TXT_PRODUTO_B", "ARQUIVO_PRODUTO_B_ANTERIOR.txt"),
  TXT_src   = if Bin_Ant <> null
              then Csv.Document(
                     Bin_Ant,
                     [Delimiter=";", Columns=58, Encoding=1252,
                      CsvStyle=CsvStyle.QuoteAfterDelimiter, QuoteStyle=QuoteStyle.Csv,
                      ExtraValues=ExtraValues.Ignore]
                   )
              else #table({"Column1"}, {}),
  TXT_typ   = Table.TransformColumnTypes(TXT_src, List.Transform({1..58}, each {"Column" & Text.From(_), type text})),
  TXT_hdr   = Table.PromoteHeaders(TXT_typ, [PromoteAllScalars=true]),

  // ===== META ANTERIOR → LB_DATE (D-1) com múltiplos fallbacks =====
  Bin_MetaAnt = fxSPFileBin("TXT_PRODUTO_B", "ARQUIVO_PRODUTO_B_ANTERIOR_META.txt"),
  MetaRec     = fxReadMetaKV_Bin(Bin_MetaAnt),

  D1Txt = try Text.From(Record.Field(MetaRec, "ReferenceD1SourceDate")) otherwise null,
  D2Txt = try Text.From(Record.Field(MetaRec, "SourceDate"))            otherwise null,

  DataCol_ANT  = PickFirstExisting(
                   Table.ColumnNames(TXT_hdr),
                   {
                     "DATA_TRANS","DATA TRANS","DATATRANS","DATA","DATA_PROPOSTA","DATA DA PROPOSTA","DT_PROPOSTA",
                     "DT TRANS","DT_TRANS","DT_TRANSACAO","DT TRANSACAO","DATA TRANSACAO","DATA DA TRANSACAO"
                   }
                 ),
  ANT_withData = if DataCol_ANT<>null
                 then Table.AddColumn(TXT_hdr, "_DATA_", each fxToDate(Record.Field(_, DataCol_ANT)), type date)
                 else TXT_hdr,
  MaxD2        = if DataCol_ANT<>null
                 then let vals = List.RemoveNulls(ANT_withData[_DATA_]) in if List.Count(vals)>0 then List.Max(vals) else null
                 else null,

  LB_DATE =
    let
      d1 = try Date.FromText(D1Txt) otherwise null,
      d2 = try Date.FromText(D2Txt) otherwise null
    in
      if d1 <> null then d1
      else if d2 <> null then Date.AddDays(d2, 1)
      else if MaxD2 <> null then Date.AddDays(MaxD2, 1)
      else Date.AddDays(Date.From(DateTime.LocalNow()), -1),

  // ===== Base mínima + data/unidade =====
  Ant_MustHave = List.RemoveNulls({"ID_PROPOSTA","USUARIO_ORIGEM","UNIDADE","FLAG_JANELA","FLAG_PRIORIDADE_A","FLAG_PRIORIDADE_B","VALOR_PREMIO_LIQUIDO","DESC_CATEGORIA", DataCol_ANT}),
  Ant_sel      = Table.SelectColumns(ANT_withData, List.Union({{"ID_PROPOSTA"}, Ant_MustHave}), MissingField.Ignore),

  Ant_dt       = if DataCol_ANT<>null
                 then Table.AddColumn(Ant_sel,"DATA_PROPOSTA", each fxToDate(Record.Field(_, DataCol_ANT)), type date)
                 else Table.AddColumn(Ant_sel,"DATA_PROPOSTA", each null, type date),

  // Limpeza de unidade e inclusão de DATA_PROPOSTA_TXT para auditoria
  Ant_fil      = Table.TransformColumns(Ant_dt, {{"UNIDADE", each try fxCleanUnidade(_) otherwise null, type text}}),
  Ant_dttxt    = Table.AddColumn(
                   Ant_fil, "DATA_PROPOSTA_TXT",
                   each if [DATA_PROPOSTA] = null then null else Date.ToText([DATA_PROPOSTA], "dd/MM/yyyy","pt-BR"),
                   type text
                 ),

  // ===== Auxiliares com buffer: atribuição manual + mapa por unidade =====
  AtribBuf   = Table.Buffer(ATRIBUIR_PROPOSTA_UNICA),
  UnidadeBuf = Table.Buffer(UNIDADE_RESPONSAVEL_SPO),

  MAP_cols  = Table.TransformColumnNames(UnidadeBuf, each Text.Trim(Text.Replace(_, "  ", " "))),
  MAP_clean = Table.TransformColumns(
                MAP_cols,
                {{"UNIDADE", each fxCleanUnidade(_), type text}, {"RESPONSAVEL", each fxTrimAll(_), type text}}
              ),
  MAP_idx   = Table.AddIndexColumn(MAP_clean, "_IDX", 1, 1, Int64.Type),
  MAP_sort  = Table.Sort(MAP_idx, {{"_IDX", Order.Ascending}}),
  MAP_unica = Table.Group(MAP_sort, {"UNIDADE"}, {{"RESPONSAVEL", each List.Last([RESPONSAVEL]), type text}}),
  GLOBAL_PADRAO =
    let lst = List.RemoveNulls(MAP_sort[RESPONSAVEL]) in if List.Count(lst)>0 then fxTrimAll(List.Last(lst)) else "RESPONSAVEL_PADRAO",

  // ===== Atribuição manual por proposta + mapa unidade → responsável =====
  MergeAtrib   = Table.NestedJoin(Ant_dttxt, {"ID_PROPOSTA"}, AtribBuf, {"ID_PROPOSTA"}, "ATRIB", JoinKind.LeftOuter),
  ExpAtrib     = Table.ExpandTableColumn(MergeAtrib, "ATRIB", {"RESPONSAVEL_AJUSTADO"}),

  Ant_mergeMap = Table.NestedJoin(ExpAtrib, {"UNIDADE"}, MAP_unica, {"UNIDADE"}, "MAP", JoinKind.LeftOuter),
  Ant_expMap   = Table.ExpandTableColumn(Ant_mergeMap, "MAP", {"RESPONSAVEL"}, {"RESPONSAVEL_MAP"}),

  // ===== Proteção: só transformar colunas se existirem =====
  HasAjustado  = List.Contains(Table.ColumnNames(Ant_expMap), "RESPONSAVEL_AJUSTADO"),
  HasMap       = List.Contains(Table.ColumnNames(Ant_expMap), "RESPONSAVEL_MAP"),

  SafeCols_ANT =
    let
      T0 = if HasAjustado
           then Table.TransformColumns(
                  Ant_expMap,
                  {{"RESPONSAVEL_AJUSTADO", each try Text.From(_) otherwise null, type text}}
                )
           else Ant_expMap,
      T1 = if HasMap
           then Table.TransformColumns(
                  T0,
                  {{"RESPONSAVEL_MAP", each try Text.From(_) otherwise null, type text}}
                )
           else T0
    in
      T1,

  // ===== Lookups auxiliares: relookup MAP por unidade; lookup ATRIB por proposta =====
  GetMapForUnidade = (und as any) as nullable text =>
    let u = fxCleanUnidade(und),
        r = try Table.SelectRows(MAP_unica, (x)=> x[UNIDADE] = u){0}[RESPONSAVEL] otherwise null
    in fxTrimAll(try Text.From(r) otherwise null),

  GetAtribForProposta = (id as any) as nullable text =>
    let p = fxTrimAll(Text.From(id)),
        r = try Table.SelectRows(AtribBuf, (x)=> fxTrimAll(Text.From(x[ID_PROPOSTA])) = p){0}[RESPONSAVEL_AJUSTADO] otherwise null
    in fxTrimAll(try Text.From(r) otherwise null),

  // ===== RESPONSAVEL_ANTERIOR = AJUSTADO → MAP(merge) → USUARIO(!prefixos técnicos) → MAP(relookup) → ATRIBUIR(proposta) → GLOBAL_PADRAO =====
  Ant_destino  =
    Table.AddColumn(
      SafeCols_ANT, "RESPONSAVEL_ANTERIOR",
      each
        let
          adjRaw = try [RESPONSAVEL_AJUSTADO] otherwise null,
          mapRaw = try [RESPONSAVEL_MAP]      otherwise null,
          usrRaw = try [USUARIO_ORIGEM]       otherwise null,
          undRaw = try [UNIDADE]              otherwise null,
          idRaw  = try [ID_PROPOSTA]          otherwise null,

          adj = fxTrimAll( if adjRaw=null then "" else adjRaw ),
          map = fxTrimAll( if mapRaw=null then "" else mapRaw ),
          usr = fxTrimAll( if usrRaw=null then "" else usrRaw ),
          und = fxCleanUnidade( undRaw ),
          idp = fxTrimAll( Text.From(idRaw) ),

          mapLookup   = fxTrimAll(try GetMapForUnidade(und)    otherwise ""),
          atribLookup = fxTrimAll(try GetAtribForProposta(idp) otherwise ""),

          pick =
            if adj<>"" then adj
            else if map<>"" then map
            else if usr<>"" and not IsUserLogin(usr) then usr
            else if mapLookup<>"" then mapLookup
            else if atribLookup<>"" then atribLookup
            else GLOBAL_PADRAO
        in
          pick,
      type text
    ),

  // ===== PATCH strict+1: FLAG_JANELA entra se DATA_PROPOSTA for último OU penúltimo dia da janela =====
  normSN = (x as any) as text =>
    let
      t0 = try Text.From(x) otherwise "",
      t1 = Text.Select(t0, {"A".."Z","a".."z","0".."9"}),
      up = Text.Upper(fxTrimAll(t1))
    in up,

  Ant_eleg =
    Table.AddColumn(
      Table.AddColumn(Ant_destino, "LB_DATE", each LB_DATE, type date),
      "ELEGIVEL",
      (r)=>
        let
          refDate  = r[LB_DATE],
          winEnd   = if refDate=null then null else Date.AddDays(refDate, -12),
          isPriorA = normSN(r[#"FLAG_PRIORIDADE_A"]) = "S",
          isPriorB = normSN(r[#"FLAG_PRIORIDADE_B"]) = "S",
          isJanela = normSN(r[#"FLAG_JANELA"      ]) = "S",
          isPrior  = isPriorA or isPriorB,
          dt       = try Date.From(r[DATA_PROPOSTA]) otherwise null,
          isLast   = isJanela and (dt <> null) and (winEnd <> null) and (dt = winEnd),
          isPenUlt = isJanela and (dt <> null) and (winEnd <> null) and (dt = Date.AddDays(winEnd, -1))
        in
          if isPrior or isLast or isPenUlt then "Manter" else "Excluir",
      type text
    ),

  // ===== Snapshot D-1, uma linha por proposta, com colunas extras para auditoria =====
  Ant_normId =
    Table.TransformColumns(
      Table.SelectRows(Ant_eleg, each [ELEGIVEL] = "Manter"),
      {{"ID_PROPOSTA", each if _=null then null else fxTrimAll(Text.From(_)), type text}}
    ),

  Out =
    Table.Group(
      Table.SelectColumns(
        Ant_normId,
        {
          "ID_PROPOSTA","RESPONSAVEL_ANTERIOR","LB_DATE",
          // Auditoria:
          "DATA_PROPOSTA_TXT","UNIDADE","FLAG_JANELA","FLAG_PRIORIDADE_A","FLAG_PRIORIDADE_B"
        }
      ),
      {"ID_PROPOSTA"},
      {
        {"RESPONSAVEL_ANTERIOR", each List.First([RESPONSAVEL_ANTERIOR]), type text},
        {"LB_DATE",              each List.First([LB_DATE]),              type date},
        {"DATA_PROPOSTA_TXT",    each List.First([DATA_PROPOSTA_TXT]),    type text},
        {"UNIDADE",              each List.First([UNIDADE]),              type text},
        {"FLAG_JANELA",          each List.First([#"FLAG_JANELA"]),       type text},
        {"FLAG_PRIORIDADE_A",    each List.First([#"FLAG_PRIORIDADE_A"]), type text},
        {"FLAG_PRIORIDADE_B",    each List.First([#"FLAG_PRIORIDADE_B"]), type text}
      }
    ),
    #"Colunas Reordenadas" = Table.ReorderColumns(Out,{"ID_PROPOSTA", "RESPONSAVEL_ANTERIOR", "DATA_PROPOSTA_TXT", "UNIDADE", "FLAG_JANELA", "FLAG_PRIORIDADE_A", "FLAG_PRIORIDADE_B", "LB_DATE"})
in
    #"Colunas Reordenadas"
