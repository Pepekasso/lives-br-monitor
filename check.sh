#!/usr/bin/env bash
# Checa os canais de watch.txt na Twitch e na Kick e imprime as lives que acabaram desde a ultima checagem.
# Saida: "ENDED <plataforma>:<canal>" por live encerrada, "LIVE <plataforma>:<canal>" por live que comecou.
# Estado em state.txt (uma linha "plataforma:canal" por live no ar).
DIR="$(cd "$(dirname "$0")" && pwd)"
STATE="$DIR/state.txt"
UA="Mozilla/5.0"

watch=$(tr -d '\r' < "$DIR/watch.txt" | tr 'A-Z' 'a-z' | grep -v '^$')
prev=""
[ -f "$STATE" ] && prev=$(tr -d '\r' < "$STATE" | grep -v '^$' | sed '/:/!s/^/twitch:/')

vivos=""
lidos_t=0; lidos_k=0
for ch in $watch; do
  pagina=$(curl -sL -A "$UA" "https://www.twitch.tv/$ch")
  [ -n "$pagina" ] && lidos_t=$((lidos_t + 1))
  echo "$pagina" | grep -q '"isLiveBroadcast":true' && vivos="$vivos"$'\n'"twitch:$ch"

  api=$(curl -s -A "$UA" -H "Accept: application/json" "https://kick.com/api/v2/channels/$ch")
  echo "$api" | grep -q '"slug"' && lidos_k=$((lidos_k + 1))
  echo "$api" | grep -q '"livestream":{' && vivos="$vivos"$'\n'"kick:$ch"
done
[ "$lidos_t" -eq 0 ] && { echo "ERRO: nao consegui abrir nenhuma pagina da Twitch"; exit 1; }
# se a Kick nao respondeu (bloqueio), mantem quem estava ao vivo la, para nao avisar fim falso
if [ "$lidos_k" -eq 0 ]; then
  echo "AVISO: a Kick nao respondeu nesta checagem"
  vivos="$vivos"$'\n'"$(echo "$prev" | grep '^kick:')"
fi
vivos=$(echo "$vivos" | grep -v '^$' | sort -u)

for x in $prev; do echo "$vivos" | grep -qx "$x" || echo "ENDED $x"; done
for x in $vivos; do echo "$prev" | grep -qx "$x" || echo "LIVE $x"; done

echo "$vivos" > "$STATE"
echo "OK $(echo "$vivos" | grep -c .) lives no ar (Twitch: $lidos_t/$(echo "$watch" | grep -c .) lidos, Kick: $lidos_k lidos)"
