#!/usr/bin/env bash
# Baixa o enigma do dia e envia para o GitHub, que republica o site.
# Roda pelo cron a cada 30 minutos (configurado pelo debian/instalar.sh).
set -u
DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG="$DIR/sincronizar.log"
# mantém o registro pequeno (últimas 2000 linhas)
[ -f "$LOG" ] && tail -n 2000 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
exec >> "$LOG" 2>&1
cd "$DIR"
echo "== $(date '+%F %T')"
git pull -q --rebase --autostash origin main || echo "aviso: não foi possível buscar alterações do GitHub"
python3 debian/atualizar.py
git add dados
if git diff --cached --quiet; then
  echo "Nada novo para enviar."
elif git commit -q -m "Enigmas de $(date -u +%F)" && git push -q origin main; then
  echo "Enviado para o GitHub."
else
  echo "ERRO ao enviar para o GitHub."
fi
