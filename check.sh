#!/usr/bin/env bash
# Checa os canais de watch.txt e imprime os que encerraram a live desde a ultima checagem.
# Saida: "ENDED <login>" por live encerrada, "LIVE <login>" por live que comecou. Estado em state.txt.
# Com TWITCH_CLIENT_ID e TWITCH_CLIENT_SECRET no ambiente usa a API oficial da Twitch;
# sem eles, abre a pagina de cada canal na Twitch.
DIR="$(cd "$(dirname "$0")" && pwd)"
STATE="$DIR/state.txt"
UA="Mozilla/5.0"

watch=$(tr -d '\r' < "$DIR/watch.txt" | tr 'A-Z' 'a-z' | grep -v '^$')
prev=""
[ -f "$STATE" ] && prev=$(tr -d '\r' < "$STATE" | grep -v '^$')

vivos=""
if [ -n "$TWITCH_CLIENT_ID" ] && [ -n "$TWITCH_CLIENT_SECRET" ]; then
  token=$(curl -s -X POST "https://id.twitch.tv/oauth2/token" \
    -d "client_id=$TWITCH_CLIENT_ID" -d "client_secret=$TWITCH_CLIENT_SECRET" -d "grant_type=client_credentials" \
    | grep -oE '"access_token":"[^"]+"' | cut -d'"' -f4)
  [ -z "$token" ] && { echo "ERRO: token da Twitch nao veio (confira o Client ID e o Secret)"; exit 1; }
  q=$(echo "$watch" | sed 's/^/user_login=/' | paste -sd '&' -)
  resp=$(curl -s -H "Client-Id: $TWITCH_CLIENT_ID" -H "Authorization: Bearer $token" "https://api.twitch.tv/helix/streams?first=100&$q")
  echo "$resp" | grep -q '"data"' || { echo "ERRO: resposta estranha da API: ${resp:0:200}"; exit 1; }
  vivos=$(echo "$resp" | grep -oE '"user_login":"[^"]+"' | cut -d'"' -f4 | tr 'A-Z' 'a-z')
else
  lidos=0
  for ch in $watch; do
    pagina=$(curl -sL -A "$UA" "https://www.twitch.tv/$ch")
    [ -n "$pagina" ] && lidos=$((lidos + 1))
    echo "$pagina" | grep -q '"isLiveBroadcast":true' && vivos="$vivos"$'\n'"$ch"
  done
  [ "$lidos" -eq 0 ] && { echo "ERRO: nao consegui abrir nenhuma pagina da Twitch"; exit 1; }
fi
vivos=$(echo "$vivos" | grep -v '^$')

for ch in $prev; do echo "$vivos" | grep -qx "$ch" || echo "ENDED $ch"; done
for ch in $vivos; do echo "$prev" | grep -qx "$ch" || echo "LIVE $ch"; done

echo "$vivos" > "$STATE"
echo "OK $(echo "$vivos" | grep -c .) de $(echo "$watch" | grep -c .) canais ao vivo"
