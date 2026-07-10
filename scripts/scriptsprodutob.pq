# =====================================================
# Script 1: Copiar_Arquivo_Atual_ProdutoB_Share.ps1
# ATUAL (D-1) — Produto B, sem histórico
# =====================================================

param(
    [switch]$StrictYesterday,
    [datetime]$OverrideD1Date
)
$ErrorActionPreference = 'Stop'

function Header-Cyan([string]$title) {
  $line = [string]::new('=', $title.Length)
  Write-Host $line -ForegroundColor Cyan
  Write-Host $title -ForegroundColor Cyan
  Write-Host $line -ForegroundColor Cyan
}

function Ensure-Dir([string]$p) {
  try {
    if (-not [System.IO.Directory]::Exists($p)) {
      [System.IO.Directory]::CreateDirectory($p) | Out-Null
    }
  } catch {
    Write-Host ("AVISO: Não foi possível criar a pasta: {0} — {1}" -f $p, $_.Exception.Message) -ForegroundColor Yellow
  }
}

function Write-MetaFile([string]$Path, [hashtable]$Data) {
  $dir = Split-Path -Path $Path -Parent
  if (-not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
  }
  $lines = foreach ($k in $Data.Keys) { "{0}={1}" -f $k, ($Data[$k]) }
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllLines($Path, $lines, $utf8NoBom)
}

function Update-Atual([IO.FileInfo]$Src, [string]$DestAtual) {
  $destDir = Split-Path -Path $DestAtual -Parent
  Ensure-Dir $destDir
  Copy-Item -LiteralPath $Src.FullName -Destination $DestAtual -Force
}

