NAME         = helmdemo
PROVIDER    ?= mandelsoft.org
GITHUBORG   ?= mandelsoft
COMPONENT    = $(PROVIDER)/demo/$(NAME)
OCMREPO     ?= ghcr.io/$(GITHUBORG)/ocm
LOOKUP      ?= ghcr.io/open-component-model/ocm
IMAGE        = echoserver

MULTI       ?= true
PLATFORMS   ?= linux/amd64 linux/arm64
HELMINSTCOMP = ocm.software/toi/installers/helminstaller
HELMINSTVERS = 0.3.0

REPO_ROOT                                     := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
VERSION                                        = $(shell cat VERSION)
COMMIT                                         := $(shell git rev-parse --verify HEAD)
EFFECTIVE_VERSION                              := $(VERSION)-$(COMMIT)
GIT_TREE_STATE                                 := $(shell [ -z "$$(git status --porcelain 2>/dev/null)" ] && echo clean || echo dirty)
PLATFORM                                       := $(shell go env GOOS)/$(shell go env GOARCH)

ATTRIBUTES = \
  COMPONENT="$(COMPONENT)" \
  PROVIDER="$(PROVIDER)" \
  VERSION="$(VERSION)" \
  COMMIT="$(COMMIT)" \
  IMAGE="$(IMAGE):$(VERSION)" \
  PLATFORMS="$(PLATFORMS)" \
  MULTI="$(MULTI)" \
  HELMINSTALLER="$(HELMINSTCOMP):$(HELMINSTVERS)" \

ifeq ($(MULTI),true)
FLAGSUF     = .multi
endif

ifneq ($(TARGETREPO),)
DEPLOYSOURCE = $(TARGETREPO)
else
DEPLOYSOURCE = $(OCMREPO)
endif

CREDS ?=
OCM = ocm $(CREDS)

GEN := $(REPO_ROOT)/gen

CHARTSRCS=$(shell find $(REPO_ROOT)/echoserver/helmchart -type f)
CMDSRCS=$(shell find $(REPO_ROOT)/echoserver/cmd -type f)
COMPSRCS=$(shell find $(REPO_ROOT)/component -type f)


.PHONY: build
build: $(GEN)/image.$(NAME)$(FLAGSUF)

$(GEN)/image.$(NAME): $(GEN)/.exists Dockerfile $(CMDSRCS) $(OCMSRCS)
	docker buildx build -t $(IMAGE):$(VERSION) --platform $(PLATFORM) --file Dockerfile $(REPO_ROOT) \
          --build-arg COMMIT=$(COMMIT) \
          --build-arg EFFECTIVE_VERSION=$(EFFECTIVE_VERSION) \
          --build-arg GIT_TREE_STATE=$(GIT_TREE_STATE)
	@touch $(GEN)/image.$(NAME)

.PHONY: build.multi
build.multi: $(GEN)/image.$(NAME).multi

$(GEN)/image.$(NAME).multi: $(GEN)/.exists Dockerfile $(CMDSRCS) $(OCMSRCS)
	for i in $(PLATFORMS); do \
	tag=$$(echo $$i | sed -e s:/:-:g); \
        echo building platform $$i; \
	docker buildx build --load -t $(IMAGE):$(VERSION)-$$tag --platform $$i --file Dockerfile $(REPO_ROOT) \
          --build-arg COMMIT=$(COMMIT) \
          --build-arg EFFECTIVE_VERSION=$(EFFECTIVE_VERSION) \
          --build-arg GIT_TREE_STATE=$(GIT_TREE_STATE); \
	done
	@touch $(GEN)/image.$(NAME).multi


.PHONY: ctf
ctf: $(GEN)/ctf

.PHONY: version
version:
	@echo $(VERSION)

$(GEN)/ctf: $(GEN)/.exists $(GEN)/image.$(NAME)$(FLAGSUF) $(COMPSRC)
	$(OCM) add component --templater spiff -cf --file $(GEN)/ctf component/component.yaml $(ATTRIBUTES)
	@touch $(GEN)/ctf

.PHONY: eval-component
eval-component:
	$(OCM) add component --templater spiff --dry-run component/component.yaml -O "$(GEN)/component.yaml" $(ATTRIBUTES)

.PHONY: push
push: $(GEN)/ctf $(GEN)/push.$(NAME)

$(GEN)/push.$(NAME): $(GEN)/ctf
	$(OCM) -X keeplocalblob=true transfer ctf --lookup $(LOOKUP) -f $(GEN)/ctf $(OCMREPO)
	@touch $(GEN)/push.$(NAME)

.PHONY: plain-push
plain-push: $(GEN)
	$(OCM) -X keeplocalblob=true transfer ctf --lookup $(LOOKUP) -f $(GEN)/ctf $(OCMREPO)
	@touch $(GEN)/push.$(NAME)

.PHONY: transport
transport:
ifneq ($(TARGETREPO),)
	$(OCM) -X keeplocalblob=true transfer component -Vr  $(OCMREPO)//$(COMPONENT):$(VERSION) $(TARGETREPO)
endif

$(GEN)/.exists:
	@mkdir -p $(GEN)
	@touch $@

.PHONY: info
info:
	@echo "ROOT:     $(REPO_ROOT)"
	@echo "VERSION:  $(VERSION)"
	@echo "COMMIT:   $(COMMIT)"
	@echo "CREDS:    $(CREDS)"
	@echo "version for helminstaller:  $(HELMINSTVERSION)"

.PHONY: describe
describe: $(GEN)/ctf
ifneq ($(TARGETREPO),)
	$(OCM) get resources --lookup $(LOOKUP) -r -o treewide $(TARGETREPO)//$(COMPONENT):$(VERSION)
else
	$(OCM) get resources --lookup $(LOOKUP) -r -o treewide $(GEN)/ctf
endif

.PHONY: descriptor
descriptor: $(GEN)/ctf
ifneq ($(TARGETREPO),)
	$(OCM) get component -S v3alpha1 -o yaml $(TARGETREPO)//$(COMPONENT):$(VERSION)
else
	$(OCM) get component -S v3alpha1 -o yaml $(GEN)/ctf
endif


.PHONY: clean
clean:
	rm -rf $(GEN)

.PHONY: toi-testenv
toi-testenv: $(GEN)/.exists $(GEN)/push.$(NAME)
	@mkdir -p $(GEN)/test
	cd local/toi; ocm bootstrap component -C $(GEN)/test install $(DEPLOYSOURCE)//$(COMPONENT):$(VERSION)

.PHONY: toi-config
toi-config:
	@mkdir -p local/toi
	cd local/toi; ocm bootstrap config $(DEPLOYSOURCE)//$(COMPONENT):$(VERSION)

.PHONY: toi-install
toi-install:
	@mkdir -p local/toi
	cd local/toi; ocm bootstrap package install $(DEPLOYSOURCE)//$(COMPONENT):$(VERSION)

.PHONY: toi-uninstall
toi-uninstall:
	@mkdir -p local/toi
	cd local/toi; ocm bootstrap package uninstall $(DEPLOYSOURCE)//$(COMPONENT):$(VERSION)
