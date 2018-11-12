DOTACTION = ./.kustomize-action
DOTACTION_EXISTS := $(shell [ -f $(DOTACTION) ] && echo 0 || echo 1 )

ifeq ($(DOTACTION_EXISTS), 0)
	include $(DOTACTION)
	export $(shell sed 's/=.*//' .kustomize-action)
	DOCKER_IMAGE_TAG := $(tag)
	UPDATED_BRANCH := $(branch)
endif

KUSTOMIZE_ACTION_FILE_NAME := kustomize-action.yaml

ifeq ($(UPDATED_BRANCH), "release")
	PATCH_DIR := overlays/staging
endif

PATCH_FILE_NAME := qicoo-api-patch.yaml
PATCH := $(PATCH_DIR)/$(PATCH_FILE_NAME)
# PATCH_DIR_STAGING := overlays/staging
# PATCH_DIR_PRODUCTION := overlays/production
# PATCH_STAGING := $(PATCH_DIR_STAGING)/$(PATCH_FILE_NAME)
# PATCH_PRODUCTION := $(PATCH_DIR_PRODUCTION)/$(PATCH_FILE_NAME)

MANIFEST_FINAL_NAME := qicoo-api-all.yaml

REPOSITORY_STAGING := https://github.com/cndjp/qicoo-api-manifests-staging.git
REPOSITORY_PRODUCTION := https://github.com/cndjp/qicoo-api-manifests-production.git

HUB_VERSION := 2.6.0
KUSTOMIZE_VERSION := 1.0.9

$(MANIFEST_FINAL_NAME): build-and-pr

.PHONY: load-kustomize-action
load-kustomize-action:
	sed -e 's/:[^:\/\/]/="/g;s/$$/"/g;s/ *=/=/g' ./kustomize-action.yaml > .kustomize-action

.PHONY: status
status:
	echo $(DOCKER_IMAGE_TAG)
	echo $(tag)
	echo $(UPDATED_BRANCH)

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

.PHONY: build-and-pr
build-and-pr:
	$(eval KUSTOMIZE := $(shell echo $(HOME)/kustomize))
	$(eval HUB := $(shell echo $(HOME)/hub-linux-amd64-$(HUB_VERSION)/bin/hub))
	$(eval EDITED := $(shell $(HUB) log -n 1 --no-merges --author="$(GITHUB_USER)" --name-only | grep -e ^$(PATCH_STAGING) -e ^$(PATCH_PRODUCTION)))
	@if test "$(EDITED)" = "$(PATCH_STAGING)"; \
		then \
		$(KUSTOMIZE) build $(PATCH_DIR_STAGING) -o $(HOME)/$(MANIFEST_FINAL_NAME); \
		$(HUB) clone "$(REPOSITORY_STAGING)" $(HOME)/qicoo-api-manifests-all; \
	elif test "$(EDITED)" = "$(PATCH_PRODUCTION)"; \
		then \
		$(KUSTOMIZE) build $(PATCH_DIR_PRODUCTION) -o $(HOME)/$(MANIFEST_FINAL_NAME); \
		$(HUB) clone "$(REPOSITORY_PRODUCTION)" $(HOME)/qicoo-api-manifests-all; \
	else \
		echo "Too many or no file is modified."; \
		exit 1; \
	fi
	$(eval BRANCH := "CI/$(TRAVIS_JOB_ID)")
	cd $(HOME)/qicoo-api-manifests-all && \
		$(HUB) checkout -b $(BRANCH) && \
		mv $(HOME)/$(MANIFEST_FINAL_NAME) . && \
	 	$(HUB) add ./$(MANIFEST_FINAL_NAME) && \
		$(HUB) commit -m "Update the Environment: $(TRAVIS_JOB_ID)" && \
		$(HUB) push --set-upstream origin "$(BRANCH)" && \
		$(HUB) pull-request -m "Update the Environment: $(TRAVIS_JOB_ID)"