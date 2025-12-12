#!/bin/bash -e

### sanity checks

[ -z "$1" ] && {
  echo 'Provide an export xml' > /dev/stderr
  exit 13
}

which yq > /dev/null
which jq > /dev/null
which pandoc  > /dev/null

###

IN="$(realpath "$1")"

TMPDIR=$(mktemp -d)
echo "$TMPDIR"
cd "$TMPDIR" || exit

WM=wmark
MD=md

mkdir -p $WM
mkdir -p $MD

TMP=$(mktemp XXXXX.json)
cat "$IN" | yq -p xml '.mediawiki.page' -ojson \
  | jq 'map( {title: .title, content: .revision.text."+content" } )' \
  > "$TMP"

jq -c '.[]' "$TMP" | while read -r obj; do
  key=$(echo "$obj" | jq -r '.title')
  value=$(echo "$obj" | jq -r '.content')

  if [[ "$key" == */* ]]
  then
    echo "Warning: '/' in title $key" > /dev/stderr
  else
    printf "%s\n" "$value" > "$WM/${key}.mediawiki"
  fi
done

for m in "$WM"/*
do
  NAME=$(basename "$m" mediawiki)
  pandoc -f mediawiki -t markdown "$m" -o $MD/"$NAME".md \
    || echo 'parse error in' "$NAME" > /dev/stderr
done
