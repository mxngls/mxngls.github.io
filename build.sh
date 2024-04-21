#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# constants
SOURCE='src'
TARGET='docs'
MD_CONVERT='pandoc'
TITLE="Max Website"
HOST="mxngls.github.io"
URL="https://""$HOST"

# metadata format:
# title
# subtitle
# created_at
# updated_at

# redefine IFS to split on tabs
IFS='	'

# tabs as field separator
index_tsv() {
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

    # should work for the next 8000 years
    created="${created:0:10}"

    posts+=$(printf "
    <tr style=\"line-height: 1;\">
        <td style=\"font-weight: 500;\">%s</td>
        <td class=\"delimiter\">\\&#12316;</td>
        <td>
          <a style=\"color: inherit; font-weight: 500;\" href=%s>%s</a>
        </td>
    </tr>\n" "$created" "$ref" "$title")
  done < "$1"

  # shfmt-ignore
  content+="$(printf "
    <table>
      <tbody>
        %s
      </tbody>
    </table>" "$posts"
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
    'template.html'
}

create_page() {
  tmp_target="${1/%.md/.html}"
  target="${tmp_target//$SOURCE/$TARGET}"

  title="$2"
  subtitle="$3"
  content="$6"

  # should work for the next 8000 years
  created="${4:0:10}"
  updated="${5:0:10}"

  dates_text="<p><small>Written on ${created}</small></p>"
  if [ "$created" != "$updated" ]; then
    dates_text="
    <p>
      <small>Written on ${created}</small>
      <br/>
      <small>Last updated on ${updated}</small>
    </p>"
  fi

  html="$($MD_CONVERT -f gfm -t html "$f")"

  back_button="<a href=\"./\">back</a>"

  awk '
    BEGIN {
      html = ARGV[1];
      dates = ARGV[2];
      title = ARGV[3];
      back_button = ARGV[4];
      ARGV[1] = "";
      ARGV[2] = "";
      ARGV[3] = "";
      ARGV[4] = "";
      r = "{{CONTENT}}";    # string to be replaced
    }

    /{{CONTENT}}/ {         # treat everything as literals
      s = index($0,r);
      $0 = substr($0,1,s-1) back_button "<br/>" html substr($0,s+length(r)) "\n" dates;
    }

    /{{TITLE}}/ { sub(/{{TITLE}}/,title); }

    { print $0; }' \
    "$html" \
    "$dates_text" \
    "$title" \
    "$back_button" \
    template.html > "$target"

}

atom_xml() {

  # https://stackoverflow.com/a/5189296/13490131
  since="$(git log --max-parents=0 HEAD --format='%aI')" 
  updated="$(awk -v FS="$IFS" 'NR == 1 { print $5; exit;}' "$1")"
  uri="$URL""/atom.xml"

  cat << EOF
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
	<title>Max's Space</title>
	<link href="$uri" rel="self" />
	<updated>$updated</updated>
	<author>
		<name>Maximilian Hoenig</name>
	</author>
	<id>tag:www.$HOST,${since:0:10}:F2B3E23B-ECB6-4EE7-8197-D3C6C2594701</id>
EOF

  while read -r f title subtitle created updated content; do

    if [[ "$created" = "draft" ]]; then continue; fi

    t="${f//$SOURCE/$TARGET}"
    post_updated="${created:0:10}"
    content="$(awk '{gsub(/\\n/, "\n"); print $0;}' <<< "$subtitle""\n""$content" | \
      $MD_CONVERT -f gfm -t html | \
      awk '
      {
        gsub(/&/,   "\\&amp;", $0);
        gsub(/</,  "\\&lt;", $0);
        gsub(/>/,  "\\&gt;", $0);
        gsub(/"/,  "\\&#34;", $0);
        gsub(/'\''/,  "\\&#39;", $0);
        print $0;
      }'
    )"

    cat << EOF
    <entry>
      <title>$title</title>
      <content type="html">$content</content>
		  <link href="${f##"$SOURCE"/}"/>
      <id>tag:www.$HOST,$post_updated:$t</id>
      <published>$created</published>
      <updated>$updated</updated>
    </entry>
EOF
  done < "$1"

  echo '</feed>'
}

mkdir -p "$TARGET"
index_tsv | sort -r -t "	" -k 4 > "$TARGET"/index.tsv # Use tab as seperator
index_html "$TARGET"/index.tsv > "$TARGET"/index.html

while read -r f title subtitle created updated content; do
  create_page "$f" "$title" "$subtitle" "$created" "$updated" "$content"
done < "$TARGET"/index.tsv

atom_xml "$TARGET"/index.tsv > "$TARGET"/atom.xml
