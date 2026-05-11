.PHONY: build framework clean deps librime pack ci-build help

VERSION    ?= v0.1.0-dev
RELEASE_URL = https://github.com/thomfang/LibrimeKit-iOS/releases/download/$(VERSION)/Frameworks.tgz

OUTDIR     := $(CURDIR)/Frameworks
BUILDDIR   := $(CURDIR)/build

help:
	@echo "Targets:"
	@echo "  framework   download pre-built Frameworks.tgz from Releases (consumers use this)"
	@echo "  build       full local build: deps -> librime -> xcframework pack (~1h)"
	@echo "  deps        build small deps only (yaml-cpp, leveldb, marisa, opencc, glog)"
	@echo "  librime     build librime only (assumes deps already built)"
	@echo "  pack        pack built .a libs into XCFrameworks under Frameworks/"
	@echo "  ci-build    full build + tar package for GH Release"
	@echo "  clean       remove build/ and Frameworks/"

framework:
	rm -rf $(OUTDIR) && mkdir -p $(OUTDIR)
	curl -fSL $(RELEASE_URL) | tar -xz -C $(OUTDIR) --strip-components=1

build: deps librime pack

deps:
	bash scripts/build-deps.sh

librime:
	bash scripts/build-librime.sh

pack:
	bash scripts/pack-xcframework.sh

ci-build: build
	cd $(OUTDIR) && tar -czf $(CURDIR)/Frameworks.tgz *.xcframework

clean:
	rm -rf $(BUILDDIR) $(OUTDIR) Frameworks.tgz
