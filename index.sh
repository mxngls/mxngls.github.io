#!/bin/bash

SRC_DIR='src'
INDEX_YML='index.yaml'
SECTION_TITLE='Writing'
SECTION_SUBTITLE='Everything longer than 280 characters'

echo "title: $SECTION_TITLE" > $INDEX_YML
echo "subtitle: $SECTION_SUBTITLE" >> $INDEX_YML
echo "posts:" >> $INDEX_YML

SRC_DOCS=$(find "$SRC_DIR" \
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
  index_date=$(date -d "$date" +"%Y %b")

  # Check for missing meta data
  if [ -z "$title" ]; then
    printf "Error: Missing title in %s\n" "$filename"
    exit 1
  elif [ -z "$date" ]; then
    printf "Error: Missing date in %s\n" "$filename"
    exit 1
  fi

  {
    printf "  %s\n  %s\n  %s\n" \
      "- title: $title" \
      "  date: $index_date" \
      "  path: $(basename "${filename%.*}.html")";
  } >> "$INDEX_YML"

done < <(echo "${SRC_DOCS[@]}")

exit 0
