SHELL = /bin/sh

# Directories are intentionally not managed by variables for better 
SOURCE						:= src
BUILD							:= html
TPL								:= templates

# Source and target files
SOURCE_DOCS				:= $(wildcard $(SOURCE)/*.md)
SOURCE_CSS				:= $(wildcard *.css)

EXPORTED_DOCS			:= $(addprefix $(BUILD)/,$(notdir $(SOURCE_DOCS:.md=.html)))
EXPORTED_CSS			:= $(addprefix $(BUILD)/css/,$(notdir $(SOURCE_CSS)))

# Pandoc related stuff
PANDOC_VERSION		:= 3.1.9
PANDOC						:= pandoc 
PANDOC_SHARED_OPT	:= -f gfm \
										 -t markdown-smart \
										 --standalone \
										 --to html5 \
										 --highlight-style tango \
										 --from=markdown+yaml_metadata_block
PANDOC_HTML_OPT		:= --include-before-body header.html \
										 -M \
										 --document-css=false \
										 --css css/style.css
PANDOC_PAGE_TPL		:= --template $(TPL)/page.tpl 
PANDOC_INDEX_TPL	:= --template $(TPL)/index.tpl 
PANDOC_METADATA		:= --metadata title-author="Max"

# Convert to upper case
uppercase = $(shell echo '$*' | perl -nE 'say ucfirst')

.PHONY: all
all: $(BUILD) $(EXPORTED_CSS) $(EXPORTED_DOCS) $(BUILD)/index.html

# In case the Makefile itself changes
all: .EXTRA_PREREQS := $(abspath $(lastword $(MAKEFILE_LIST)))

# Create directory to hold CSS and HTML files
html:
	@echo 'Creating directory for css files...'
	mkdir -p $(BUILD)/css

# Copy CSS files into the build directory
$(BUILD)/css/%.css: %.css
	@echo 'Copying css files...'
	cp $< $@

# Convert Markdown to HTML
$(BUILD)/%.html: $(SOURCE)/%.md header.html | $(BUILD)
	@printf "Converting $(notdir $<) >>> $(notdir $@)\n"
	@$(PANDOC) \
		$(PANDOC_SHARED_OPT) \
		$(PANDOC_PAGE_TPL) \
		$(PANDOC_HTML_OPT) \
		$(PANDOC_METADATA) \
		--variable="modified-date:$$(date '+%Y-%m-%d')" \
		$< -o $@

# Source metadata from all files
.INTERMEDIATE: index.yaml
index.yaml: index.sh $(TPL)/index.tpl $(SOURCE_DOCS)
	@echo 'Parsing metadata...'
	@./index.sh

# Create index.html
$(BUILD)/index.html: index.yaml
	@echo 'Building index.html...'
	@$(PANDOC) \
		$(PANDOC_SHARED_OPT) \
		--metadata-file index.yaml \
		$(PANDOC_INDEX_TPL) \
		$(PANDOC_HTML_OPT) \
		$(PANDOC_METADATA) \
		-o html/index.html /dev/null

# Make sure we rebuild the index when source files change
$(BUILD)/index.html: $(patsubst $(SRC)/%.md,$(BUILD)/%.html,$(wildcard $(SRC)/*.md))

# Clean the build directory
.PHONY: clean
clean:
	rm -rf html