try {
  $title = " DISTRIBUIDOR DE PROPOSTAS - PRODUTO B"
  Header-Cyan $title

  $ciPT = New-Object System.Globalization.CultureInfo('pt-BR')
  $inpD = Read-Host "Digite a data de negócio (dd/MM/yyyy) [Enter para hoje]"
  if ([string]::IsNullOrWhiteSpace($inpD)) {
    $D = (Get-Date).Date
  } else {
    try { $D = [datetime]::ParseExact($inpD,'dd/MM/yyyy',$ciPT) }
    catch { Write-Host "Data inválida. Use dd/MM/yyyy."; exit 1 }
  }

  if ($PSBoundParameters.ContainsKey('OverrideD1Date') -and $OverrideD1Date) {
    $D1 = $OverrideD1Date.Date
    $mode = 'OverrideFromD1'
  } else {
    $D1 = $D.AddDays(-1)
    if ($StrictYesterday) { $mode = 'ExactFromD1' } else { $mode = 'FallbackFromD1' }
  }

  # ================= RESOLVE CAMINHO LOCAL SINCRONIZADO =================
  $userProfile = $env:USERPROFILE
  $candidates = @(
    (Join-Path $userProfile "Organizacao\Equipe Projeto - Documentos\Distribuicao Produto B\TXT_PRODUTO_B"),
    (Join-Path $userProfile "OneDrive - Organizacao\Equipe Projeto - Documentos\Distribuicao Produto B\TXT_PRODUTO_B"),
    (Join-Path $userProfile "OneDrive - Organizacao\Distribuicao Produto B\TXT_PRODUTO_B"),
    (Join-Path $userProfile "Organizacao\Distribuicao Produto B\TXT_PRODUTO_B"),
    (Join-Path $userProfile "Organizacao\Equipe Projeto - Documents\Distribuicao Produto B\TXT_PRODUTO_B"),
    (Join-Path $userProfile "Organizacao\Equipe Projeto - Distribuicao Produto B\TXT_PRODUTO_B")
  )

  $BaseTxt = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
  if (-not $BaseTxt) {
    Write-Host "FALHA: Pasta sincronizada 'Distribuicao Produto B\TXT_PRODUTO_B' não encontrada no perfil do usuário atual." -ForegroundColor Red
    Write-Host "Abra o SharePoint, sincronize a biblioteca do projeto e aguarde a pasta aparecer no Explorer." -ForegroundColor Yellow
    exit 1
  }

  $Config = @{
    OrigemDir = "\\servidor\area\projeto\origem_produto_b";
    DestAtual = (Join-Path $BaseTxt 'ARQUIVO_PRODUTO_B_ATUAL.txt');
    MetaAtual = (Join-Path $BaseTxt 'ARQUIVO_PRODUTO_B_ATUAL_META.txt')
  }

  $files = Get-ChildItem -LiteralPath $Config.OrigemDir -Filter "ARQUIVO_PRODUTO_B_*" -File
  if (-not $files) { throw "Nenhum arquivo 'ARQUIVO_PRODUTO_B_*' encontrado na origem." }

  $ciInv = [System.Globalization.CultureInfo]::InvariantCulture
  $filesWithDate = foreach ($f in $files) {
    $name = $f.Name
    $m = [regex]::Match($name, '^ARQUIVO_PRODUTO_B_(\d{6})\.txt$', 'IgnoreCase')
    if (-not $m.Success) { $m = [regex]::Match($name, '^ARQUIVO_PRODUTO_B_(\d{6})txt$', 'IgnoreCase') }
    if ($m.Success) {
      $srcDate = [datetime]::ParseExact($m.Groups[1].Value, 'yyMMdd', $ciInv)
      [pscustomobject]@{ File=$f; SourceDate=$srcDate.Date; LastWriteTime=$f.LastWriteTime }
    }
  }

  $pickD1 = $filesWithDate | Where-Object { $_.SourceDate -eq $D1 } | Sort-Object SourceDate -Descending | Select-Object -First 1
  if (-not $pickD1) {
    if ($PSBoundParameters.ContainsKey('OverrideD1Date') -and $OverrideD1Date) {
      throw ("OverrideD1Date {0:yyyy-MM-dd}: arquivo correspondente não encontrado." -f $D1)
    }
    if ($StrictYesterday) {
      throw ("Arquivo D-1 ({0}) não encontrado e StrictYesterday está ativo." -f $D1.ToString('dd/MM/yyyy',$ciPT))
    }
    $pickD1 = $filesWithDate | Where-Object { $_.SourceDate -le $D1 } | Sort-Object SourceDate -Descending | Select-Object -First 1
    if (-not $pickD1) { $pickD1 = $filesWithDate | Sort-Object SourceDate -Descending | Select-Object -First 1 }
  }

  Write-Host ""
  Write-Host ("dia atual:              {0}" -f $D.ToString('dd/MM/yyyy',$ciPT))
  Write-Host ("arquivo utilizado hoje: {0} (data referente ao arquivo: {1})" -f $pickD1.File.Name, $pickD1.SourceDate.ToString('dd/MM/yyyy',$ciPT))

  Update-Atual -Src $pickD1.File -DestAtual $Config.DestAtual

  $meta = @{
    NomeOriginal = $pickD1.File.Name
    SourceDate   = $pickD1.SourceDate.ToString('yyyy-MM-dd')
    WrittenAtUtc = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
    Mode         = $mode
  }
  Write-MetaFile -Path $Config.MetaAtual -Data $meta

  Write-Host ""
  Write-Host "ATUAL.txt gerado com sucesso!" -ForegroundColor Green
}
catch {
  Write-Host ("ERRO: {0}" -f $_.Exception.Message)
  exit 1
}


# =====================================================
# Script 2: Copiar_Arquivo_Historico_ProdutoB_Share.ps1
# ANTERIOR (D-2) — Produto B, sem histórico; log exibe D-1
# =====================================================

<#
OBSERVAÇÃO:
Este segundo script foi mantido no mesmo arquivo para documentação/repositório.
Para execução prática no PowerShell, salve este bloco em arquivo separado, por exemplo:
Copiar_Arquivo_Historico_ProdutoB_Share.ps1.
#>

