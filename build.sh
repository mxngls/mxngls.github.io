#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# constants
SOURCE='src'
TARGET='docs'
MD_CONVERT='pandoc'
TITLE="Max Website"

# Metadata format:
# title
# subtitle
# created_at
# updated_at

# redefine IFS to split on tabs
IFS='	'

# tabs as field separator
meta_tsv() {
  for f in "$SOURCE"/*.md; do
    if [[ "$f" =~ index.md ]]; then continue; fi

    read -r title subtitle < <(
      awk -v RS= '
      # Parse title
      NR == 1 { 
        sub(/#[[:space:]]+/,""); 
        title=$0; 
      }

      # Parse subtitle
      NR == 2 { 
        sub(/\n/,"\\n"); 
        subtitle=$0; 
        print title "\t" subtitle; 
        exit;
      }' "$f"
    )

    read -r created updated < <(git log \
      --pretty='format:%aI' "$f" 2> /dev/null |
      awk '
          NR==1 { created=$0 }
          END{updated=$0; print created "\t" updated;}
      ')

    printf '%s\t%s\t%s\t%s\t%s\n' \
      "$f" \
      "${title:="No title"}" \
      "${subtitle:="No subtitle"}" \
      "${updated:="draft"}" \
      "${created:="draft"}"
  done
}

index_html() {

  content="$($MD_CONVERT src/index.md)"

  while read -r f title subtitle created updated; do
    f="$(basename "$f")"
    ref="${f/%.md/.html}"
    created=$(awk '{sub(/T.*/,""); print $0}' <<< "$created")
    posts+=$(printf "
    <li>
        <span>%s</span> \&nbsp; <a href=docs/%s>%s</a>
    </li>\n" "$created" "$ref" "$title")
  done < "$1"

  # shfmt-ignore
  content+="$(printf "
    <ol style=\"list-style: none; padding: 0;\">
      %s
    </ol>" "$posts"
  )"

  # Read input as arguments to avoid escaping newlines
  awk '
    BEGIN {
      title=ARGV[1]; 
      content=ARGV[2]; 
      ARGV[1]=""; 
      ARGV[2]="";
    }

    /{{TITLE}}/ { sub(/{{TITLE}}/,title); }

    /{{CONTENT}}/ { sub(/{{CONTENT}}/,content); }

    { print $0; }' \
    "$TITLE" \
    "$content" \
    'header.html'
}

create_page() {
  target="$(awk \
    -v source="$SOURCE" \
    -v target="$TARGET" \
    '{sub(source,target); print $0}' \
    <<< "${1/%.md/.html}")"

  title="$2"
  subtitle="$3"

  # should work for the next 8000 years
  created="${4:0:9}"
  updated="${5:0:9}"

  dates_text="Written on ${created}."
  if [ "$created" != "$updated" ]; then
    dates_text="$dates_text Last updated on ${updated}."
  fi

  # printf "<small>%s</small>" "$dates_text"| \

  content="$($MD_CONVERT "$f")"
  awk '
    BEGIN {
      content=ARGV[1];
      ARGV[1]="";
    }

    /{{CONTENT}}/ {
      sub(/{{CONTENT}}/,content); 
      print $0
    }' "$content" header.html > "$target"
}

meta_tsv | sort -r -t "\t" -k 4 > index.tsv
index_html index.tsv > index_test.html

while read -r f title subtitle created updated; do
  create_page "$f" "$title" "$subtitle" "$created" "$updated"
done < index.tsv
