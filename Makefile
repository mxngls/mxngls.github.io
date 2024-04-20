SHELL = /bin/sh

SOURCE := src
TARGET := docs

# build
build: 
	@printf "%s\n" "Generting pages..."
	@./build.sh
	@printf "%s\n" "Done."

# clean the build directory
clean:
	@printf "%s\n" "Removing build archive."
	@rm -rf $(TARGET)
	@printf "%s\n" "Done."
	
# deploy
deploy: clean build

.PHONY: build clean deploy
