SHELL = /bin/sh

SITE_SOURCE := src
SITE_OUT ?= docs 

# deploy
deploy: clean build

# build
build: 
	@printf "%s\n" "Generating pages..."
	@./build.sh
	@printf "%s\n" "Done."

# clean the build directory
clean:
	@printf "%s\n" "Removing build archive."
	@if [ -d "$(SITE_OUT)" ]; then rm -v -I -r "$(SITE_OUT)"; fi
	@printf "%s\n" "Done."
	
.PHONY: build clean deploy
