SHELL := /bin/bash
.DEFAULT_GOAL := help

TF      ?= terraform
TF_DIRS := $(sort $(dir $(wildcard terraform/modules/*/main.tf terraform/envs/*/main.tf)))
TF_TEST := $(sort $(patsubst %/tests/,%,$(dir $(wildcard terraform/*/*/tests/*.tftest.hcl))))

.PHONY: help terraform tftest tflint lint security check clean

help: ## Show this help
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z_-]+:.*## / {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

terraform: ## fmt-check + init + validate every module and environment
	$(TF) fmt -check -recursive
	@set -e; for d in $(TF_DIRS); do \
		echo "==> $$d"; \
		$(TF) -chdir=$$d init -backend=false -input=false >/dev/null; \
		$(TF) -chdir=$$d validate; \
	done

tftest: ## terraform test with mocked providers (no Azure credentials needed)
	@set -e; for d in $(TF_TEST); do \
		echo "==> $$d"; \
		$(TF) -chdir=$$d init -backend=false -input=false >/dev/null; \
		$(TF) -chdir=$$d test; \
	done

tflint: ## tflint with the azurerm ruleset
	tflint --init --config=$(CURDIR)/.tflint.hcl
	@set -e; for d in $(TF_DIRS); do \
		echo "==> $$d"; \
		tflint --chdir=$$d --config=$(CURDIR)/.tflint.hcl; \
	done

lint: ## yamllint
	yamllint -s .

security: ## trivy config scan (HIGH/CRITICAL)
	trivy config --severity HIGH,CRITICAL --exit-code 1 --skip-dirs '**/.terraform' .

check: terraform tftest lint ## Everything CI runs (except tflint and trivy)

clean: ## Remove Terraform caches
	find terraform -type d -name .terraform -prune -exec rm -rf {} +
