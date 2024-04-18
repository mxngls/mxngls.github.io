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

    read -r title subtitle content < <(
      awk -v RS= '
      BEGIN {
        title = "";
        subtitle = "";
      }

      # Parse title
      NR == 1 { 
        gsub(/#[[:space:]]+/,""); 
        title=$0; 
      }

      # Parse subtitle
      NR == 2 { 
        gsub(/\n/,"\\n"); 
        subtitle=$0; 
      }
      
      # Parse content
      NR > 2 {
        gsub(/\n/,"\\n"); 
        content = content $0 "\\n";
      }

      END {
        print title "\t" subtitle "\t" content;
      }
      ' "$f"
    )

    read -r created updated < <(git log \
      --pretty='format:%aI' "$f" 2> /dev/null |
      awk '
          NR==1 { created=$0 }
          END{updated=$0; print created "\t" updated;}
      ')

    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$f" \
      "${title:="No title"}" \
      "${subtitle:="No subtitle"}" \
      "${updated:="draft"}" \
      "${created:="draft"}" \
      "${content:="draft"}"
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
  content+="$(
    printf "
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

    /{{TITLE}}/ { gsub(/{{TITLE}}/,title); }

    /{{CONTENT}}/ { gsub(/{{CONTENT}}/,content); }

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

  content="$6"

  dates_text="Written on ${created}."
  if [ "$created" != "$updated" ]; then
    dates_text="$dates_text Last updated on ${updated}."
  fi

  # printf "<small>%s</small>" "$dates_text"| \

  html="$($MD_CONVERT -f gfm -t html < <(awk '{gsub(/\\n/,"\n"); print $0}' <<< "$content"))"

  awk '
    BEGIN {
      html=ARGV[1];
      ARGV[1]="";
    }

    /{{CONTENT}}/ {
      gsub(/{{CONTENT}}/,html); 
      print $0;
    }' "$html" header.html > "$target"

}

meta_tsv | sort -r -t "\t" -k 4 > index.tsv
index_html index.tsv > index_test.html

while read -r f title subtitle created updated content; do
  create_page "$f" "$title" "$subtitle" "$created" "$updated" "$content"
done < index.tsv
