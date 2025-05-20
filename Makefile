SHELL = /bin/sh

_SITE_EXT_TARGET_DIR ?= docs/

COMPILER = clang

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
-D_FORTIFY_SOURCE=2 \
-D_SITE_EXT_TARGET_DIR=\"$(_SITE_EXT_TARGET_DIR)\"

# deploy
deploy: clean build

# build
build: 
	@printf "%s\n" "Generating pages..."
	@$(COMPILER) $(COMPILER_FLAGS) build.c -o build.out
	@./build.out
	@printf "%s\n" "Done."

# clean the build directory
clean:
	@printf "%s\n" "Removing build archive."
	@if [ -d "$(_SITE_OUT_DIR)" ]; then find "$(_SITE_OUT_DIR)" -mindepth 1 -delete; fi
	@printf "%s\n" "Done."
	
.PHONY: build clean deploy
