SHELL = /bin/sh

# Directories are intentionally not managed by variables for better 
DATE              := $(shell date -I)
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
SOURCE_INDEX			:= $(SOURCE)/index.md

# Targets
TARGET_DIRS				:= $(subst $(SOURCE),$(BUILD),$(SOURCE_DIRS))
TARGET_DOCS				:= $(patsubst $(SOURCE)/%,$(BUILD)/%,$(SOURCE_DOCS:.md=.html))
TARGET_CSS				:= $(patsubst $(SOURCE)/%,$(BUILD)/%,$(SOURCE_CSS))
TARGET_ASSETS			:= $(patsubst $(SOURCE)/%,$(BUILD)/%,$(SOURCE_ASSETS))
TARGET_INDEX			:= $(BUILD)/index.html

# HTML templates
PAGE_TPL					:= page.html
INDEX_TPL					:= index.html

# Pandoc
PANDOC						:= pandoc 
PANDOC_SHARED_OPT	:= -f gfm \
										 -t markdown-smart \
										 --standalone \
										 --to html5 \
										 --highlight-style tango \
										 --from=markdown+yaml_metadata_block
PANDOC_HTML_OPT		:= --css $(CSS_DIR)/style.css
PANDOC_PAGE_TPL		:= --template $(TPL)/$(PAGE_TPL)
PANDOC_INDEX_TPL	:= --template $(TPL)/$(INDEX_TPL)
PANDOC_METADATA		:= --metadata author="Max Hönig"

.PHONY: all
all: $(BUILD) \
     $(TARGET_DIRS) \
     $(TARGET_CSS) \
     $(TARGET_ASSETS) \
     $(TARGET_DOCS) \
     $(BUILD)/index.html \
     $(BUILD)/atom.xml

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
$(BUILD)/%.html: $(SOURCE)/%.md $(TPL)/$(PAGE_TPL)
	@printf "Converting $(notdir $<) >>> $(notdir $@)\n"
	@$(PANDOC) \
		$(PANDOC_SHARED_OPT) \
		$(PANDOC_PAGE_TPL) \
		$(PANDOC_HTML_OPT) \
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
		$< -o $@ 2> /dev/null

.INTERMEDIATE: atom.xml index.yaml
index.yaml: index.sh $(TPL)/atom.xml $(SOURCE_DOCS) $(TPL)/$(INDEX_TPL)
	@./index.sh 

atom.xml: index.sh $(TPL)/atom.xml $(SOURCE_DOCS) $(TPL)/$(INDEX_TPL)
	@./atom.sh 

# Create index.html
$(BUILD)/index.html: index.yaml
	@echo 'Building index.html...'
	@$(PANDOC) \
		$(PANDOC_SHARED_OPT) \
		--metadata-file index.yaml \
    --metadata description="Personal Website of Max Hönig" \
		-V site-title="mxngls.github.io" \
		$(PANDOC_INDEX_TPL) \
    $(PANDOC_HTML_OPT) \
		$(PANDOC_METADATA) \
		$(SOURCE_INDEX) \
		-o $(TARGET_INDEX)

# Build the atom feed
$(BUILD)/atom.xml: atom.xml
	@echo 'Creating building atom feed...'
	@cp $(TPL)/atom.xml $(BUILD)/atom.xml
	@sed -i -r \
			-e '/\$$entries\$$/r atom.xml' \
			-e '/\$$entries\$$/d' \
			-e "s/\\\$$updated\\\$$/$$(date +"%Y-%m-%dT%H:%M:%SZ")/" \
			$(BUILD)/atom.xml 

# Deploy
.PHONY: deploy
deploy: clean all

# Clean the build directory
.PHONY: clean
clean:
	rm -rf $(BUILD)
