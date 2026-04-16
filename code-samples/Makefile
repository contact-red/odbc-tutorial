BUILD_DIR ?= build
SAMPLES := $(notdir $(shell find . -maxdepth 1 -type d -name '[0-9][0-9]-*' | sort))
BINARIES := $(addprefix $(BUILD_DIR)/,$(SAMPLES))

all: $(BINARIES)

deps:
	corral fetch

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/%: %/*.pony | $(BUILD_DIR) deps
	corral run -- ponyc -o $(BUILD_DIR) $*

clean:
	corral clean
	rm -rf $(BUILD_DIR)

list:
	@printf '%s\n' $(SAMPLES)

.PHONY: all deps clean list
