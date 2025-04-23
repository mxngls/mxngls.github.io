#!/bin/bash

# constants
SITE_SOURCE='src'
SITE_TARGET="${SITE_OUT:-docs}"
MD_CONVERT='pandoc'
TITLE="max's site"
HOST="maxh.site"
URL="https://$HOST"

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
            --date='format:%Y-%m-%d' \
            "$f" 2>/dev/null |
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
    done < <(find "$SITE_SOURCE" -type f -name '*.md' -not -path "$SITE_SOURCE/drafts/*")
}

index_html() {
    content="$(<"$SITE_SOURCE"/index.html)"

    while read -r f title subtitle created updated; do
        d="$(dirname "$f")"
        ref="${f//$SITE_SOURCE/$SITE_TARGET}"
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
    done <"$1"

    content+="$(printf '
        <hr>
        <div>
            <h2>Posts</h2>
            <section>
                <h4 style="margin-bottom: 0.2em;">Weblog</h4>
                <span style="font-size: 95%%;">
                    Occasionally shared writings that feel hard to categorize
                </span> 
                <div style="margin: 1em 0;">
                    <table>
                        <tbody>
                            %s
                        </tbody>
                    </table>
                </div>
            </section>
            <section>
                <h4 style="margin-bottom: 0.2em;">Notes</h4>
                <span style="font-size: 95%%;">
                    Things I worked on in the past or that I am still tinkering with: 
                </span> 
                <div style="margin: 1em 0;">
                    <table>
                        <tbody>
                            %s
                        </tbody>
                    </table>
                </div>
            </section>
        </div>
    ' "$posts" "$notes")"

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
    for d in "$SITE_SOURCE"/*; do
        if [[ -d "$d" ]] && [[ ! "$d" =~ "drafts" ]]; then
            local dir="${d/$SITE_SOURCE/$SITE_TARGET}"
            mkdir "$dir" &>/dev/null
        fi
    done
}

create_page() {
    if [[ "$#" -ne 6 ]]; then
        echo "Invalid number of arguments: $#. Expected six."
        return 1
    fi

    tmp_target="${1/%.md/.html}"
    target="${tmp_target//$SITE_SOURCE/$SITE_TARGET}"

    title="$2"
    subtitle="$3"

    date_created="<div id=\"date-created\" style=\"margin: 2rem 0;\"><a href="/">${4}</a></div>"
    date_updated="<div id=\"date-updated\" style=\"color: #696969; margin: 2rem 0;\"><small>Last Updated on ${5}</small></div>"
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
        'template.html' >"$target"
}

atom_xml() {
    # https://stackoverflow.com/a/5189296/13490131
    since="$(git log --max-parents=0 HEAD --format='%aI')"
    updated="$(awk -v FS="$IFS" 'NR == 1 { print $5; exit;}' "$1")"
    updated="${updated}T00:00:00Z"

    uri="$URL""/atom.xml"

    cat <<EOF
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

        t="${f//$SITE_SOURCE/$SITE_TARGET}"

        # format date to use it as part of a valid URI tag
        post_updated="${created//\//-}"

        # make dates RFC-3339 compliant
        created="${created}T00:00:00Z"
        updated="${updated}T00:00:00Z"

        content="$(
            awk '{gsub(/\\n/, "\n"); print $0;}' <<<"$subtitle""\n""$content" |
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

        cat <<EOF
    <entry>
      <title>$title</title>
      <content type="html">$content</content>
        <link href="${f##"$SITE_SOURCE"/}"/>
      <id>tag:www.$HOST,$post_updated:$t</id>
      <published>$created</published>
      <updated>$updated</updated>
    </entry>
EOF
    done <"$1"

    echo '</feed>'
}

mkdir -p "$SITE_TARGET"
index_tsv | sort -r -t $'\t' -k4,4 >"$SITE_TARGET"/index.tsv # Use tab as seperator
index_html "$SITE_TARGET"/index.tsv >"$SITE_TARGET"/index.html
create_dirs

while read -r f title subtitle created updated content; do
    create_page "$f" "$title" "$subtitle" "$created" "$updated" "$content" || exit 1
done <"$SITE_TARGET"/index.tsv

atom_xml "$SITE_TARGET"/index.tsv >"$SITE_TARGET"/atom.xml
cp style.css "$SITE_TARGET"/style.css
cp -R assets "$SITE_TARGET"
