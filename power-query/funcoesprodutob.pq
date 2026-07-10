// =====================================================
// Query 1: Registro de funções compartilhadas - Produto B
// =====================================================
let
  // ======= Parâmetros =======
  Site = "https://tenant.sharepoint.com/sites/projeto",

  // ======= Funções utilitárias =======
  fxTrimAll = (s as any) as text =>
    let t = try Text.From(s) otherwise "", u = Text.Trim(t) in u,

  fxNormalize = (s as nullable text, optional removeDiacritics as nullable logical) as text =>
    let
      base = Text.Upper(fxTrimAll(s)),
      repl = {
        {"Á","A"},{"À","A"},{"Â","A"},{"Ã","A"},{"Ä","A"},{"á","a"},{"à","a"},{"â","a"},{"ã","a"},{"ä","a"},
        {"É","E"},{"È","E"},{"Ê","E"},{"Ë","E"},{"é","e"},{"è","e"},{"ê","e"},{"ë","e"},
        {"Í","I"},{"Ì","I"},{"Î","I"},{"Ï","I"},{"í","i"},{"ì","i"},{"î","i"},{"ï","i"},
        {"Ó","O"},{"Ò","O"},{"Ô","O"},{"Õ","O"},{"Ö","O"},{"ó","o"},{"ò","o"},{"ô","o"},{"õ","o"},{"ö","o"},
        {"Ú","U"},{"Ù","U"},{"Û","U"},{"Ü","U"},{"ú","u"},{"ù","u"},{"û","u"},{"ü","u"},
        {"Ç","C"},{"ç","c"},{"Ñ","N"},{"ñ","n"}
      },
      out =
        if removeDiacritics=null or removeDiacritics=false then base
        else List.Accumulate(repl, base, (st,pair)=> Text.Replace(st, pair{0}, pair{1}))
    in
      out,

  fxBlankLike = (s as any) as logical =>
    let t = fxTrimAll(s) in (t = null or t = ""),

  fxToDate = (v as any) as nullable date =>
    let
      try1 = try Date.From(v) otherwise null,
      try2 = if try1=null then try Date.FromText(Text.From(v), "pt-BR") otherwise null else null,
      txt  = Text.Select(Text.From(v), {"0".."9"}),
      try3 =
        if try1=null and try2=null and Text.Length(txt)=8 then
          let y = Number.FromText(Text.Start(txt,4)),
              m = Number.FromText(Text.Range(txt,4,2)),
              d = Number.FromText(Text.Range(txt,6,2))
          in  try #date(y,m,d) otherwise null
        else null,
      out  = if try1<>null then try1 else if try2<>null then try2 else try3
    in
      out,

  fxCleanUnidade = (s as nullable text) as nullable text =>
    let t = fxTrimAll(s),
        oneSpace = Text.Combine(List.Select(Text.SplitAny(t," "), each _<>""), " "),
        dashPad  = Text.Replace(Text.Replace(oneSpace," - ","-"), "-", " - ")
    in  dashPad,

  fxReadMetaKV_Bin = (bin as binary) as record =>
    let
      lines = Lines.FromBinary(bin),
      kv    = List.Transform(List.Select(lines, each Text.Contains(_, "=")),
               each let p = Text.PositionOf(_, "="),
                        k = Text.Trim(Text.Start(_, p)),
                        v = Text.Trim(Text.Range(_, p+1))
                    in  [K=k,V=v]),
      keys  = List.Transform(kv, each _[K]),
      vals  = List.Transform(kv, each _[V]),
      rec   = if List.Count(kv)>0 then Record.FromList(vals, keys) else []
    in  rec,

  fxSPFileBin = (subfolder as text, filename as text) as nullable binary =>
    let
      Root = SharePoint.Contents(Site, [ApiVersion=15]),
      Lib  = Root{[Name="Shared Documents"]}[Content],
      Dist = Lib{[Name="Distribuicao Produto B"]}[Content],
      // subfolder: "TXT_PRODUTO_B", "ATRIBUIR_PROPOSTA", "AUSENCIAS", "UNIDADE_RESPONSAVEL"
      Folder = Dist{[Name=subfolder]}[Content],
      Row    = Table.SelectRows(Folder, each [Name] = filename),
      Bin    = if Table.RowCount(Row)>0 then Row{0}[Content] else null
    in
      Bin,

  // Função de redistribuição por pesos, com bucket determinístico 0..99
  fxPickWeighted = (original as text, key as any, distTable as table) as nullable text =>
    let
      norm   = (s as text) => fxNormalize(s, true),
      origN  = norm(original),
      prep   = Table.AddColumn(distTable, "ORIGINAL_NORM", each norm([RESPONSAVEL_ORIGINAL]), type text),
      base   = Table.SelectRows(prep, each [ORIGINAL_NORM] = origN),
      clean  = Table.TransformColumns(Table.SelectColumns(base, {"RESPONSAVEL_SUBSTITUTO","PESO"}),
                 {{"PESO", each try Number.From(_) otherwise null, Int64.Type}}),
      valid  = Table.SelectRows(clean, each [RESPONSAVEL_SUBSTITUTO]<>null and [PESO]<>null and [PESO] > 0),
      chosenIfEmpty = if Table.RowCount(valid)=0 then null else "go",
      ordered= if chosenIfEmpty=null then valid else Table.Sort(valid, {{"RESPONSAVEL_SUBSTITUTO", Order.Ascending}}),
      sumW   = List.Sum(ordered[PESO]),
      alloc0 = Table.AddColumn(ordered, "ALLOC", each Number.IntegerDivide([PESO]*100, sumW), Int64.Type),
      floorSum = List.Sum(alloc0[ALLOC]),
      rest   = 100 - floorSum,
      withIx = Table.AddIndexColumn(alloc0, "IDX", 0, 1, Int64.Type),
      alloc2 = Table.AddColumn(withIx, "ALLOC2", each [ALLOC] + (if [IDX] < rest then 1 else 0), Int64.Type),
      fromC  = Table.AddColumn(alloc2, "FROM", each if [IDX]=0 then 0 else List.Sum(List.FirstN(alloc2[ALLOC2],[IDX])), Int64.Type),
      toC    = Table.AddColumn(fromC, "TO",   each [FROM] + [ALLOC2], Int64.Type),
      ktxt   = Text.From(key),
      codes  = List.Transform(Text.ToList(ktxt), each Character.ToNumber(_)),
      h      = List.Accumulate(codes, 5381, (acc,c)=> Number.Mod(acc*33 + c, 2147483647)),
      bucket = Number.Mod(h, 100),
      pick   = Table.SelectRows(toC, each bucket >= [FROM] and bucket < [TO]),
      chosen = if Table.RowCount(pick)=0 then null else pick{0}[RESPONSAVEL_SUBSTITUTO]
    in
      chosen,

  Funcoes = [
    fxTrimAll        = fxTrimAll,
    fxNormalize      = fxNormalize,
    fxBlankLike      = fxBlankLike,
    fxToDate         = fxToDate,
    fxCleanUnidade   = fxCleanUnidade,
    fxReadMetaKV_Bin = fxReadMetaKV_Bin,
    fxSPFileBin      = fxSPFileBin,
    fxPickWeighted   = fxPickWeighted
  ]
