# ReqPack wrapper plugins (letter-grouped monorepo)
ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SCRIPTS := $(ROOT)/scripts
LEGACY_ROOT ?= $(HOME)/Dev/Coditary/plugins/reqpack
RQ ?= rqp
RQ_CONFIG ?=

.PHONY: help import validate validate-strict list list-bucket find path test-plugin test-plugin-core count clean-git

help:
	@echo "Targets:"
	@echo "  make import              Copy from LEGACY_ROOT (default: ~/Dev/Coditary/plugins/reqpack)"
	@echo "  make migrate-registry REGISTRY=/path/to/rqp-registry  Update registry JSON sources"
	@echo "  make validate            Check all plugins (required files + metadata)"
	@echo "  make validate-strict     validate + fail on metadata.name != folder name"
	@echo "  make list                List all plugin ids"
	@echo "  make list-bucket B=n     List plugins in bucket B"
	@echo "  make find Q=npm          Find plugins matching substring Q"
	@echo "  make path PLUGIN=npm     Print filesystem path for plugin id"
	@echo "  make test-plugin PLUGIN=npm   Run rqp test-plugin on one plugin"
	@echo "  make test-plugin-core PLUGIN=npm  Same with --preset core"
	@echo "  make count               Count plugins"

import:
	@LEGACY_ROOT="$(LEGACY_ROOT)" bash "$(SCRIPTS)/import-legacy.sh"
	@$(MAKE) validate

REGISTRY ?=
migrate-registry:
	@test -n "$(REGISTRY)" || (echo "usage: make migrate-registry REGISTRY=/path/to/rqp-registry" >&2; exit 1)
	@python3 "$(SCRIPTS)/migrate-registry-sources.py" "$(REGISTRY)"

validate:
	@python3 "$(SCRIPTS)/validate-plugins.py"

validate-strict:
	@python3 "$(SCRIPTS)/validate-plugins.py" --strict

count:
	@find "$(ROOT)" -mindepth 2 -maxdepth 2 -type f -name run.lua | wc -l

list:
	@find "$(ROOT)" -mindepth 2 -maxdepth 2 -type f -name run.lua | sed 's|.*/\([^/]*\)/run.lua|\1|' | sort

list-bucket:
	@test -n "$(B)" || (echo "usage: make list-bucket B=n" >&2; exit 1)
	@find "$(ROOT)/$(B)" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sed 's|.*/||' | sort

find:
	@test -n "$(Q)" || (echo "usage: make find Q=substring" >&2; exit 1)
	@$(MAKE) -s list | grep -i "$(Q)" || true

path:
	@test -n "$(PLUGIN)" || (echo "usage: make path PLUGIN=npm" >&2; exit 1)
	@python3 "$(SCRIPTS)/resolve-plugin.py" "$(PLUGIN)"

test-plugin:
	@test -n "$(PLUGIN)" || (echo "usage: make test-plugin PLUGIN=npm" >&2; exit 1)
	@p="$$(python3 "$(SCRIPTS)/resolve-plugin.py" "$(PLUGIN)")"; \
	if [[ -n "$(RQ_CONFIG)" ]]; then \
	  $(RQ) --config "$(RQ_CONFIG)" test-plugin --plugin "$$p"; \
	else \
	  $(RQ) test-plugin --plugin "$$p"; \
	fi

test-plugin-core:
	@test -n "$(PLUGIN)" || (echo "usage: make test-plugin-core PLUGIN=npm" >&2; exit 1)
	@p="$$(python3 "$(SCRIPTS)/resolve-plugin.py" "$(PLUGIN)")"; \
	if [[ -n "$(RQ_CONFIG)" ]]; then \
	  $(RQ) --config "$(RQ_CONFIG)" test-plugin --plugin "$$p" --preset core; \
	else \
	  $(RQ) test-plugin --plugin "$$p" --preset core; \
	fi

clean-git:
	@find "$(ROOT)" -name .git -type d -prune -exec rm -rf {} + 2>/dev/null || true
	@echo "removed nested .git directories"
