DOTACTION = ./.kustomize-action
DOTACTION_EXISTS := $(shell [ -f $(DOTACTION) ] && echo 0 || echo 1 )

ifeq ($(DOTACTION_EXISTS), 0)
	include $(DOTACTION)
	export $(shell sed 's/=.*//' .kustomize-action)
	DOCKER_IMAGE_TAG := $(tag)
	UPDATED_BRANCH := $(branch)
endif

ifeq ($(UPDATED_BRANCH), "release")
	PATCH_DIR := overlays/staging
	REPOSITORY := https://github.com/cndjp/qicoo-api-manifests-staging.git
else ifeq ($(UPDATED_BRANCH), "master")
	PATCH_DIR := overlays/production
	PATCH_DIR_BASE := $(PATCH_DIR)/spin-base
	PATCH_DIR_CANARY := $(PATCH_DIR)/spin-canary
	REPOSITORY := https://github.com/cndjp/qicoo-api-manifests-production.git
endif

KUSTOMIZE_ACTION_FILE_NAME := kustomize-action.yaml

MANIFEST_DIR := $(HOME)/manifests
MANIFEST_FINAL_NAME_ALL := qicoo-api-all.yaml
MANIFEST_FINAL_NAME_BASE := qicoo-api-base.yaml
MANIFEST_FINAL_NAME_CANARY := qicoo-api-canary.yaml

HUB_VERSION := 2.6.0
KUSTOMIZE_VERSION := 1.0.10

$(MANIFEST_FINAL_NAME_ALL): kustomize-build github-pr

.PHONY: load-kustomize-action
load-kustomize-action:
	sed -e 's/:[^:\/\/]/="/g;s/$$/"/g;s/ *=/=/g' ./kustomize-action.yaml > .kustomize-action

.PHONY: github-setup
github-setup:
	mkdir -p "$(HOME)/.config"
	echo "https://$(GITHUB_TOKEN):@github.com" > "$(HOME)/.config/git-credential"
	echo "github.com:" > "$(HOME)/.config/hub"
	echo "- oauth_token: $(GITHUB_TOKEN)" >> "$(HOME)/.config/hub"
	echo "  user: $(GITHUB_USER)" >> "$(HOME)/.config/hub"
	git config --global user.name "$(GITHUB_USER)"
	git config --global user.email "$(GITHUB_USER)@users.noreply.github.com"
	git config --global core.autocrlf "input"
	git config --global hub.protocol "https"
	git config --global credential.helper "store --file=$(HOME)/.config/git-credential"
	curl -LO "https://github.com/github/hub/releases/download/v$(HUB_VERSION)/hub-linux-amd64-$(HUB_VERSION).tgz"
	tar -C "$(HOME)" -zxf "hub-linux-amd64-$(HUB_VERSION).tgz"

.PHONY: kustomize-setup
kustomize-setup:
	curl -LO "https://github.com/kubernetes-sigs/kustomize/releases/download/v$(KUSTOMIZE_VERSION)/kustomize_$(KUSTOMIZE_VERSION)_linux_amd64"
	chmod +x kustomize_$(KUSTOMIZE_VERSION)_linux_amd64
	mv kustomize_$(KUSTOMIZE_VERSION)_linux_amd64 $(HOME)/kustomize

.PHONY: kustomize-build
kustomize-build:
	$(eval KUSTOMIZE := $(shell echo $(HOME)/kustomize))
	mkdir $(MANIFEST_DIR)
	sed -i -e "s/@@NEW_TAG@@/$(DOCKER_IMAGE_TAG)/g" $(PATCH_DIR)/kustomization.yaml
	$(KUSTOMIZE) build $(PATCH_DIR) -o $(MANIFEST_DIR)/$(MANIFEST_FINAL_NAME_ALL)
	@if test "$(UPDATED_BRANCH)" = "master"; \
		then \
		sed -i -e "s/@@NEW_TAG@@/$(DOCKER_IMAGE_TAG)/g" $(PATCH_DIR_CANARY)/kustomization.yaml; \
		$(KUSTOMIZE) build $(PATCH_DIR_BASE) -o $(MANIFEST_DIR)/$(MANIFEST_FINAL_NAME_BASE); \
		$(KUSTOMIZE) build $(PATCH_DIR_CANARY) -o $(MANIFEST_DIR)/$(MANIFEST_FINAL_NAME_CANARY); \
	fi

.PHONY: github-pr
github-pr:
	$(eval HUB := $(shell echo $(HOME)/hub-linux-amd64-$(HUB_VERSION)/bin/hub))
	$(HUB) clone "$(REPOSITORY)" $(HOME)/qicoo-api-manifests-final
	cd $(HOME)/qicoo-api-manifests-final && \
		$(HUB) checkout -b "CI/$(DOCKER_IMAGE_TAG)" && \
		mv $(MANIFEST_DIR)/* . && \
	 	$(HUB) add . && \
		$(HUB) commit -m "[CI]: Update the final manifest(s): $(DOCKER_IMAGE_TAG)" && \
		$(HUB) push --set-upstream origin "CI/$(DOCKER_IMAGE_TAG)" && \
		$(HUB) pull-request -m "[CI]: Update the final manifests(s): $(DOCKER_IMAGE_TAG)"