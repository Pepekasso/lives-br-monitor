#!/usr/bin/env bash
# Checa as top lives BR (portugues) da Twitch + os canais de watch.txt e imprime as que acabaram desde a ultima checagem.
# Saida: "ENDED <login>" por live encerrada. Estado salvo em state.txt ao lado.
# Com TWITCH_CLIENT_ID e TWITCH_CLIENT_SECRET no ambiente usa a API oficial da Twitch (funciona no GitHub);
# sem eles, le o twitchtracker.com (funciona no PC, mas o site bloqueia servidores).
DIR="$(cd "$(dirname "$0")" && pwd)"
STATE="$DIR/state.txt"
UA="Mozilla/5.0"
TOP=20

watch=""
[ -f "$DIR/watch.txt" ] && watch=$(tr -d '\r' < "$DIR/watch.txt" | tr 'A-Z' 'a-z' | grep -v '^$')
prev=""
[ -f "$STATE" ] && prev=$(tr -d '\r' < "$STATE" | grep -v '^$')

if [ -n "$TWITCH_CLIENT_ID" ] && [ -n "$TWITCH_CLIENT_SECRET" ]; then
  token=$(curl -s -X POST "https://id.twitch.tv/oauth2/token" \
    -d "client_id=$TWITCH_CLIENT_ID" -d "client_secret=$TWITCH_CLIENT_SECRET" -d "grant_type=client_credentials" \
    | grep -oE '"access_token":"[^"]+"' | cut -d'"' -f4)
  [ -z "$token" ] && { echo "ERRO: token da Twitch nao veio (confira o Client ID e o Secret)"; exit 1; }
  api() { curl -s -H "Client-Id: $TWITCH_CLIENT_ID" -H "Authorization: Bearer $token" "https://api.twitch.tv/helix/$1"; }
  logins() { grep -oE '"user_login":"[^"]+"' | cut -d'"' -f4 | tr 'A-Z' 'a-z'; }
  top=$(api "streams?language=pt&first=$TOP" | logins)
  [ -z "$top" ] && { echo "ERRO: a API da Twitch nao devolveu lives"; exit 1; }
  # quem estava sendo monitorado ou esta na lista fixa: pergunta de uma vez (ate 100 por chamada)
  outros=$(printf '%s\n%s\n' "$prev" "$watch" | grep -v '^$' | awk '!seen[$0]++' | head -n 100)
  vivos=""
  if [ -n "$outros" ]; then
    q=$(echo "$outros" | sed 's/^/user_login=/' | paste -sd '&' -)
    vivos=$(api "streams?first=100&$q" | logins)
  fi
  for ch in $prev; do
    echo "$top"$'\n'"$vivos" | grep -qx "$ch" || echo "ENDED $ch"
  done
  fixos=$(for ch in $watch; do echo "$vivos" | grep -qx "$ch" && echo "$ch"; done)
  ainda=$(for ch in $prev; do echo "$vivos" | grep -qx "$ch" && echo "$ch"; done)
  printf '%s\n%s\n%s\n' "$top" "$fixos" "$ainda" | grep -v '^$' | awk '!seen[$0]++' > "$STATE"
  echo "OK $(wc -l < "$STATE") lives monitoradas (API)"
  exit 0
fi

ao_vivo() { curl -sL -A "$UA" "https://www.twitch.tv/$1" | grep -q '"isLiveBroadcast":true'; }

now=$(curl -sL -A "$UA" "https://twitchtracker.com/channels/live/portuguese" \
  | grep -oE 'href="/[a-z0-9_]+"' | sed -E 's/href="\/(.*)"/\1/' \
  | grep -vE '^(games|clips|statistics|languages|subscribers|api|channels)$' \
  | awk '!seen[$0]++' | head -n "$TOP")

if [ -z "$now" ]; then echo "ERRO: nao consegui ler a lista (HTTP $(curl -s -A "$UA" -o /dev/null -w "%{http_code}" "https://twitchtracker.com/channels/live/portuguese"))"; exit 1; fi

# Canais fixos (watch.txt): entram no monitoramento sempre que estiverem ao vivo
for ch in $watch; do
  echo "$now" | grep -qx "$ch" && continue
  ao_vivo "$ch" && now="$now"$'\n'"$ch"
done

# Mantem no estado quem estava no top e ainda esta ao vivo (mesmo se caiu do top)
still=""
for ch in $prev; do
  echo "$now" | grep -qx "$ch" && continue
  if ao_vivo "$ch"; then still="$still"$'\n'"$ch"; else echo "ENDED $ch"; fi
done

printf '%s\n%s\n' "$now" "$still" | grep -v '^$' | awk '!seen[$0]++' > "$STATE"
echo "OK $(wc -l < "$STATE") lives monitoradas"
