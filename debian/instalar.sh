#!/usr/bin/env bash
# Configura este computador (Debian/Ubuntu) para baixar o enigma do dia e enviar
# para o GitHub a cada 30 minutos, sem depender do PC com Windows.
#
# Uso (como usuário normal, não precisa ser root):
#   curl -fsSL https://raw.githubusercontent.com/jhonnyyy23/teste/main/debian/instalar.sh | bash
set -euo pipefail
REPO="jhonnyyy23/teste"
DIR="$HOME/enigma"
KEY="$HOME/.ssh/enigma_deploy"

sudo_() { if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi; }

echo "==> 1/5 Verificando programas necessários"
falta=0
for c in git curl python3 ssh-keygen crontab; do command -v "$c" >/dev/null 2>&1 || falta=1; done
if [ "$falta" = 1 ]; then
  echo "    Instalando git, curl, python3, openssh-client e cron (pode pedir sua senha)…"
  sudo_ apt-get update -qq
  sudo_ apt-get install -y -qq git curl python3 openssh-client cron
fi
command -v systemctl >/dev/null 2>&1 && { systemctl is-active --quiet cron || sudo_ systemctl enable --now cron; } || true

echo "==> 2/5 Baixando o repositório em $DIR"
if [ -d "$DIR/.git" ]; then
  git -C "$DIR" pull -q --rebase origin main || true
else
  git clone -q "https://github.com/$REPO.git" "$DIR"
fi

echo "==> 3/5 Criando a chave de acesso ao GitHub"
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
[ -f "$KEY" ] || ssh-keygen -q -t ed25519 -N "" -C "enigma-debian@$(hostname)" -f "$KEY"
git -C "$DIR" remote set-url origin "git@github.com:$REPO.git"
git -C "$DIR" config core.sshCommand "ssh -i $KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
git -C "$DIR" config user.name "jhonnyyy23"
git -C "$DIR" config user.email "jhonnyyy23@users.noreply.github.com"

echo "==> 4/5 Agendando a sincronização a cada 30 minutos (cron)"
( crontab -l 2>/dev/null | grep -v 'debian/sincronizar.sh' || true
  echo "*/30 * * * * bash \"$DIR/debian/sincronizar.sh\"" ) | crontab -

echo "==> 5/5 Testando o acesso ao GitHub"
pode_enviar() { git -C "$DIR" push --dry-run -q origin main >/dev/null 2>&1; }
if ! pode_enviar; then
  echo
  echo "  Falta autorizar esta chave no GitHub (só uma vez):"
  echo "   1. Abra: https://github.com/$REPO/settings/keys/new"
  echo "   2. Title: Debian"
  echo "   3. Key: cole a linha abaixo"
  echo "   4. Marque 'Allow write access' e clique em 'Add key'"
  echo
  cat "$KEY.pub"
  echo
  if [ -r /dev/tty ]; then
    while ! pode_enviar; do
      read -r -p "  Depois de adicionar a chave, aperte Enter para testar de novo… " _ < /dev/tty
    done
  else
    echo "  Depois de adicionar a chave, a sincronização começa sozinha em até 30 minutos."
    exit 0
  fi
fi

echo "  Acesso ao GitHub OK."
bash "$DIR/debian/sincronizar.sh"
echo
echo "Pronto! Resultado da primeira sincronização:"
tail -n 8 "$DIR/sincronizar.log"
echo
echo "O registro fica em $DIR/sincronizar.log"
