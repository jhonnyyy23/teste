<#
  Baixa os enigmas novos (atualizar.ps1) e envia tudo para o GitHub,
  que republica o site sozinho. É o que a tarefa agendada diária executa.
  Registro da última execução: sincronizar.log
#>
$ErrorActionPreference = 'Continue'
Set-Location $PSScriptRoot
Start-Transcript -Path (Join-Path $PSScriptRoot 'sincronizar.log') | Out-Null

$git = 'C:\Program Files\Git\cmd\git.exe'

# traz alterações feitas pelo site do GitHub, para não haver conflito
& $git pull --rebase --autostash origin main

& (Join-Path $PSScriptRoot 'atualizar.ps1')

& $git add -A
& $git diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
  & $git commit -m ("Enigmas de " + (Get-Date).ToString('yyyy-MM-dd'))
  & $git push origin main
  if ($LASTEXITCODE -eq 0) { Write-Host 'Enviado para o GitHub.' } else { Write-Host 'ERRO ao enviar para o GitHub.' }
} else {
  Write-Host 'Nada novo para enviar.'
}

Stop-Transcript | Out-Null
