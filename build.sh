#!/bin/bash

set -o errexit
set -o nounset
# set -o pipefail

SOURCE='src'

# Metadata format:
# title
# subtitle
# created_at
# updated_at

IFS=' '
meta_tsv() {
  for f in "$SOURCE"/*.md; do
    if [[ "$f" =~ index.md ]]; then continue; fi

    title="$(awk -v RS= '
      # Parse title
      NR == 1 { title=$0; sub(/#[[:space:]]+/,"",title); }

      # Parse subtitle
      NR == 2 { sub(/\n/,"\\n"); subtitle=$0; print title "\t" subtitle; exit;}' "$f")"

    created=$(git log --pretty='format:%aI' "$f" 2> /dev/null | tail -1)
    updated=$(git log --pretty='format:%aI' "$f" 2> /dev/null | head -1)

    printf '%s\t%s\t%s\t%s\n' "$f" "${title:="No Title"}" "${created:="draft"}" "${updated:="draft"}"
  done
}

meta_tsv | sort -r -t "\t" -k 3 > test.csv
