SHELL = /bin/sh

# Directories are intentionally not managed by variables for better 
SOURCE						:= src
BUILD							:= docs
TPL								:= templates
ASSETS						:= assets
CSS_DIR						:= css

# Prerequisites
SOURCE_DIRS				:= $(shell find $(SOURCE) \
										 -type d \
										 -mindepth 1 \
										 -not -path '$(SOURCE)/drafts'\
										 )
SOURCE_DOCS				:= $(shell find $(SOURCE) \
										 -type f \
										 -name '*.md' \
										 -not -path '$(SOURCE)/drafts/*'\
										 )
SOURCE_CSS				:= $(wildcard $(SOURCE)/$(CSS_DIR)/*.css)
SOURCE_ASSETS			:= $(wildcard $(SOURCE)/$(ASSETS)/*)

# Targets
TARGET_DIRS				:= $(subst $(SOURCE),$(BUILD),$(SOURCE_DIRS))
TARGET_DOCS				:= $(patsubst $(SOURCE)/%,$(BUILD)/%,$(SOURCE_DOCS:.md=.html))
TARGET_CSS				:= $(patsubst $(SOURCE)/%,$(BUILD)/%,$(SOURCE_CSS))
TARGET_ASSETS			:= $(patsubst $(SOURCE)/%,$(BUILD)/%,$(SOURCE_ASSETS))

# HTML templates
PAGE_TPL					:= page.html
INDEX_TPL					:= index.html

# Pandoc
PANDOC_VERSION		:= 3.1.9
PANDOC						:= pandoc 
PANDOC_SHARED_OPT	:= -f gfm \
										 -t markdown-smart \
										 --standalone \
										 --to html5 \
										 --highlight-style tango \
										 --from=markdown+yaml_metadata_block
PANDOC_BEFORE     := --include-before-body $(SOURCE)/header.html
PANDOC_HTML_OPT		:= -M \
										 --document-css=false \
										 --css $(CSS_DIR)/style.css
PANDOC_PAGE_TPL		:= --template $(TPL)/$(PAGE_TPL)
PANDOC_INDEX_TPL	:= --template $(TPL)/$(INDEX_TPL)
PANDOC_METADATA		:= --metadata title-author="Max"

.PHONY: all
all: $(BUILD) \
     $(BUILD)/index.html \
     $(TARGET_DIRS) \
     $(TARGET_CSS) \
     $(TARGET_ASSETS) \
     $(TARGET_DOCS)

# Create directories to hold CSS and other assets
$(BUILD):
	mkdir -p $(BUILD)/$(CSS_DIR)
	mkdir -p $(BUILD)/$(ASSETS)
	
# Build all necessary target directories for source docs
$(TARGET_DIRS):
	mkdir -p $@

# Copy CSS files into the build directory
$(BUILD)/%.css: $(SOURCE)/%.css
	cp $< $@

# Copy other assets into the build directory
$(BUILD)/%: $(SOURCE)/%
	cp $< $@

# Convert Markdown to HTML
$(BUILD)/%.html: $(SOURCE)/%.md $(TPL)/$(PAGE_TPL) $(SOURCE)/header.html
	@printf "Converting $(notdir $<) >>> $(notdir $@)\n"
	@$(PANDOC) \
		$(PANDOC_SHARED_OPT) \
		$(PANDOC_PAGE_TPL) \
		$(PANDOC_HTML_OPT) \
		$(PANDOC_BEFORE) \
		$(PANDOC_METADATA) \
		--variable="date:$$(grep -h -w -m 1 'date:' $< | \
			sed -e 's/date:[[:space:]]*//g' | \
			tr -d \" | \
			{ read DATE; date -d $$DATE +'%a, %-e %B %Y'; } \
			2> /dev/null)" \
		--variable="modified-date:$$(git log \
			-1 \
			--date='format:%a, %e %B %G' \
      --format='%cd' \
			$< | \
			sed -e 's/-/\//g' 2> /dev/null)" \
		$< -o $@ \
		2> /dev/null

# Source metadata from all files
.INTERMEDIATE: index.yaml
index.yaml: index.sh $(SOURCE_DOCS) $(TPL)/$(INDEX_TPL) $(SOURCE)/header.html
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
		$(PANDOC_BEFORE) \
		$(PANDOC_METADATA) \
		-o $(BUILD)/index.html /dev/null

# Deploy
.PHONY: deploy
deploy: clean all

# Clean the build directory
.PHONY: clean
clean:
	rm -rf $(BUILD)
