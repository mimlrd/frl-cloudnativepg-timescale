#!/bin/bash
#
# Build script for FRL CloudNativePG TimescaleDB images
#
# Usage:
#   ./build.sh                    # Build with defaults (PG17, latest TimescaleDB)
#   ./build.sh --pg-version 16    # Build for PostgreSQL 16
#   ./build.sh --push             # Build and push to registry
#   ./build.sh --all              # Build all supported PostgreSQL versions
#
# Environment variables:
#   REGISTRY          - Container registry (default: ghcr.io/your-org)
#   IMAGE_NAME        - Image name (default: frl-cloudnativepg-timescale)
#   TIMESCALE_VERSION - TimescaleDB version (default: auto-detect latest)
#   PGVECTOR_VERSION  - pgvector version (default: 0.8.0)

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY="${REGISTRY:-ghcr.io/mimlrd}"
IMAGE_NAME="${IMAGE_NAME:-frl-cloudnativepg-timescale}"
PGVECTOR_VERSION="${PGVECTOR_VERSION:-0.8.0}"

# Supported PostgreSQL versions and their CNPG base image tags
declare -A PG_VERSIONS=(
    ["15"]="15.10-bookworm"
    ["16"]="16.6-bookworm"
    ["17"]="17.2-bookworm"
)

# Default to PostgreSQL 17
DEFAULT_PG_VERSION="17"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Parse command line arguments
PG_VERSION=""
PUSH=false
BUILD_ALL=false
DRY_RUN=false
NO_CACHE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --pg-version)
            PG_VERSION="$2"
            shift 2
            ;;
        --push)
            PUSH=true
            shift
            ;;
        --all)
            BUILD_ALL=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --no-cache)
            NO_CACHE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --pg-version VERSION  PostgreSQL version (15, 16, 17)"
            echo "  --push                Push image to registry after build"
            echo "  --all                 Build all supported PostgreSQL versions"
            echo "  --no-cache            Build without using cache"
            echo "  --dry-run             Show what would be done without executing"
            echo "  --help, -h            Show this help message"
            echo ""
            echo "Environment variables:"
            echo "  REGISTRY              Container registry (default: ghcr.io/your-org)"
            echo "  IMAGE_NAME            Image name (default: frl-cloudnativepg-timescale)"
            echo "  TIMESCALE_VERSION     TimescaleDB version (optional, auto-detect)"
            echo "  PGVECTOR_VERSION      pgvector version (default: 0.8.0)"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Set default PG version if not specified
if [[ -z "$PG_VERSION" && "$BUILD_ALL" == "false" ]]; then
    PG_VERSION="$DEFAULT_PG_VERSION"
fi

# Validate PG version
validate_pg_version() {
    local version=$1
    if [[ -z "${PG_VERSIONS[$version]:-}" ]]; then
        log_error "Unsupported PostgreSQL version: $version"
        log_error "Supported versions: ${!PG_VERSIONS[*]}"
        exit 1
    fi
}

# Build a single image
build_image() {
    local pg_version=$1
    local cnpg_tag="${PG_VERSIONS[$pg_version]}"
    local image_tag="${REGISTRY}/${IMAGE_NAME}:${pg_version}"
    local cache_flag=""

    if [[ "$NO_CACHE" == "true" ]]; then
        cache_flag="--no-cache"
    fi

    log_info "Building image for PostgreSQL ${pg_version}"
    log_info "  Base image: ghcr.io/cloudnative-pg/postgresql:${cnpg_tag}"
    log_info "  Target tag: ${image_tag}"
    log_info "  pgvector version: ${PGVECTOR_VERSION}"

    if [[ -n "${TIMESCALE_VERSION:-}" ]]; then
        log_info "  TimescaleDB version: ${TIMESCALE_VERSION}"
    else
        log_info "  TimescaleDB version: latest"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_warn "Dry run - skipping actual build"
        return 0
    fi

    # Build the image
    docker build \
        ${cache_flag} \
        --build-arg CNPG_TAG="${cnpg_tag}" \
        --build-arg POSTGRES_VERSION="${pg_version}" \
        --build-arg PGVECTOR_VERSION="${PGVECTOR_VERSION}" \
        ${TIMESCALE_VERSION:+--build-arg TIMESCALE_VERSION="${TIMESCALE_VERSION}"} \
        --tag "${image_tag}" \
        --tag "${image_tag}-$(date +%Y%m%d)" \
        "${SCRIPT_DIR}"

    log_success "Built: ${image_tag}"

    # Push if requested
    if [[ "$PUSH" == "true" ]]; then
        log_info "Pushing ${image_tag}..."
        docker push "${image_tag}"
        docker push "${image_tag}-$(date +%Y%m%d)"
        log_success "Pushed: ${image_tag}"
    fi
}

# Main execution
main() {
    log_info "FRL CloudNativePG TimescaleDB Image Builder"
    log_info "Registry: ${REGISTRY}"
    log_info "Image name: ${IMAGE_NAME}"
    echo ""

    if [[ "$BUILD_ALL" == "true" ]]; then
        log_info "Building all supported PostgreSQL versions..."
        for version in "${!PG_VERSIONS[@]}"; do
            echo ""
            build_image "$version"
        done
    else
        validate_pg_version "$PG_VERSION"
        build_image "$PG_VERSION"
    fi

    echo ""
    log_success "Build complete!"
}

main "$@"
