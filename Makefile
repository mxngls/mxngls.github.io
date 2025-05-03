SHELL = /bin/sh

SITE_SOURCE := src
SITE_OUT ?= docs 

COMPILER_FLAGS = -xc \
-std=c99 \
-fsanitize=undefined \
-Wall \
-Wextra \
-Wconversion \
-Wno-sign-conversion \
-Wdouble-promotion \
-Werror \
-Wpedantic \
-Wpointer-arith \
-D_FORTIFY_SOURCE=2

# deploy
deploy: clean build

# build
build: 
	@printf "%s\n" "Generating pages..."
	@gcc $(COMPILER_FLAGS) build.c -o build.out
	@./build.out
	@printf "%s\n" "Done."

# clean the build directory
clean:
	@printf "%s\n" "Removing build archive."
	@if [ -d "$(SITE_OUT)" ]; then find "$(SITE_OUT)" -mindepth 1 -delete; fi
	@printf "%s\n" "Done."
	
.PHONY: build clean deploy
