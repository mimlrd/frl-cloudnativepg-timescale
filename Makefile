# FRL CloudNativePG TimescaleDB - Makefile
#
# Usage:
#   make build          - Build PostgreSQL 17 image (default)
#   make build-all      - Build all supported versions
#   make push           - Build and push to registry
#   make test           - Run local test
#   make clean          - Remove local images

# Configuration
REGISTRY ?= ghcr.io/mimlrd
IMAGE_NAME ?= frl-cloudnativepg-timescale
PGVECTOR_VERSION ?= 0.8.0

# PostgreSQL versions and their CNPG base tags
PG15_TAG = 15.10-bookworm
PG16_TAG = 16.6-bookworm
PG17_TAG = 17.2-bookworm

# Default target
.DEFAULT_GOAL := build

.PHONY: build build-15 build-16 build-17 build-all push push-all test test-all clean help

# Build PostgreSQL 17 (default)
build: build-17

# Build specific versions
build-15:
	@echo "Building PostgreSQL 15 image..."
	docker build \
		--build-arg CNPG_TAG=$(PG15_TAG) \
		--build-arg POSTGRES_VERSION=15 \
		--build-arg PGVECTOR_VERSION=$(PGVECTOR_VERSION) \
		-t $(REGISTRY)/$(IMAGE_NAME):15 \
		-t $(REGISTRY)/$(IMAGE_NAME):15-$$(date +%Y%m%d) \
		.

build-16:
	@echo "Building PostgreSQL 16 image..."
	docker build \
		--build-arg CNPG_TAG=$(PG16_TAG) \
		--build-arg POSTGRES_VERSION=16 \
		--build-arg PGVECTOR_VERSION=$(PGVECTOR_VERSION) \
		-t $(REGISTRY)/$(IMAGE_NAME):16 \
		-t $(REGISTRY)/$(IMAGE_NAME):16-$$(date +%Y%m%d) \
		.

build-17:
	@echo "Building PostgreSQL 17 image..."
	docker build \
		--build-arg CNPG_TAG=$(PG17_TAG) \
		--build-arg POSTGRES_VERSION=17 \
		--build-arg PGVECTOR_VERSION=$(PGVECTOR_VERSION) \
		-t $(REGISTRY)/$(IMAGE_NAME):17 \
		-t $(REGISTRY)/$(IMAGE_NAME):17-$$(date +%Y%m%d) \
		.

build-all: build-15 build-16 build-17

# Push to registry
push: build-17
	@echo "Pushing PostgreSQL 17 image..."
	docker push $(REGISTRY)/$(IMAGE_NAME):17
	docker push $(REGISTRY)/$(IMAGE_NAME):17-$$(date +%Y%m%d)

push-all: build-all
	@echo "Pushing all images..."
	docker push $(REGISTRY)/$(IMAGE_NAME):15
	docker push $(REGISTRY)/$(IMAGE_NAME):15-$$(date +%Y%m%d)
	docker push $(REGISTRY)/$(IMAGE_NAME):16
	docker push $(REGISTRY)/$(IMAGE_NAME):16-$$(date +%Y%m%d)
	docker push $(REGISTRY)/$(IMAGE_NAME):17
	docker push $(REGISTRY)/$(IMAGE_NAME):17-$$(date +%Y%m%d)

# Test locally
test: build-17
	@echo "Testing PostgreSQL 17 image..."
	@docker rm -f frl-timescale-test 2>/dev/null || true
	docker run -d \
		--name frl-timescale-test \
		-e POSTGRES_PASSWORD=testpass \
		$(REGISTRY)/$(IMAGE_NAME):17
	@echo "Waiting for PostgreSQL to start..."
	@sleep 15
	@echo "Checking available extensions..."
	docker exec frl-timescale-test psql -U postgres -c \
		"SELECT name, default_version FROM pg_available_extensions WHERE name IN ('timescaledb', 'vector', 'pg_trgm') ORDER BY name;"
	@echo ""
	@echo "Creating extensions..."
	docker exec frl-timescale-test psql -U postgres -c \
		"CREATE EXTENSION IF NOT EXISTS timescaledb; CREATE EXTENSION IF NOT EXISTS vector; CREATE EXTENSION IF NOT EXISTS pg_trgm;"
	@echo ""
	@echo "Listing installed extensions..."
	docker exec frl-timescale-test psql -U postgres -c "\dx"
	@echo ""
	@echo "Cleaning up test container..."
	docker stop frl-timescale-test
	docker rm frl-timescale-test
	@echo "Test completed successfully!"

test-all: build-all
	@for ver in 15 16 17; do \
		echo "Testing PostgreSQL $$ver..."; \
		docker rm -f frl-timescale-test-$$ver 2>/dev/null || true; \
		docker run -d \
			--name frl-timescale-test-$$ver \
			-e POSTGRES_PASSWORD=testpass \
			$(REGISTRY)/$(IMAGE_NAME):$$ver; \
		sleep 15; \
		docker exec frl-timescale-test-$$ver psql -U postgres -c \
			"SELECT name, default_version FROM pg_available_extensions WHERE name IN ('timescaledb', 'vector', 'pg_trgm');"; \
		docker stop frl-timescale-test-$$ver; \
		docker rm frl-timescale-test-$$ver; \
		echo "PostgreSQL $$ver test passed!"; \
		echo ""; \
	done

# Clean up local images
clean:
	@echo "Removing local images..."
	-docker rmi $(REGISTRY)/$(IMAGE_NAME):15 2>/dev/null
	-docker rmi $(REGISTRY)/$(IMAGE_NAME):16 2>/dev/null
	-docker rmi $(REGISTRY)/$(IMAGE_NAME):17 2>/dev/null
	-docker rmi $$(docker images -q $(REGISTRY)/$(IMAGE_NAME) 2>/dev/null) 2>/dev/null
	@echo "Cleanup complete."

# Help
help:
	@echo "FRL CloudNativePG TimescaleDB - Build Targets"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  build        Build PostgreSQL 17 image (default)"
	@echo "  build-15     Build PostgreSQL 15 image"
	@echo "  build-16     Build PostgreSQL 16 image"
	@echo "  build-17     Build PostgreSQL 17 image"
	@echo "  build-all    Build all supported versions"
	@echo "  push         Build and push PostgreSQL 17"
	@echo "  push-all     Build and push all versions"
	@echo "  test         Run local test with PostgreSQL 17"
	@echo "  test-all     Test all versions"
	@echo "  clean        Remove local images"
	@echo "  help         Show this help message"
	@echo ""
	@echo "Environment Variables:"
	@echo "  REGISTRY          Container registry (default: ghcr.io/your-org)"
	@echo "  IMAGE_NAME        Image name (default: frl-cloudnativepg-timescale)"
	@echo "  PGVECTOR_VERSION  pgvector version (default: 0.8.0)"
