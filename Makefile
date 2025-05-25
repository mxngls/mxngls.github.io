.POSIX:

SHELL = /bin/sh

_SITE_EXT_TARGET_DIR ?= docs/

COMPILER = clang

LIBGIT2_VERSION = v1.9.0
LIBGIT2_DIR = deps/libgit2
LIBGIT2_BUILD = $(LIBGIT2_DIR)/build
LIBGIT2_LIB = $(LIBGIT2_BUILD)/libgit2.a

# run on FreeBSD
SYSTEM_LIBS = -lz -lssl -lcrypto -L/usr/local/lib -lpcre

COMPILER_FLAGS = \
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
-D_SITE_EXT_TARGET_DIR=\"$(_SITE_EXT_TARGET_DIR)\" \
-I$(LIBGIT2_DIR)/include

LINKER_FLAGS = $(LIBGIT2_LIB) $(SYSTEM_LIBS)

# deploy
deploy: clean build

# build
build: $(LIBGIT2_LIB)
	@printf "%s\n" "Generating pages..."
	@$(COMPILER) $(COMPILER_FLAGS) build.c $(LINKER_FLAGS) -o build.out
	@./build.out
	@printf "%s\n" "Done."

# Download and build libgit2
$(LIBGIT2_LIB):
	@printf "%s\n" "Setting up libgit2..."
	@mkdir -p deps
	@if [ ! -d "$(LIBGIT2_DIR)" ]; then \
		printf "%s\n" "Downloading libgit2 $(LIBGIT2_VERSION)..."; \
		wget -q https://github.com/libgit2/libgit2/archive/$(LIBGIT2_VERSION).tar.gz --output-document deps/libgit2.tar.gz; \
		tar -xzf deps/libgit2.tar.gz -C deps; \
		mv deps/libgit2-* $(LIBGIT2_DIR); \
		rm deps/libgit2.tar.gz; \
	fi
	@mkdir -p $(LIBGIT2_BUILD)
	@cd $(LIBGIT2_BUILD) && cmake .. -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTS=OFF
	@cd $(LIBGIT2_BUILD) && cmake --build .
	@printf "%s\n" "libgit2 setup complete."

# clean the build directory
clean:
	@printf "%s\n" "Removing build artifacts..."
	@if [ -d "$(_SITE_OUT_DIR)" ]; then find "$(_SITE_OUT_DIR)" -mindepth 1 -delete; fi
	@if [ -f "build.out" ]; then rm build.out; fi
	@rm -f build.o
	@printf "%s\n" "Done."

# deep clean including dependencies
distclean: clean
	@printf "%s\n" "Removing dependencies..."
	@rm -rf deps
	@printf "%s\n" "Done."
	
.PHONY: build clean deploy distclean
