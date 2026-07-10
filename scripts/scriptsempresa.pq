# =====================================================
# Script 1: Copiar_Arquivo_Atual_Share.ps1
# Gera ARQUIVO_PRODUTO_A_ATUAL.TXT (D-1) e escreve .meta.
# Caminho da pasta sincronizada montado dinamicamente para qualquer usuário.
# =====================================================

param(
    [switch]$StrictYesterday,
    [datetime]$OverrideD1Date
)

$ErrorActionPreference = 'Stop'

# ================= RESOLVE CAMINHO LOCAL SINCRONIZADO =================
$userProfile = $env:USERPROFILE
$candidates = @(
  (Join-Path $userProfile "Organizacao\Equipe Projeto - Documentos\Automacao Produto A\TXT_PRODUTO_A"),
  (Join-Path $userProfile "OneDrive - Organizacao\Equipe Projeto - Documentos\Automacao Produto A\TXT_PRODUTO_A"),
  (Join-Path $userProfile "OneDrive - Organizacao\Automacao Produto A\TXT_PRODUTO_A"),
  (Join-Path $userProfile "Organizacao\Automacao Produto A\TXT_PRODUTO_A"),
  (Join-Path $userProfile "Organizacao\Equipe Projeto - Documents\Automacao Produto A\TXT_PRODUTO_A"),
  (Join-Path $userProfile "Organizacao\Equipe Projeto - Automacao Produto A\TXT_PRODUTO_A")
)

$BaseTxt = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $BaseTxt) {
  Write-Host "FALHA: Pasta sincronizada 'Automacao Produto A\TXT_PRODUTO_A' não encontrada no perfil do usuário atual." -ForegroundColor Red
  Write-Host "Abra o SharePoint, sincronize a biblioteca do projeto e aguarde a pasta aparecer no Explorer." -ForegroundColor Yellow
  exit 1
}

