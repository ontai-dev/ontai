.PHONY: lint lint-docs install-hooks build-all push-all

# Registry and tag override for all image builds.
# Override via: make build-all IMAGE_REGISTRY=registry.ontai.dev/ontai-dev TAG=v1.9.3-r1
IMAGE_REGISTRY ?= 10.20.0.1:5000/ontai-dev
TAG            ?= dev

lint: lint-docs install-hooks

lint-docs:
	@echo ">>> lint-docs: verifying no unintended tracked .md files"
	@bad=$$(git ls-files '*.md' | grep -v '^README\.md$$' | grep -v -- '-schema\.md$$' | grep -v '^CONTEXT\.md$$'); \
	if [ -n "$$bad" ]; then \
		echo "FAIL: tracked .md files violating policy:"; \
		echo "$$bad"; \
		exit 1; \
	fi
	@echo "PASS: no unintended tracked .md files"
	@echo ">>> lint-docs: scanning session/1-governor-init for Co-Authored-By trailers"
	@if git log session/1-governor-init --format='%B' 2>/dev/null | grep -qE '^Co-Authored-By:|^Co-authored-by:'; then \
		echo "FAIL: Co-Authored-By trailer found in commit history"; \
		exit 1; \
	fi
	@echo "PASS: no Co-Authored-By trailers in commit history"

install-hooks:
	@echo ">>> install-hooks: installing commit-msg hook"
	@cp scripts/commit-msg .git/hooks/commit-msg
	@chmod +x .git/hooks/commit-msg
	@echo "PASS: commit-msg hook installed at .git/hooks/commit-msg"

# build-all builds and pushes all operator images in dependency order.
#
# Build order:
#   1. seam-core  — CRD definitions embedded by other operators (must be first)
#   2. guardian, platform, wrapper — in parallel (no inter-dependency)
#   3. conductor  — last (compiler embeds CRDs from all other operators)
#
# All images use --platform linux/amd64 (QEMU x86_64 lab nodes).
# Override registry/tag: make build-all IMAGE_REGISTRY=registry.ontai.dev/ontai-dev TAG=v1.9.3-r1
build-all:
	@echo ">>> build-all: step 1 — seam-core"
	$(MAKE) -C seam-core docker-build docker-push IMAGE_REGISTRY=$(IMAGE_REGISTRY) TAG=$(TAG)
	@echo ">>> build-all: step 2 — guardian, platform, wrapper (parallel)"
	$(MAKE) -C guardian docker-build docker-push IMAGE_REGISTRY=$(IMAGE_REGISTRY) TAG=$(TAG) & \
	$(MAKE) -C platform docker-build docker-push IMAGE_REGISTRY=$(IMAGE_REGISTRY) TAG=$(TAG) & \
	$(MAKE) -C wrapper  docker-build docker-push IMAGE_REGISTRY=$(IMAGE_REGISTRY) TAG=$(TAG) & \
	wait
	@echo ">>> build-all: step 3 — conductor (compiler + execute + agent)"
	$(MAKE) -C conductor docker-build docker-push IMAGE_REGISTRY=$(IMAGE_REGISTRY) TAG=$(TAG)
	@echo ">>> build-all: done — all images pushed to $(IMAGE_REGISTRY)"

# push-all pushes all already-built images to the registry without rebuilding.
push-all:
	$(MAKE) -C seam-core  docker-push IMAGE_REGISTRY=$(IMAGE_REGISTRY) TAG=$(TAG)
	$(MAKE) -C guardian   docker-push IMAGE_REGISTRY=$(IMAGE_REGISTRY) TAG=$(TAG)
	$(MAKE) -C platform   docker-push IMAGE_REGISTRY=$(IMAGE_REGISTRY) TAG=$(TAG)
	$(MAKE) -C wrapper    docker-push IMAGE_REGISTRY=$(IMAGE_REGISTRY) TAG=$(TAG)
	$(MAKE) -C conductor  docker-push IMAGE_REGISTRY=$(IMAGE_REGISTRY) TAG=$(TAG)
