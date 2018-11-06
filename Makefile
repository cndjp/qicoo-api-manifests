DOTENV := ./.env
DOTENV_EXISTS := $(shell [ -f $(DOTENV) ] && echo 0 || echo 1 )

ifeq ($(DOTENV_EXISTS), 0)
	include $(DOTENV)
	export $(shell sed 's/=.*//' .env)
endif

NAME	 := qicoo-api-manifest
TARGET	 := bin/$(NAME)
SRCS	:= $(shell find . -type f -name '*.yaml')

PATCH_FILE_NAME := qicoo-api-patch.yaml
PATCH_RELEASE := overlays/staging/$(PATCH_FILE_NAME)
PATCH_MASTER := overlays/production/$(PATCH_FILE_NAME)

HUB_VERSION = 2.6.0

$(TARGET): github-pr
	echo run

.PHONY: github-setup
github-setup:
	echo "TRAVIS_BRANCH: $(TRAVIS_BRANCH)"
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

.PHONY: github-pr
github-pr:
	$(eval HUB := $(shell echo $(HOME)/hub-linux-amd64-$(HUB_VERSION)/bin/hub))
	$(HUB) log
	$(eval EDITED := $(shell $(HUB) log -n 1 --no-merges --author="hhiroshell" --name-only | grep $(PATCH_FILE_NAME)))
	@if test "$(EDITED)" = "$(PATCH_RELEASE)"; \
		then \
		kustomize build ./overlays/staging -o qicoo-api-all.yaml; \
		$(HUB) clone "https://github.com/cndjp/qicoo-api-manifests-staging.git" $(HOME)/qicoo-api-manifests-all; \
	elif test "$(EDITED)" = "$(PATCH_MASTER)"; \
		then \
		kustomize build ./overlays/production -o qicoo-api-all.yaml; \
		$(HUB) clone "https://github.com/cndjp/qicoo-api-manifests-production.git" $(HOME)/qicoo-api-manifests-all; \
	else \
		exit 1; \
	fi
	cd $(HOME)/qicoo-api-manifests && \
		$(HUB) log && \
		ls
	# 	$(HOME)/hub-linux-amd64-$(HUB_VERSION)/bin/hub add . && \
	# 	$(HOME)/hub-linux-amd64-$(HUB_VERSION)/bin/hub commit -m "Update the image: cndjp/qicoo-api:$(VERSION)" && \
	# 	$(HOME)/hub-linux-amd64-$(HUB_VERSION)/bin/hub push --set-upstream origin "travis/$(VERSION)" && \
	# 	$(HOME)/hub-linux-amd64-$(HUB_VERSION)/bin/hub pull-request -m "Update the image: cndjp/qicoo-api:$(VERSION)"