# ================= CONFIG =================
$Config = @{
  OrigemDir = "\\servidor\area\projeto\origem_produto_a"
  DestAtual = Join-Path $BaseTxt "ARQUIVO_PRODUTO_A_ATUAL.TXT"
  MetaAtual = Join-Path $BaseTxt "ARQUIVO_PRODUTO_A_ATUAL_META.txt"
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

function Write-MetaFile {
  param([Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][hashtable]$Data)
  $dir = Split-Path -Path $Path -Parent
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  $lines = foreach ($k in $Data.Keys) { "{0}={1}" -f $k, ($Data[$k]) }
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllLines($Path, $lines, $utf8NoBom)
}

function Update-Atual {
  param(
    [Parameter(Mandatory=$true)][IO.FileInfo]$Src,
    [Parameter(Mandatory=$true)][string]$DestAtual
  )
  $destDir = Split-Path -Path $DestAtual -Parent
  Ensure-Dir $destDir
  Copy-Item -LiteralPath $Src.FullName -Destination $DestAtual -Force
}

try {
  $ciPT = New-Object System.Globalization.CultureInfo('pt-BR')
  $inpD = Read-Host "Digite a data de negócio (dd/MM/yyyy) [Enter para hoje]"
  if ([string]::IsNullOrWhiteSpace($inpD)) { $D = (Get-Date).Date }
  else {
    try { $D = [datetime]::ParseExact($inpD, 'dd/MM/yyyy', $ciPT) }
    catch { Write-Host "Data inválida. Use dd/MM/yyyy. Ex: 24/10/2025."; exit 1 }
  }

  if ($PSBoundParameters.ContainsKey('OverrideD1Date') -and $OverrideD1Date) {
    $D1 = $OverrideD1Date.Date
    $mode = 'OverrideFromD1'
  } else {
    $D1 = $D.AddDays(-1)
    if ($StrictYesterday) { $mode = 'ExactFromD1' } else { $mode = 'FallbackFromD1' }
  }

  $files = Get-ChildItem -LiteralPath $Config.OrigemDir -Filter "ARQUIVO_PRODUTO_A_*.TXT" -File
  if (-not $files) { throw "Nenhum arquivo 'ARQUIVO_PRODUTO_A_*.TXT' encontrado na origem." }

  $ciInv = [System.Globalization.CultureInfo]::InvariantCulture
  $filesWithDate = foreach ($f in $files) {
    $m = [regex]::Match($f.Name, '^ARQUIVO_PRODUTO_A_(\d{6})\.TXT$')
    if ($m.Success) {
      $srcDate = [datetime]::ParseExact($m.Groups[1].Value, 'yyMMdd', $ciInv)
      [pscustomobject]@{ File=$f; SourceDate=$srcDate.Date; LastWriteTime=$f.LastWriteTime }
    }
  }

  # Seleciona D-1 com fallback
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
  Write-Host "======================================="

  Update-Atual -Src $pickD1.File -DestAtual $Config.DestAtual

  $meta = @{
    NomeOriginal          = $pickD1.File.Name
    SourceDate            = $pickD1.SourceDate.ToString('yyyy-MM-dd')
    WrittenAtUtc          = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
    Mode                  = $mode
  }
  Write-MetaFile -Path $Config.MetaAtual -Data $meta

  Write-Host ""
  Write-Host "ATUAL.TXT gerado com sucesso!" -ForegroundColor Green
}
catch {
  Write-Host ("ERRO: {0}" -f $_.Exception.Message)
  exit 1
}


# =====================================================
# Script 2: Copiar_Arquivo_Historico_Share.ps1
# Gera ARQUIVO_PRODUTO_A_ANTERIOR.TXT (D-2) e escreve .meta.
# Caminho da pasta sincronizada montado dinamicamente para qualquer usuário.
# =====================================================

<#
OBSERVAÇÃO:
Este segundo script foi mantido no mesmo arquivo para documentação/repositório.
Para execução prática no PowerShell, salve este bloco em um arquivo separado, por exemplo:
Copiar_Arquivo_Historico_Share.ps1.
#>

param(
    [switch]$StrictYesterday,
    [datetime]$OverrideD1Date
)

$ErrorActionPreference = 'Stop'

# ================= RESOLVE CAMINHO LOCAL SINCRONIZADO =================
$userProfile = $env:USERPROFILE
$candidates = @(
  (Join-Path $userProfile "Organizacao\Equipe Projeto - Documentos\Automacao Produto A\TXT_PRODUTO_A"),
  (Join-Path $userProfile "OneDrive - Organizacao\Equipe Projeto - Documentos\Automacao Produto A\TXT_PRODUTO_A"),
  (Join-Path $userProfile "OneDrive - Organizacao\Automacao Produto A\TXT_PRODUTO_A"),
  (Join-Path $userProfile "Organizacao\Automacao Produto A\TXT_PRODUTO_A"),
  (Join-Path $userProfile "Organizacao\Equipe Projeto - Documents\Automacao Produto A\TXT_PRODUTO_A"),
  (Join-Path $userProfile "Organizacao\Equipe Projeto - Automacao Produto A\TXT_PRODUTO_A")
)

$BaseTxt = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $BaseTxt) {
  Write-Host "FALHA: Pasta sincronizada 'Automacao Produto A\TXT_PRODUTO_A' não encontrada no perfil do usuário atual." -ForegroundColor Red
  Write-Host "Abra o SharePoint, sincronize a biblioteca do projeto e aguarde a pasta aparecer no Explorer." -ForegroundColor Yellow
  exit 1
}

