<#
  Baixa os enigmas diários do puzzleship.com (os 6 níveis) e salva em dados\AAAA-MM-DD.js,
  que o index.html carrega.

  Uso:
    .\atualizar.ps1                  # hoje + dias que estiverem faltando (últimos 30 dias)
    .\atualizar.ps1 -Dias 365        # completa o último ano
    .\atualizar.ps1 -Data 2025-01-15 # um dia específico (sobrescreve)
#>
param(
  [string]$Data,
  [int]$Dias = 30,
  [string]$Saida = (Join-Path $PSScriptRoot 'dados')
)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Web.Extensions
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$ser.MaxJsonLength = [int]::MaxValue
$utf8 = New-Object Text.UTF8Encoding $false
New-Item -ItemType Directory -Force $Saida | Out-Null

# Extrai o objeto JSON "pack" do payload do Next.js embutido na página
function Get-Pack([string]$dia) {
  $resp = Invoke-WebRequest -UseBasicParsing "https://www.puzzleship.com/logic/einstein-riddles/p/$dia"
  $html = $utf8.GetString($resp.RawContentStream.ToArray())
  $sb = New-Object Text.StringBuilder
  foreach ($m in [regex]::Matches($html, 'self\.__next_f\.push\(\[1,("(?:[^"\\]|\\.)*")\]\)')) {
    [void]$sb.Append($ser.DeserializeObject($m.Groups[1].Value))
  }
  $t = $sb.ToString()
  $i = $t.IndexOf('"pack":{')
  if ($i -lt 0) { throw 'pacote não encontrado na página' }
  $i += 7
  $depth = 0; $inStr = $false; $esc = $false
  for ($j = $i; $j -lt $t.Length; $j++) {
    $ch = $t[$j]
    if ($inStr) {
      if ($esc) { $esc = $false } elseif ($ch -eq '\') { $esc = $true } elseif ($ch -eq '"') { $inStr = $false }
    } elseif ($ch -eq '"') { $inStr = $true }
    elseif ($ch -eq '{') { $depth++ }
    elseif ($ch -eq '}') { $depth--; if ($depth -eq 0) { break } }
  }
  $pack = $ser.DeserializeObject($t.Substring($i, $j - $i + 1))
  if ($pack['dateSlug'] -ne $dia) { throw "a página devolveu o dia $($pack['dateSlug'])" }

  # guarda só o necessário para o jogo
  [ordered]@{
    num   = $pack['num']
    data  = $pack['dateSlug']
    niveis = @($pack['items'] | ForEach-Object {
      [ordered]@{
        nivel     = $_['level']
        categorias = @($_['house']['attributes'] | ForEach-Object { [ordered]@{ nome = $_['name']; itens = @($_['items']) } })
        solucao   = @($_['solution'] | ForEach-Object { , @($_) })
        pistas    = @($_['clues'] | ForEach-Object { [ordered]@{ regra = @($_['rule'][0], @($_['rule'][1])); texto = $_['text'] } })
      }
    })
  }
}

if ($Data) { $lista = @($Data) }
else {
  $hoje = (Get-Date).ToUniversalTime()
  $lista = 0..$Dias | ForEach-Object { $hoje.AddDays(-$_).ToString('yyyy-MM-dd') }
}

foreach ($dia in $lista) {
  $arq = Join-Path $Saida "$dia.js"
  if ((Test-Path $arq) -and -not $Data) { continue }
  try {
    $pack = Get-Pack $dia
    $js = "(window.PACKS = window.PACKS || {})['$dia'] = " + $ser.Serialize($pack) + ";`n"
    [IO.File]::WriteAllText($arq, $js, $utf8)
    Write-Host "OK  $dia  (#$($pack.num))"
  } catch {
    Write-Host "--  $dia  não disponível: $($_.Exception.Message)"
  }
}

# índice com as datas disponíveis (o navegador não consegue listar a pasta sozinho)
$datas = [string[]](Get-ChildItem $Saida -Filter '????-??-??.js' | ForEach-Object { [string]$_.BaseName } | Sort-Object)
[IO.File]::WriteAllText((Join-Path $Saida 'indice.js'), 'window.DATAS = ' + $ser.Serialize(@($datas)) + ";`n", $utf8)
Write-Host "$($datas.Count) dia(s) disponíveis em $Saida"
