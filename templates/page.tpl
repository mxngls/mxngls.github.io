<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" lang="$lang$" xml:lang="$lang$"$if(dir)$ dir="$dir$"$endif$>
  <head>
    <meta charset="utf-8" />
    <meta name="generator" content="pandoc" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=yes" />
    <meta name="author" content="$author-meta$" />
    <meta name="dcterms.date" content="$date-meta$" />
  $if(description-meta)$
    <meta name="description" content="$description-meta$" />
  $endif$
    <title>$pagetitle$</title>
    <style>
      $styles.html()$
    </style>
    <link rel="stylesheet" href="$css$" />
    $for(header-includes)$
      $header-includes$
    $endfor$
  </head>
  <body>
    $for(include-before)$
    $include-before$
    $endfor$
    $if(title)$
    <header id="title-block-header">
      <h1 class="title">$title$</h1>
      $if(date)$
      <p class="date">created at $date$</p>
      $endif$
    </header>
    $endif$
    $body$
    $for(include-after)$
      $include-after$
    $endfor$
  </body>
</html>
