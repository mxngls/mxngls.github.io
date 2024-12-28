#!/bin/bash

# constants
SOURCE='src'
TARGET='docs'
MD_CONVERT='pandoc'
TITLE="˚⌇˚"
HOST="mxngls.github.io"
URL="https://""$HOST"

# metadata format:
# title
# subtitle
# created_at
# updated_at

# redefine IFS to split on tabs
IFS=$'\t'

# tabs as field separator
index_tsv() {
  while read -r f; do
    if [[ "$f" =~ index.html ]]; then continue; fi

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
      --follow \
      --format='format:%ad' \
      --date='format:%Y/%m/%d' \
      "$f" 2> /dev/null |
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
  done < <(find "$SOURCE" -type f -name '*.md' -not -path "$SOURCE/drafts/*")
}

index_html() {
  content="$(< "$SOURCE"/index.html)"

  while read -r f title subtitle created updated; do
    d="$(dirname "$f")"
    ref="${f//$SOURCE/$TARGET}"
    ref="${ref#*/}"
    ref="${ref/%.md/.html}"
    f="$(basename "$f")"

    if [[ "$d" =~ "notes" ]]; then
      notes+=$(printf '
        <tr>
          <td>%s</td>
          <td style="padding-left: 10px">
            <a href=%s>%s</a>
          </td>
        </tr>\n' "$created" "$ref" "$title")
    else
      posts+=$(printf '
      <tr>
          <td>%s</td>
          <td style="padding-left: 10px">
            <a href=%s>%s</a>
          </td>
      </tr>\n' "$created" "$ref" "$title")
    fi
  done < "$1"

  # shfmt-ignore
  content+="$(printf '
        <div>
          <h2>Notes</h2>
          <p>
            Things I worked on in the past or that I am still tinkering with (mostly of technical nature): 
          </p> 
          <table stlye="width: 100%%;">
            <tbody>
              %s
            </tbody>
          </table>
          <h2>Weblog</h2>
          <p>
            Occasionally shared writings that feel hard to categorize <a href="./atom.xml"><em>(feed)</em></a>:
          </p> 
          <table>
            <tbody>
              %s
            </tbody>
          </table>
        </div>
	  </main>' "$notes" "$posts")"

  # Read input as arguments to avoid escaping newlines
  awk '
    BEGIN {
      title=ARGV[1];
      content=ARGV[2];
      ARGV[1]="";
      ARGV[2]="";
    }

    /{{TITLE}}/ { gsub(/{{TITLE}}/,title); }

    /{{CONTENT}}/ { gsub(/{{CONTENT}}/, content); }

    { print $0; }' \
    "$TITLE" \
    "$content" \
    'index_template.html'
}

create_dirs() {
  for d in "$SOURCE"/*; do
    if [[ -d "$d" ]] && [[ ! "$d" =~ "drafts" ]]; then
      local dir="${d/$SOURCE/$TARGET}"
      mkdir "$dir" &> /dev/null
    fi
  done
}

create_page() {
  if [[ "$#" -ne 6 ]]; then
    echo "Invalid number of arguments: $#. Expected six."
	return 1
  fi

  tmp_target="${1/%.md/.html}"
  target="${tmp_target//$SOURCE/$TARGET}"

  title="$2"
  subtitle="$3"

  date_created="<div style=\"margin: 1rem 0;\">${4}</div>"
  date_updated="<div style=\"margin: 1rem 0;\"><small>Last Updated on ${5}</small></div>"
  content="$($MD_CONVERT -f gfm -t html "$1")"

  header="$date_created"
  main="$content"
  footer="$date_updated"

  # provide multiline strings as arguments instead of using -v var=""
  awk '
    BEGIN {
      title = ARGV[1];
      header = ARGV[2];
      main = ARGV[3];
      footer = ARGV[4];
      ARGV[1] = "";
      ARGV[2] = "";
      ARGV[3] = "";
      ARGV[4] = "";
    }

    /{{HEADER}}/ { 
      r = "{{HEADER}}"
      s = index($0, r)
      $0 = substr($0, 1, s-1) header substr($0, s + length(r))
    }

    /{{CONTENT}}/ { 
      r = "{{CONTENT}}"
      s = index($0, r)
      $0 = substr($0, 1, s-1) main substr($0, s + length(r))
    }

    /{{FOOTER}}/ { 
      r = "{{FOOTER}}"
      s = index($0, r)
      $0 = substr($0, 1, s-1) footer substr($0, s + length(r))
    }


    /{{TITLE}}/ { sub(/{{TITLE}}/, title) }

    { print $0 }' \
    "$title" \
    "$header" \
    "$main" \
    "$footer" \
    'template.html' > "$target"
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
    content="$(awk '{gsub(/\\n/, "\n"); print $0;}' <<< "$subtitle""\n""$content" |
        $MD_CONVERT -f gfm -t html |
        awk '
      {
        gsub(/&/,  "\\&amp;", $0);
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
index_tsv | sort -r -t $'\t' -k4,4 > "$TARGET"/index.tsv # Use tab as seperator
index_html "$TARGET"/index.tsv > "$TARGET"/index.html
create_dirs

while read -r f title subtitle created updated content; do
  create_page "$f" "$title" "$subtitle" "$created" "$updated" "$content" || exit 1
done < "$TARGET"/index.tsv

atom_xml "$TARGET"/index.tsv > "$TARGET"/atom.xml
cp style.css "$TARGET"/style.css