in
  Funcoes


// =====================================================
// Query 2: fxExtractDateFromFileName
// Extrai data a partir de padrão de arquivo yyMMdd em posições fixas
// =====================================================
(fileName as nullable text) as nullable date =>
let
    y = try 2000 + Number.FromText(Text.Range(fileName, 12, 2)) otherwise null,
    m = try Number.FromText(Text.Range(fileName, 14, 2)) otherwise null,
    d = try Number.FromText(Text.Range(fileName, 16, 2)) otherwise null,
    result =
        if fileName <> null
           and Text.Length(fileName) >= 18
           and y <> null and m <> null and d <> null
           and m >= 1 and m <= 12 and d >= 1 and d <= 31
        then #date(y, m, d)
        else null
in
    result


// =====================================================
// Query 3: fxPickWeighted
// Seleção determinística por pesos
// =====================================================
(original as text, key as any, distTable as table) as nullable text =>
let
    ReplaceList = {
        {"Á","A"},{"À","A"},{"Â","A"},{"Ã","A"},{"Ä","A"},{"á","a"},{"à","a"},{"â","a"},{"ã","a"},{"ä","a"},
        {"É","E"},{"È","E"},{"Ê","E"},{"Ë","E"},{"é","e"},{"è","e"},{"ê","e"},{"ë","e"},
        {"Í","I"},{"Ì","I"},{"Î","I"},{"Ï","I"},{"í","i"},{"ì","i"},{"î","i"},{"ï","i"},
        {"Ó","O"},{"Ò","O"},{"Ô","O"},{"Õ","O"},{"Ö","O"},{"ó","o"},{"ò","o"},{"ô","o"},{"õ","o"},{"ö","o"},
        {"Ú","U"},{"Ù","U"},{"Û","U"},{"Ü","U"},{"ú","u"},{"ù","u"},{"û","u"},{"ü","u"},
        {"Ç","C"},{"ç","c"},{"Ñ","N"},{"ñ","n"}
    },
    fxNormalize = (s as nullable text, optional removeDiacritics as nullable logical) as text =>
        let
            base = if s=null then "" else Text.Trim(Text.Upper(Text.From(s))),
            out  = if (removeDiacritics=null or removeDiacritics=false)
                   then base
                   else List.Accumulate(ReplaceList, base, (state, pair) => Text.Replace(state, pair{0}, pair{1}))
        in  out,
    _removeAccentsForMatch = true,

    ktxt   = Text.From(key),
    codes  = List.Transform(Text.ToList(ktxt), each Character.ToNumber(_)),
    hash32 = List.Accumulate(codes, 5381, (h, c) => Number.Mod(h * 33 + c, 2147483647)),
    bucket = Number.Mod(hash32, 100),

    originalNorm = fxNormalize(original, _removeAccentsForMatch),
    DistPrep = Table.AddColumn(distTable, "ORIGINAL_NORM", each fxNormalize([RESPONSAVEL_ORIGINAL], _removeAccentsForMatch), type text),
    T0 = Table.SelectRows(DistPrep, each [ORIGINAL_NORM] = originalNorm),
    BaseCols = Table.SelectColumns(T0, {"RESPONSAVEL_SUBSTITUTO","PESO"}),

    ToNum = Table.TransformColumns(BaseCols, {{"PESO", each try Number.From(_) otherwise null, Int64.Type}}),
    Clean = Table.SelectRows(ToNum, each [RESPONSAVEL_SUBSTITUTO]<>null and [PESO]<>null and [PESO] > 0),
    chosenIfEmpty = if Table.RowCount(Clean)=0 then null else "continue",

    Ordered = if chosenIfEmpty=null then Clean else Table.Sort(Clean, {{"RESPONSAVEL_SUBSTITUTO", Order.Ascending}}),

    sumW     = List.Sum(Ordered[PESO]),
    Alloc0   = Table.AddColumn(Ordered, "ALLOC", each Number.IntegerDivide([PESO]*100, sumW), Int64.Type),
    floorSum = List.Sum(Alloc0[ALLOC]),
    rest     = 100 - floorSum,

    WithIdx  = Table.AddIndexColumn(Alloc0, "IDX", 0, 1, Int64.Type),
    AllocAdj = Table.AddColumn(WithIdx, "ALLOC2", each [ALLOC] + (if [IDX] < rest then 1 else 0), Int64.Type),

    FromCol = Table.AddColumn(AllocAdj, "FROM", each if [IDX]=0 then 0 else List.Sum(List.FirstN(AllocAdj[ALLOC2],[IDX])), Int64.Type),
    ToCol   = Table.AddColumn(FromCol, "TO",   each [FROM] + [ALLOC2], Int64.Type),

    Pick   = Table.SelectRows(ToCol, each bucket >= [FROM] and bucket < [TO]),
    chosen = if Table.RowCount(Pick)=0 then null else Pick{0}[RESPONSAVEL_SUBSTITUTO]
in
    chosen


// =====================================================
// Query 4: fxReadMetaKV
// Lê arquivo meta no formato key=value e retorna um record
// =====================================================
(metaPath as text) as record =>
let
    bin   = try File.Contents(metaPath) otherwise null,
    rec   =
        if bin = null then
            []
        else
            let
                lines = Lines.FromBinary(bin),
                kv    = List.Transform(
                            List.Select(lines, each Text.Contains(_, "=")),
                            each
                                let
                                    p = Text.PositionOf(_, "="),
                                    k = Text.Trim(Text.Start(_, p)),
                                    v = Text.Trim(Text.Range(_, p + 1))
                                in  [K=k, V=v]
                        ),
                keys  = List.Transform(kv, each _[K]),
                vals  = List.Transform(kv, each _[V]),
                r     = if List.Count(kv) > 0 then Record.FromList(vals, keys) else []
            in
                r
in
    rec


// =====================================================
// Query 5: fxFridayOfWeek
// Retorna a sexta-feira da semana da data informada
// =====================================================
(date as date) as date =>
let
    wd = Date.DayOfWeek(date, Day.Monday),
    friday = Date.AddDays(date, 5 - (wd + 1))
in
    friday
