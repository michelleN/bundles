PROJECT         := bundles
ORG             := deislabs
DOCKER_REGISTRY ?= cnab

BASE_DIR        := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

GIT_TAG         := $(shell git describe --tags --always)
VERSION         ?= ${GIT_TAG}
# Replace + with -, for Docker image tag compliance
IMAGE_TAG       ?= $(subst +,-,$(VERSION))
BUNDLE          ?=
DUFFLE_IMG      ?= brigade.azurecr.io/deis/duffle:latest

ifeq ($(OS),Windows_NT)
	SHELL  = cmd.exe
	CHECK  = where.exe
else
	SHELL  ?= bash
	CHECK  = command -v
endif

HAS_DOCKER := $(shell $(CHECK) docker)

.PHONY: default
default:
ifndef HAS_DOCKER
	$(error You must install docker)
endif

.PHONY: check-bundle
check-bundle:
ifndef BUNDLE
	$(error BUNDLE must be provided, e.g., BUNDLE=<bundle> make <target>)
endif

.PHONY: docker-build
docker-build: check-bundle
	docker build -t $(DOCKER_REGISTRY)/$(BUNDLE):$(IMAGE_TAG) $(BUNDLE)/cnab

.PHONY: docker-run
docker-run: check-bundle
	docker run -t $(DOCKER_REGISTRY)/$(BUNDLE):$(VERSION)

.PHONY: docker-push
docker-push: check-bundle
	docker push $(DOCKER_REGISTRY)/$(BUNDLE):$(IMAGE_TAG)

.PHONY: test-functional
test-functional:
	docker run --rm \
		-v ${BASE_DIR}:/src \
		-w /src \
		-e BUNDLE=$(BUNDLE) \
		$(DUFFLE_IMG) ./scripts/test-functional.sh

.PHONY: test-functional-local
test-functional-local:
	./scripts/test-functional.sh

define all
	@for dir in $$(ls -1); do \
		if [[ -e "$$dir/$(1)" ]]; then \
			BUNDLE=$$dir make $(2) ; \
		fi ; \
	done
endef

define docker-all
	$(call all,cnab/Dockerfile,$(1))
endef

.PHONY: docker-build-all
docker-build-all:
	$(call docker-all,docker-build)

.PHONY: docker-push-all
docker-push-all:
	$(call docker-all,docker-push)
