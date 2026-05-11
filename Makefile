.PHONY: build framework clean deps boost librime pack ci-build help

VERSION    ?= v0.1.0-dev
RELEASE_URL = https://github.com/thomfang/LibrimeKit-iOS/releases/download/$(VERSION)/Frameworks.tgz

# 子集编译参数，可由调用方覆盖。default 是 librime 实际需要的最小集 + 3 iOS slice。
BOOST_LIBS      ?= regex,system,filesystem,thread
BOOST_PLATFORMS ?= ios,iossim-both

OUTDIR     := $(CURDIR)/Frameworks
BUILDDIR   := $(CURDIR)/build

help:
	@echo "Targets:"
	@echo "  framework   download pre-built Frameworks.tgz from Releases (consumers use this)"
	@echo "  build       full local build: boost -> deps -> librime -> pack (~30 min cold)"
	@echo "  boost       build boost-iosx xcframeworks + extract per-slice .a/headers"
	@echo "  deps        build glog/leveldb/yaml-cpp/marisa/opencc for 3 iOS slices"
	@echo "  librime     build librime only (assumes boost + deps already built)"
	@echo "  pack        pack built .a libs into XCFrameworks under Frameworks/"
	@echo "  ci-build    full build + tar package for GH Release"
	@echo "  clean       remove build/ and Frameworks/"

framework:
	rm -rf $(OUTDIR) && mkdir -p $(OUTDIR)
	curl -fSL $(RELEASE_URL) | tar -xz -C $(OUTDIR) --strip-components=1

build: boost deps librime pack

boost:
	cd deps/boost-iosx && bash scripts/build.sh --libs=$(BOOST_LIBS) --platforms=$(BOOST_PLATFORMS)
	bash scripts/extract-boost.sh

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