# ================= CONFIG =================
$Config = @{
  OrigemDir    = "\\servidor\area\projeto\origem_produto_a"
  DestAnterior = Join-Path $BaseTxt "ARQUIVO_PRODUTO_A_ANTERIOR.TXT"
  MetaAnterior = Join-Path $BaseTxt "ARQUIVO_PRODUTO_A_ANTERIOR_META.txt"
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

function Write-MetaFile {
  param([Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][hashtable]$Data)
  $dir = Split-Path -Path $Path -Parent
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  $lines = foreach ($k in $Data.Keys) { "{0}={1}" -f $k, ($Data[$k]) }
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllLines($Path, $lines, $utf8NoBom)
}

function Update-Anterior {
  param(
    [Parameter(Mandatory=$true)][IO.FileInfo]$Src,
    [Parameter(Mandatory=$true)][string]$DestAnterior
  )
  $destDir = Split-Path -Path $DestAnterior -Parent
  Ensure-Dir $destDir
  Copy-Item -LiteralPath $Src.FullName -Destination $DestAnterior -Force
}

function Write-Color([string]$Text, [string]$Color) {
  Write-Host $Text -ForegroundColor $Color
}

try {
  Write-Color "`n=======================================" 'Cyan'
  Write-Color " DISTRIBUIDOR DE PROPOSTAS - PRODUTO A" 'Cyan'
  Write-Color "=======================================`n" 'Cyan'

  $ciPT = New-Object System.Globalization.CultureInfo('pt-BR')
  $inpD = Read-Host "Digite a data de negócio (dd/MM/yyyy) [Enter para hoje]"
  if ([string]::IsNullOrWhiteSpace($inpD)) { $D = (Get-Date).Date }
  else {
    try { $D = [datetime]::ParseExact($inpD, 'dd/MM/yyyy', $ciPT) }
    catch { Write-Host "Data inválida. Use dd/MM/yyyy. Ex: 24/10/2025."; exit 1 }
  }

  if ($PSBoundParameters.ContainsKey('OverrideD1Date') -and $OverrideD1Date) {
    $D1 = $OverrideD1Date.Date
    $mode = 'OverrideFromD1'
  } else {
    $D1 = $D.AddDays(-1)
    if ($StrictYesterday) { $mode = 'ExactFromD1' } else { $mode = 'FallbackFromD1' }
  }

  $files = Get-ChildItem -LiteralPath $Config.OrigemDir -Filter "ARQUIVO_PRODUTO_A_*.TXT" -File
  if (-not $files) { throw "Nenhum arquivo 'ARQUIVO_PRODUTO_A_*.TXT' encontrado na origem." }

  $ciInv = [System.Globalization.CultureInfo]::InvariantCulture
  $filesWithDate = foreach ($f in $files) {
    $m = [regex]::Match($f.Name, '^ARQUIVO_PRODUTO_A_(\d{6})\.TXT$')
    if ($m.Success) {
      $srcDate = [datetime]::ParseExact($m.Groups[1].Value, 'yyMMdd', $ciInv)
      [pscustomobject]@{ File=$f; SourceDate=$srcDate.Date; LastWriteTime=$f.LastWriteTime }
    }
  }

  # Seleciona D-1 para referência de log
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

  # Seleciona D-2 para gravar ANTERIOR.TXT
  $pickD2 = $filesWithDate | Where-Object { $_.SourceDate -lt $pickD1.SourceDate } | Sort-Object SourceDate -Descending | Select-Object -First 1
  if (-not $pickD2) { $pickD2 = $filesWithDate | Sort-Object SourceDate | Select-Object -First 1 }

  Write-Host ("dia anterior:          {0}" -f $pickD1.SourceDate.ToString('dd/MM/yyyy',$ciPT))
  Write-Host ("arquivo dia anterior:  {0} (data referente ao arquivo: {1})" -f $pickD2.File.Name, $pickD2.SourceDate.ToString('dd/MM/yyyy',$ciPT))
  Write-Host "======================================="

  Update-Anterior -Src $pickD2.File -DestAnterior $Config.DestAnterior

  $meta = @{
    NomeOriginal              = $pickD2.File.Name
    SourceDate                = $pickD2.SourceDate.ToString('yyyy-MM-dd')
    WrittenAtUtc              = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
    ReferenceD1Original       = $pickD1.File.Name
    ReferenceD1SourceDate     = $pickD1.SourceDate.ToString('yyyy-MM-dd')
    Mode                      = $mode
    LagFromExpectedD1Days     = ($D1 - $pickD1.SourceDate).Days
    LagFromExpectedD2Days     = ($pickD1.SourceDate.AddDays(-1) - $pickD2.SourceDate).Days
  }
  Write-MetaFile -Path $Config.MetaAnterior -Data $meta

  Write-Color "`nANTERIOR.TXT gerado com sucesso!`n" 'Green'
}
catch {
  Write-Host ("ERRO: {0}" -f $_.Exception.Message)
  exit 1
}