param(
    [switch]$StrictYesterday,
    [datetime]$OverrideD1Date
)
$ErrorActionPreference = 'Stop'

function Header-Cyan([string]$title) {
  $line = [string]::new('=', $title.Length)
  Write-Host $line -ForegroundColor Cyan
  Write-Host $title -ForegroundColor Cyan
  Write-Host $line -ForegroundColor Cyan
}

function Ensure-Dir([string]$p) {
  try {
    if (-not [System.IO.Directory]::Exists($p)) {
      [System.IO.Directory]::CreateDirectory($p) | Out-Null
    }
  } catch {
    Write-Host ("AVISO: Não foi possível criar a pasta: {0} — {1}" -f $p, $_.Exception.Message) -ForegroundColor Yellow
  }
}

function Write-MetaFile([string]$Path, [hashtable]$Data) {
  $dir = Split-Path -Path $Path -Parent
  if (-not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
  }
  $lines = foreach ($k in $Data.Keys) { "{0}={1}" -f $k, ($Data[$k]) }
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllLines($Path, $lines, $utf8NoBom)
}

function Update-Anterior([IO.FileInfo]$Src, [string]$DestAnterior) {
  $destDir = Split-Path -Path $DestAnterior -Parent
  Ensure-Dir $destDir
  Copy-Item -LiteralPath $Src.FullName -Destination $DestAnterior -Force
}

function Write-Color([string]$Text, [string]$Color) { Write-Host $Text -ForegroundColor $Color }

