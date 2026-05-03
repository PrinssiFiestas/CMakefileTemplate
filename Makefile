# -----------------------------------------------------------------------------
# MIT License
# Copyright (c) 2026 Lauri Lorenzo Fiestas
# https://github.com/PrinssiFiestas/MSL/blob/main/LICENSE
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Public Targets

.PHONY: release # optimized build (default)
.PHONY: debug   # debug build with sanitizers when available
.PHONY: clean   # remove build artifacts

.PHONY: tests   # build and run debug build tests
.PHONY: build_tests
.PHONY: run_tests

.PHONY: release_tests # build and run release build tests
.PHONY: build_release_tests
.PHONY: run_release_tests

# -----------------------------------------------------------------------------
# Common Variables

# Output executable is either release or debug build depending which one was
# built last.
NAME        = foo # CHANGE ME
EXE         = ./$(NAME)$(EXE_EXT)
RELEASE_EXE = ./build/release/$(NAME)$(EXE_EXT)
DEBUG_EXE   = ./build/debug/$(NAME)$(EXE_EXT)

CC = gcc

EXTRA_CFLAGS = # additional flags from command line
CFLAGS = -Wall -Wextra -D_GNU_SOURCE $(EXTRA_CFLAGS)
LFLAGS = # link flags
TEST_CFLAGS = -Werror -no-pie # -no-pie prevents some sanitizer crashes

DEBUG_CFLAGS   = -ggdb3 -gdwarf
RELEASE_CFLAGS = -O3 -DNDEBUG

SRCS = $(wildcard src/*.c)
TEST_SRCS = $(wildcard tests/test_*.c)

RELEASE_OBJS = $(patsubst src/%.c,build/release/%.o,$(SRCS))
RELEASE_OBJS_NO_MAIN = $(filter-out build/release/main.o,$(RELEASE_OBJS))

RELEASE_TEST_OBJS = $(patsubst tests/test_%.c,build/release/test_%.o,$(TEST_SRCS))
RELEASE_TESTS     = $(patsubst build/release/test_%.o,build/release/test_%$(EXE_EXT),$(RELEASE_TEST_OBJS))
.PRECIOUS: $(RELEASE_TESTS)

DEBUG_OBJS = $(patsubst src/%.c,build/debug/%.o,$(SRCS))
DEBUG_OBJS_NO_MAIN = $(filter-out build/debug/main.o,$(DEBUG_OBJS))

DEBUG_TEST_OBJS = $(patsubst tests/test_%.c,build/debug/test_%.o,$(TEST_SRCS))
DEBUG_TESTS     = $(patsubst build/debug/test_%.o,build/debug/test_%$(EXE_EXT),$(DEBUG_TEST_OBJS))
.PRECIOUS: $(DEBUG_TESTS)

# Multithreaded build by default
NPROC        = $(shell echo `nproc`)
THREAD_COUNT = $(if $(NPROC),$(NPROC),4)
MAKEFLAGS   += -j$(THREAD_COUNT)

ifeq ($(OS), Windows_NT)
    EXE_EXT = .exe
else
    SANITIZERS = -fsanitize=address -fsanitize=leak -fsanitize=undefined
    ifeq ($(CC), gcc)
        DEBUG_CFLAGS += -static-libasan -fno-sanitize-recover=all
    else ifeq ($(CC), clang)
        DEBUG_CFLAGS += -static-libsan -fsanitize-trap=all
    endif
endif

# -----------------------------------------------------------------------------
# Rules

-include $(RELEASE_OBJS:.o=.d)
-include $(DEBUG_OBJS:.o=.d)

release: CFLAGS += $(RELEASE_CFLAGS)
release: $(RELEASE_EXE)

debug: CFLAGS += $(DEBUG_CFLAGS) $(SANITIZERS)
debug: $(DEBUG_EXE)

$(RELEASE_EXE): $(RELEASE_OBJS)
	$(CC) -o $@ $(CFLAGS) $(LFLAGS) $(RELEASE_OBJS)
	cp $@ .

$(RELEASE_OBJS): build/release/%.o: src/%.c
	@mkdir -p build/release
	$(CC) -o $@ -c -MMD -MP $(CFLAGS) $<

release_tests: MAKEFLAGS= # prevent jobserver issues
release_tests:
	$(MAKE) build_release_tests
	$(MAKE) run_release_tests
	@echo Release build tests PASSED!

build_release_tests: CFLAGS += $(DEBUG_CFLAGS) $(SANITIZERS)
build_release_tests: $(RELEASE_TESTS)

# Test sources #include C sources, so we link with all objects except current.
$(RELEASE_TESTS): build/release/test_%$(EXE_EXT): tests/test_%.c $(RELEASE_OBJS_NO_MAIN)
	$(CC) -o $@ $(CFLAGS) $(LFLAGS) $(filter-out $(patsubst tests/test_%.c,build/release/%.o,$<), $^)

run_release_tests:
	@echo $(RELEASE_TESTS)
	@for test in $(RELEASE_TESTS) ; do \
		./$$test || exit 1 ; \
		echo ; \
	done

$(DEBUG_EXE): $(DEBUG_OBJS)
	$(CC) -o $@ $(CFLAGS) $(LFLAGS) $(DEBUG_OBJS)
	cp $@ .

$(DEBUG_OBJS): build/debug/%.o: src/%.c
	@mkdir -p build/debug
	$(CC) -o $@ -c -MMD -MP $(CFLAGS) $<

tests: MAKEFLAGS= # prevent jobserver issues
tests:
	$(MAKE) build_tests
	$(MAKE) run_tests
	@echo Debug build tests PASSED!

build_tests: CFLAGS += $(DEBUG_CFLAGS) $(SANITIZERS)
build_tests: $(DEBUG_TESTS)

# Test sources #include C sources, so we link with all objects except current.
$(DEBUG_TESTS): build/debug/test_%$(EXE_EXT): tests/test_%.c $(DEBUG_OBJS_NO_MAIN)
	$(CC) -o $@ $(CFLAGS) $(LFLAGS) $(filter-out $(patsubst tests/test_%.c,build/debug/%.o,$<), $^)

run_tests:
	@echo $(DEBUG_TESTS)
	@for test in $(DEBUG_TESTS) ; do \
		./$$test || exit 1 ; \
		echo ; \
	done

clean:
	rm -rf build $(EXE)
