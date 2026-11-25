#!/usr/bin/env bash
# Checa as top lives BR (portugues) da Twitch e imprime as que acabaram desde a ultima checagem.
# Saida: "ENDED <login>" por live encerrada. Estado salvo em state.txt ao lado.
DIR="$(cd "$(dirname "$0")" && pwd)"
STATE="$DIR/state.txt"
UA="Mozilla/5.0"
TOP=20

now=$(curl -sL -A "$UA" "https://twitchtracker.com/channels/live/portuguese" \
  | grep -oE 'href="/[a-z0-9_]+"' | sed -E 's/href="\/(.*)"/\1/' \
  | grep -vE '^(games|clips|statistics|languages|subscribers|api|channels)$' \
  | awk '!seen[$0]++' | head -n "$TOP")

if [ -z "$now" ]; then echo "ERRO: nao consegui ler a lista (HTTP $(curl -s -A "$UA" -o /dev/null -w "%{http_code}" "https://twitchtracker.com/channels/live/portuguese"))"; exit 1; fi

# Canais fixos (watch.txt): entram no monitoramento sempre que estiverem ao vivo
if [ -f "$DIR/watch.txt" ]; then
  while read -r ch; do
    ch=$(echo "$ch" | tr -d '\r' | tr 'A-Z' 'a-z')
    [ -z "$ch" ] && continue
    echo "$now" | grep -qx "$ch" && continue
    if curl -sL -A "$UA" "https://www.twitch.tv/$ch" | grep -q '"isLiveBroadcast":true'; then
      now="$now"$'\n'"$ch"
    fi
  done < "$DIR/watch.txt"
fi

# Mantem no estado quem estava no top e ainda esta ao vivo (mesmo se caiu do top)
still=""
if [ -f "$STATE" ]; then
  while read -r ch; do
    [ -z "$ch" ] && continue
    if echo "$now" | grep -qx "$ch"; then continue; fi
    if curl -sL -A "$UA" "https://www.twitch.tv/$ch" | grep -q '"isLiveBroadcast":true'; then
      still="$still"$'\n'"$ch"
    else
      echo "ENDED $ch"
    fi
  done < "$STATE"
fi

printf '%s\n%s\n' "$now" "$still" | grep -v '^$' | awk '!seen[$0]++' > "$STATE"
echo "OK $(wc -l < "$STATE") lives monitoradas"
