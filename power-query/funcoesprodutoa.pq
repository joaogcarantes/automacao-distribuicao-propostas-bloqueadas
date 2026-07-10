// =====================================================
// Query 1: Registro de funções compartilhadas do projeto
// =====================================================
let
    FUNCOES_COMPARTILHADAS = let
    // ---- Navegação leve no SharePoint ----
    SP_Site = "https://tenant.sharepoint.com/sites/projeto",
    SP_Root = SharePoint.Contents(SP_Site, [ApiVersion=15]),
    SP_Lib  = SP_Root{[Name="Shared Documents"]}[Content],
    SP_Auto = SP_Lib{[Name="Automacao Produto A"]}[Content],

    fxSPFolder = (folderName as text) as table =>
        let out = try SP_Auto{[Name=folderName]}[Content] otherwise #table({}, {}) in out,

    fxSPFileRow = (folderName as text, fileName as text) as record =>
        let folder = fxSPFolder(folderName),
            row    = try Table.SelectRows(folder, each [Name] = fileName){0} otherwise null in row,

    fxSPFileBin = (folderName as text, fileName as text) as nullable binary =>
        let row = fxSPFileRow(folderName, fileName),
            bin = if row <> null then row[Content] else null in bin,

    // ---- Utilitários genéricos ----
    ReplaceList = {
        {"Á","A"},{"À","A"},{"Â","A"},{"Ã","A"},{"Ä","A"},{"á","a"},{"à","a"},{"â","a"},{"ã","a"},{"ä","a"},
        {"É","E"},{"È","E"},{"Ê","E"},{"Ë","E"},{"é","e"},{"è","e"},{"ê","e"},{"ë","e"},
        {"Í","I"},{"Ì","I"},{"Î","I"},{"Ï","I"},{"í","i"},{"ì","i"},{"î","i"},{"ï","i"},
        {"Ó","O"},{"Ò","O"},{"Ô","O"},{"Õ","O"},{"Ö","O"},{"ó","o"},{"ò","o"},{"ô","o"},{"õ","o"},{"ö","o"},
        {"Ú","U"},{"Ù","U"},{"Û","U"},{"Ü","U"},{"ú","u"},{"ù","u"},{"û","u"},{"ü","u"},
        {"Ç","C"},{"ç","c"},{"Ñ","N"},{"ñ","n"}
    },

    fxTrimAll = (s as nullable text) as text =>
        let t0 = if s=null then "" else Text.From(s),
            r1 = Text.Replace(t0, Character.FromNumber(160), " "),
            r2 = Text.Replace(r1, Character.FromNumber(9), " "),
            r3 = Text.Replace(r2, Character.FromNumber(10), " "),
            r4 = Text.Replace(r3, Character.FromNumber(13), " "),
            r5 = Text.Replace(r4, Character.FromNumber(8232), " "),
            r6 = Text.Replace(r5, Character.FromNumber(8233), " "),
            r7 = Text.Replace(r6, Character.FromNumber(8203), ""),
            r8 = Text.Replace(r7, Character.FromNumber(65279), ""),
            out = Text.Trim(r8)
        in out,

    fxNormalize = (s as nullable text, optional removeDiacritics as nullable logical) as text =>
        let base = if s=null then "" else Text.Trim(Text.Upper(Text.From(s))),
            out  = if (removeDiacritics=null or removeDiacritics=false)
                   then base
                   else List.Accumulate(ReplaceList, base, (state, pair) => Text.Replace(state, pair{0}, pair{1}))
        in  out,

    fxBlankLike = (s as nullable text) as logical =>
        let c = Text.Upper(fxTrimAll(s)),
            lst = {"","N/DA","N.DA","NDA","NA","NULL","-","SEM DADOS"}
        in List.Contains(lst, c),

    fxCleanUnidade = (f as nullable text) as text =>
        let s0 = if f=null then "" else Text.From(f),
            t1 = fxTrimAll(s0),
            h1 = Text.Replace(t1, "–", " - "), h2 = Text.Replace(h1, "—", " - "),
            parts = List.Select(Text.SplitAny(h2, " "), each _ <> ""),
            sps = Text.Combine(parts, " "),
            out = Text.Upper(Text.Trim(sps))
        in out,

    fxPickWeighted = (original as text, key as any, distTable as table) as nullable text =>
        let _rm = true,
            originalNorm = fxNormalize(original, _rm),
            ktxt   = Text.From(key),
            codes  = List.Transform(Text.ToList(ktxt), each Character.ToNumber(_)),
            hash32 = List.Accumulate(codes, 5381, (h, c) => Number.Mod(h * 33 + c, 2147483647)),
            bucket = Number.Mod(hash32, 100),
            DistPrep = Table.AddColumn(distTable, "ORIGINAL_NORM", each fxNormalize([RESPONSAVEL_ORIGINAL], _rm), type text),
            T0   = Table.SelectRows(DistPrep, each [ORIGINAL_NORM] = originalNorm),
            Base = Table.SelectColumns(T0, {"RESPONSAVEL_SUBSTITUTO","PESO"}),
            Num  = Table.TransformColumns(Base, {{"PESO", each try Number.From(_) otherwise null, Int64.Type}}),
            Clean= Table.SelectRows(Num, each [RESPONSAVEL_SUBSTITUTO]<>null and [PESO]<>null and [PESO]>0),
            chosen =
                if Table.RowCount(Clean)=0 then null else
                let Ordered = Table.Sort(Clean, {{"RESPONSAVEL_SUBSTITUTO", Order.Ascending}}),
                    sumW    = List.Sum(Ordered[PESO]),
                    Alloc0  = Table.AddColumn(Ordered, "ALLOC", each Number.IntegerDivide([PESO]*100, sumW), Int64.Type),
                    floor   = List.Sum(Alloc0[ALLOC]),
                    rest    = 100 - floor,
                    WithIdx = Table.AddIndexColumn(Alloc0, "IDX", 0, 1, Int64.Type),
                    Alloc2  = Table.AddColumn(WithIdx, "ALLOC2", each [ALLOC] + (if [IDX] < rest then 1 else 0), Int64.Type),
                    FromCol = Table.AddColumn(Alloc2, "FROM", each if [IDX]=0 then 0 else List.Sum(List.FirstN(Alloc2[ALLOC2],[IDX])), Int64.Type),
                    ToCol   = Table.AddColumn(FromCol, "TO",   each [FROM] + [ALLOC2], Int64.Type),
                    Pick    = Table.SelectRows(ToCol, each bucket >= [FROM] and bucket < [TO])
                in if Table.RowCount(Pick)=0 then null else Pick{0}[RESPONSAVEL_SUBSTITUTO]
        in chosen,

    fxToDate = (v as any) as nullable date =>
        let t0 = if v=null then null else Text.Trim(Text.From(v)),
            out =
                if t0=null or t0="" then null else
                let tryISO = try Date.FromText(t0) otherwise null,
                    tryBR  = try Date.FromText(t0, "pt-BR") otherwise null,
                    rawDigits = Text.Select(t0, {"0".."9"}),
                    lenRaw = Text.Length(rawDigits),
                    digits8 =
                        if lenRaw=9 and Text.Start(rawDigits,1)="0" then Text.Range(rawDigits, 1, 8)
                        else if lenRaw=9 and Text.End(rawDigits,1)="0" then Text.Start(rawDigits, 8)
                        else rawDigits,
                    len8 = Text.Length(digits8)=8,
                    yFirst =
                        if len8 then
                            let y = Number.FromText(Text.Start(digits8,4)),
                                m = Number.FromText(Text.Range(digits8,4,2)),
                                d = Number.FromText(Text.End(digits8,2))
                            in if y>=1900 and y<=2100 then (try #date(y,m,d) otherwise null) else null
                        else null,
                    dFirst =
                        if len8 then
                            let d2 = Number.FromText(Text.Start(digits8,2)),
                                m2 = Number.FromText(Text.Range(digits8,2,2)),
                                y2 = Number.FromText(Text.End(digits8,4))
                            in (try #date(y2,m2,d2) otherwise null)
                        else null
                in if tryISO<>null then tryISO else if tryBR<>null then tryBR else if yFirst<>null then yFirst else dFirst
        in out,

    fxFindCol = (cols as list, aliases as list) as nullable text =>
        let norm = (t as text) as text => fxNormalize(fxTrimAll(Text.Replace(Text.Replace(t,"_"," "),"-"," ")), true),
            colsN = List.Transform(cols, each [Orig=_, Norm=norm(Text.From(_))]),
            aliN  = List.Transform(aliases, each norm(Text.From(_))),
            match = List.First(List.Select(colsN, each List.Contains(aliN, _[Norm])), null)
        in if match<>null then match[Orig] else null,

    fxAsBusinessDay = (d as nullable date) as nullable date =>
        let d1 = d,
            dow = if d1=null then null else Date.DayOfWeek(d1, Day.Monday),
            d2 = if d1=null then null else if dow>=5 then Date.AddDays(d1, 7 - dow) else d1
        in d2,

    fxReadMetaKV_Bin = (bin as nullable binary) as record =>
        let rec = if bin=null then [] else
            let lines = Lines.FromBinary(bin),
                kv    = List.Transform(
                            List.Select(lines, each Text.Contains(_, "=")),
                            each let p = Text.PositionOf(_, "=") in [K=Text.Trim(Text.Start(_, p)), V=Text.Trim(Text.Range(_, p+1))]
                        ),
                keys  = List.Transform(kv, each _[K]),
                vals  = List.Transform(kv, each _[V]),
                r     = if List.Count(kv) > 0 then Record.FromList(vals, keys) else []
            in r
        in rec,

    fxExtractDateFromFileName_Local = (fileName as nullable text) as nullable date =>
        let y = try 2000 + Number.FromText(Text.Range(fileName, 12, 2)) otherwise null,
            m = try Number.FromText(Text.Range(fileName, 14, 2)) otherwise null,
            d = try Number.FromText(Text.Range(fileName, 16, 2)) otherwise null,
            result = if fileName<>null and Text.Length(fileName)>=18 and y<>null and m<>null and d<>null and m>=1 and m<=12 and d>=1 and d<=31
                     then #date(y,m,d) else null
        in result,

    fxSafeToDate = (v as any) as nullable date =>
        let t = try Text.Trim(Text.From(v)) otherwise null,
            out = if t=null or t="" then null else
                    let iso = try Date.FromText(t) otherwise null,
                        br  = try Date.FromText(t, "pt-BR") otherwise null
                    in if iso<>null then iso else br
        in out,

    fxEmptyTableWithCols = (cols as list) as table => #table(cols, {})
in
    [
        SP_Root=SP_Root, SP_Lib=SP_Lib, SP_Auto=SP_Auto,
        fxSPFolder=fxSPFolder, fxSPFileRow=fxSPFileRow, fxSPFileBin=fxSPFileBin,
        fxTrimAll=fxTrimAll, fxNormalize=fxNormalize, fxBlankLike=fxBlankLike,
        fxCleanUnidade=fxCleanUnidade, fxPickWeighted=fxPickWeighted, fxToDate=fxToDate,
        fxFindCol=fxFindCol, fxAsBusinessDay=fxAsBusinessDay,
        fxReadMetaKV_Bin=fxReadMetaKV_Bin, fxExtractDateFromFileName_Local=fxExtractDateFromFileName_Local,
        fxSafeToDate=fxSafeToDate, fxEmptyTableWithCols=fxEmptyTableWithCols
    ]
in
    FUNCOES_COMPARTILHADAS


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
    // ---------- 0) Normalização ----------
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

    // ---------- 1) Bucket DJB2 0..99 ----------
    ktxt   = Text.From(key),
    codes  = List.Transform(Text.ToList(ktxt), each Character.ToNumber(_)),
    hash32 = List.Accumulate(codes, 5381, (h, c) => Number.Mod(h * 33 + c, 2147483647)),
    bucket = Number.Mod(hash32, 100),

    // ---------- 2) Filtra responsável original ----------
    originalNorm = fxNormalize(original, _removeAccentsForMatch),
    DistPrep = Table.AddColumn(distTable, "ORIGINAL_NORM", each fxNormalize([RESPONSAVEL_ORIGINAL], _removeAccentsForMatch), type text),
    T0 = Table.SelectRows(DistPrep, each [ORIGINAL_NORM] = originalNorm),
    BaseCols = Table.SelectColumns(T0, {"RESPONSAVEL_SUBSTITUTO","PESO"}),

    // ---------- 3) Tipos e limpeza ----------
    ToNum = Table.TransformColumns(BaseCols, {{"PESO", each try Number.From(_) otherwise null, Int64.Type}}),
    Clean = Table.SelectRows(ToNum, each [RESPONSAVEL_SUBSTITUTO]<>null and [PESO]<>null and [PESO] > 0),
    chosenIfEmpty = if Table.RowCount(Clean)=0 then null else "continue",

    // ---------- 4) Ordem determinística ----------
    Ordered = if chosenIfEmpty=null then Clean else Table.Sort(Clean, {{"RESPONSAVEL_SUBSTITUTO", Order.Ascending}}),

    // ---------- 5) Alocação inteira (soma 100) ----------
    sumW     = List.Sum(Ordered[PESO]),
    Alloc0   = Table.AddColumn(Ordered, "ALLOC", each Number.IntegerDivide([PESO]*100, sumW), Int64.Type),
    floorSum = List.Sum(Alloc0[ALLOC]),
    rest     = 100 - floorSum,

    WithIdx  = Table.AddIndexColumn(Alloc0, "IDX", 0, 1, Int64.Type),
    AllocAdj = Table.AddColumn(WithIdx, "ALLOC2", each [ALLOC] + (if [IDX] < rest then 1 else 0), Int64.Type),

    // ---------- 6) Intervalos [FROM,TO) inteiros cobrindo 0..99 ----------
    FromCol = Table.AddColumn(AllocAdj, "FROM", each if [IDX]=0 then 0 else List.Sum(List.FirstN(AllocAdj[ALLOC2],[IDX])), Int64.Type),
    ToCol   = Table.AddColumn(FromCol, "TO",   each [FROM] + [ALLOC2], Int64.Type),

    // ---------- 7) Seleção pelo bucket ----------
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