try {
  $title = " DISTRIBUIDOR DE PROPOSTAS - PRODUTO B"
  Header-Cyan $title

  $ciPT = New-Object System.Globalization.CultureInfo('pt-BR')
  $inpD = Read-Host "Digite a data de negócio (dd/MM/yyyy) [Enter para hoje]"
  if ([string]::IsNullOrWhiteSpace($inpD)) {
    $D = (Get-Date).Date
  } else {
    try { $D = [datetime]::ParseExact($inpD,'dd/MM/yyyy',$ciPT) }
    catch { Write-Host "Data inválida. Use dd/MM/yyyy."; exit 1 }
  }

  if ($PSBoundParameters.ContainsKey('OverrideD1Date') -and $OverrideD1Date) {
    $D1 = $OverrideD1Date.Date
    $mode = 'OverrideFromD1'
  } else {
    $D1 = $D.AddDays(-1)
    if ($StrictYesterday) { $mode = 'ExactFromD1' } else { $mode = 'FallbackFromD1' }
  }

  # ================= RESOLVE CAMINHO LOCAL SINCRONIZADO =================
  $userProfile = $env:USERPROFILE
  $candidates = @(
    (Join-Path $userProfile "Organizacao\Equipe Projeto - Documentos\Distribuicao Produto B\TXT_PRODUTO_B"),
    (Join-Path $userProfile "OneDrive - Organizacao\Equipe Projeto - Documentos\Distribuicao Produto B\TXT_PRODUTO_B"),
    (Join-Path $userProfile "OneDrive - Organizacao\Distribuicao Produto B\TXT_PRODUTO_B"),
    (Join-Path $userProfile "Organizacao\Distribuicao Produto B\TXT_PRODUTO_B"),
    (Join-Path $userProfile "Organizacao\Equipe Projeto - Documents\Distribuicao Produto B\TXT_PRODUTO_B"),
    (Join-Path $userProfile "Organizacao\Equipe Projeto - Distribuicao Produto B\TXT_PRODUTO_B")
  )

  $BaseTxt = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
  if (-not $BaseTxt) {
    Write-Host "FALHA: Pasta sincronizada 'Distribuicao Produto B\TXT_PRODUTO_B' não encontrada no perfil do usuário atual." -ForegroundColor Red
    Write-Host "Abra o SharePoint, sincronize a biblioteca do projeto e aguarde a pasta aparecer no Explorer." -ForegroundColor Yellow
    exit 1
  }

  $Config = @{
    OrigemDir    = "\\servidor\area\projeto\origem_produto_b";
    DestAnterior = (Join-Path $BaseTxt 'ARQUIVO_PRODUTO_B_ANTERIOR.txt');
    MetaAnterior = (Join-Path $BaseTxt 'ARQUIVO_PRODUTO_B_ANTERIOR_META.txt')
  }

  $files = Get-ChildItem -LiteralPath $Config.OrigemDir -Filter "ARQUIVO_PRODUTO_B_*" -File
  if (-not $files) { throw "Nenhum arquivo 'ARQUIVO_PRODUTO_B_*' encontrado na origem." }

  $ciInv = [System.Globalization.CultureInfo]::InvariantCulture
  $filesWithDate = foreach ($f in $files) {
    $name = $f.Name
    $m = [regex]::Match($name, '^ARQUIVO_PRODUTO_B_(\d{6})\.txt$', 'IgnoreCase')
    if (-not $m.Success) { $m = [regex]::Match($name, '^ARQUIVO_PRODUTO_B_(\d{6})txt$', 'IgnoreCase') }
    if ($m.Success) {
      $srcDate = [datetime]::ParseExact($m.Groups[1].Value, 'yyMMdd', $ciInv)
      [pscustomobject]@{ File=$f; SourceDate=$srcDate.Date; LastWriteTime=$f.LastWriteTime }
    }
  }

  # D-1 para log
  $pickD1 = $filesWithDate | Where-Object { $_.SourceDate -eq $D1 } | Sort-Object SourceDate -Descending | Select-Object -First 1
  if (-not $pickD1) {
    if ($PSBoundParameters.ContainsKey('OverrideD1Date') -and $OverrideD1Date) {
      throw ("OverrideD1Date {0:yyyy-MM-dd}: arquivo correspondente não encontrado." -f $D1)
    }
    if ($StrictYesterday) {
      throw ("Arquivo D-1 ({0}) não encontrado e StrictYesterday está ativo." -f $D1.ToString('dd/MM/yyyy',$ciPT))
    }
    $pickD1 = $filesWithDate | Where-Object { $_.SourceDate -le $D1 } | Sort-Object SourceDate -Descending | Select-Object -First 1
    if (-not $pickD1) { $pickD1 = $filesWithDate | Sort-Object SourceDate -Descending | Select-Object -First 1 }
  }

  # D-2 para gravar
  $pickD2 = $filesWithDate | Where-Object { $_.SourceDate -lt $pickD1.SourceDate } | Sort-Object SourceDate -Descending | Select-Object -First 1
  if (-not $pickD2) { $pickD2 = $filesWithDate | Sort-Object SourceDate | Select-Object -First 1 }

  Write-Host ("dia anterior:          {0}" -f $pickD1.SourceDate.ToString('dd/MM/yyyy',$ciPT))
  Write-Host ("arquivo dia anterior:  {0} (data referente ao arquivo: {1})" -f $pickD2.File.Name, $pickD2.SourceDate.ToString('dd/MM/yyyy',$ciPT))

  Update-Anterior -Src $pickD2.File -DestAnterior $Config.DestAnterior

  $meta = @{
    NomeOriginal            = $pickD2.File.Name
    SourceDate              = $pickD2.SourceDate.ToString('yyyy-MM-dd')
    WrittenAtUtc            = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
    ReferenceD1Original     = $pickD1.File.Name
    ReferenceD1SourceDate   = $pickD1.SourceDate.ToString('yyyy-MM-dd')
    Mode                    = $mode
  }
  Write-MetaFile -Path $Config.MetaAnterior -Data $meta

  Write-Color "`nANTERIOR.txt gerado com sucesso!`n" 'Green'
}
catch {
  Write-Host ("ERRO: {0}" -f $_.Exception.Message)
  exit 1
}
