DOTENV := ./.env
DOTENV_EXISTS := $(shell [ -f $(DOTENV) ] && echo 0 || echo 1 )

ifeq ($(DOTENV_EXISTS), 0)
	include $(DOTENV)
	export $(shell sed 's/=.*//' .env)
endif

NAME	 := qicoo-api-manifest
TARGET	 := bin/$(NAME)
SRCS	:= $(shell find . -type f -name '*.yaml')

ifeq ($(TRAVIS_BRANCH), master)
	export PHASE = production
else ifeq ($(TRAVIS_BRANCH), release)
	export PHASE = staging
endif

HUB_VERSION = 2.6.0
HUB_VERSION = cndjpintegration

$(TARGET): $(SRCS)
	# kustomize build ./overlays/$(PHASE) -o qicoo-api-all.yaml
	$(HUB) log

.PHONY: create-dotenv
create-dotenv:
	@if [ ! -f $(DOTENV) ]; \
		then\
		echo 'Create .env file.' ;\
		echo 'TRAVIS_BRANCH=master' >> ./.env ;\
		echo 'TRAVIS=' >> ./.env ;\
	else \
		echo Not Work. ;\
	fi

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
	$(eval HUB := $(shell echo $(HOME)/hub-linux-amd64-$(HUB_VERSION)/bin/hub))

# .PHONY: github-update-manifest
# github-update-manifest: github-setup
# 	$(HOME)/hub-linux-amd64-$(HUB_VERSION)/bin/hub clone "https://github.com/cndjp/qicoo-api-manifests.git" $(HOME)/qicoo-api-manifests
# 	cd $(HOME)/qicoo-api-manifests && \
# 		$(HOME)/hub-linux-amd64-$(HUB_VERSION)/bin/hub checkout -b "travis/$(VERSION)"
# 	@if test "$(TRAVIS_BRANCH)" = "master"; \
# 		then \
# 		sed -i -e "s/image: cndjp\/qicoo-api:v[0-9]*.[0-9]*.[0-9]*/image: cndjp\/qicoo-api:$(VERSION)/g" $(HOME)/qicoo-api-manifests/overlays/production/qicoo-api-patch.yaml; \
# 	else \
# 		sed -i -e "s/image: cndjp\/qicoo-api@sha256:[0-9a-f]{64}/image: cndjp\/qicoo-api@$(IMAGE_DIGEST)/g" $(HOME)/qicoo-api-manifests/overlays/staging/qicoo-api-patch.yaml; \
# 	fi
# 	cd $(HOME)/qicoo-api-manifests && \
# 		$(HOME)/hub-linux-amd64-$(HUB_VERSION)/bin/hub add . && \
# 		$(HOME)/hub-linux-amd64-$(HUB_VERSION)/bin/hub commit -m "Update the image: cndjp/qicoo-api:$(VERSION)" && \
# 		$(HOME)/hub-linux-amd64-$(HUB_VERSION)/bin/hub push --set-upstream origin "travis/$(VERSION)" && \
# 		$(HOME)/hub-linux-amd64-$(HUB_VERSION)/bin/hub pull-request -m "Update the image: cndjp/qicoo-api:$(VERSION)"
