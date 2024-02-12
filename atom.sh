#!/bin/bash

SOURCE_DIR='src'
BUILD_DIR='docs'
ATOM="atom.xml"
LINK="https://mxngls.github.io"

SOURCE_DOCS=$(find "$SOURCE_DIR" \
  -not -name 'index.md' \
  -maxdepth 1 \
  -name '*.md' \
  -print0 \
  | xargs -0 -I {} sh -c \
    "sed -rnE 's/date: \"([0-9]{4}\/[0-9]{2}\/[0-9]{2})\"/\\1 /p' {} \
    | { read date; echo {} \$date; }" \
  | sort -r -t ' ' -k 2
)

# Sort the pairs after their creation date and parse the relating meta 
# data
while IFS='' read -r doc; do
  IFS=' ' read -r filename date <<< "${doc[@]}"

  title="$(sed -n -r 's/^title: "(.*)"/\1/p' "$filename")"
  atom_date=$(date -d "$date" +"%Y-%m-%dT%H:%M:%SZ")
  link="$LINK/$(basename "${filename%.*}.html")"

  # Check for missing meta data
  if [ -z "$title" ]; then
    printf "Error: Missing title in %s\n" "$filename"
    exit 1
  elif [ -z "$date" ]; then
    printf "Error: Missing date in %s\n" "$filename"
    exit 1
  fi

  filename_out="${filename%.*}.html"
  filename_out="${filename_out/$SOURCE_DIR/$BUILD_DIR}"
  escaped_html="$(sed \
    -e 's/&/\&amp;/g' \
    -e 's/</\&lt;/g' \
    -e 's/>/\&gt;/g' \
    -e 's/"/\&quot;/g' \
    -e 's/'"'"'/\&#39;/g' \
    "$filename_out")"

  
  {
    printf "    <entry>\n%s\n%s\n%s\n%s\n%s\n    </entry>\n" \
      "     <title>$title</title>" \
      "     <link rel=\"alternate\" type=\"text/html\" href=\"$link\"/>" \
      "     <id>$link</id>" \
      "     <published>$atom_date</published>" \
      "     <content type=\"html\">$escaped_html</content>"
  } >> "$ATOM"

done < <(echo "${SOURCE_DOCS[@]}")

exit 0

