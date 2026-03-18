#syntax=docker/dockerfile:1.9

# FRL CloudNativePG TimescaleDB Image
# Based on: https://github.com/clevyr/docker-cloudnativepg-timescale
# Purpose: CNPG-compatible PostgreSQL with TimescaleDB, pgvector, pg_trgm, and pg_search extensions
#
# This image extends the official CloudNativePG PostgreSQL image and adds:
# - TimescaleDB extension for time-series data
# - pgvector extension for vector embeddings (RAG applications)
# - pg_trgm extension for trigram-based text search
# - pg_search (ParadeDB) extension for BM25 full-text search with ICU tokenization
#
# Build args:
#   CNPG_TAG           - CloudNativePG PostgreSQL image tag (e.g., "17.2-bookworm")
#   POSTGRES_VERSION   - PostgreSQL major version (e.g., "17")
#   TIMESCALE_VERSION  - TimescaleDB version (e.g., "2.17.2~debian12")
#   PGVECTOR_VERSION   - pgvector version (e.g., "0.8.0")
#   PG_SEARCH_VERSION  - ParadeDB pg_search version (e.g., "0.22.1")

ARG CNPG_TAG=17.2-bookworm

FROM ghcr.io/cloudnative-pg/postgresql:${CNPG_TAG}

# Switch to root to install packages
USER root

ARG POSTGRES_VERSION=17
ARG TIMESCALE_VERSION
ARG PGVECTOR_VERSION=0.8.0
ARG PG_SEARCH_VERSION=0.22.1

# Install TimescaleDB and pgvector in a single layer
RUN <<EOF
set -eux

# Install build dependencies
apt-get update
apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    gnupg \
    lsb-release \
    build-essential \
    postgresql-server-dev-${POSTGRES_VERSION}

# Get OS version info
. /etc/os-release

# Add TimescaleDB APT repository
echo "deb https://packagecloud.io/timescale/timescaledb/debian/ ${VERSION_CODENAME} main" \
    > /etc/apt/sources.list.d/timescaledb.list
curl -fsSL https://packagecloud.io/timescale/timescaledb/gpgkey | \
    gpg --dearmor -o /etc/apt/trusted.gpg.d/timescale.gpg

# Install pgvector from source (more reliable than package repos)
cd /tmp
curl -fsSL "https://github.com/pgvector/pgvector/archive/refs/tags/v${PGVECTOR_VERSION}.tar.gz" \
    | tar xz
cd pgvector-${PGVECTOR_VERSION}
make OPTFLAGS="-march=x86-64-v2" PG_CONFIG=/usr/lib/postgresql/${POSTGRES_VERSION}/bin/pg_config
make install PG_CONFIG=/usr/lib/postgresql/${POSTGRES_VERSION}/bin/pg_config
cd /
rm -rf /tmp/pgvector-${PGVECTOR_VERSION}

# Update apt cache and install TimescaleDB
apt-get update

# Install TimescaleDB with specific version if provided, otherwise latest
if [ -n "${TIMESCALE_VERSION:-}" ]; then
    apt-get install -y --no-install-recommends \
        "timescaledb-2-postgresql-${POSTGRES_VERSION}=${TIMESCALE_VERSION}"
else
    apt-get install -y --no-install-recommends \
        "timescaledb-2-postgresql-${POSTGRES_VERSION}"
fi

# Install pg_search (ParadeDB BM25 full-text search)
# On pg17+, pg_search auto-loads — no shared_preload_libraries change needed
curl -fsSL "https://github.com/paradedb/paradedb/releases/download/v${PG_SEARCH_VERSION}/postgresql-${POSTGRES_VERSION}-pg-search_${PG_SEARCH_VERSION}-1PARADEDB-${VERSION_CODENAME}_amd64.deb" \
    -o /tmp/pg_search.deb
apt-get install -y --no-install-recommends /tmp/pg_search.deb
rm /tmp/pg_search.deb

# Clean up build dependencies to reduce image size
apt-get purge -y \
    curl \
    gnupg \
    lsb-release \
    build-essential \
    postgresql-server-dev-${POSTGRES_VERSION}

apt-get autoremove -y

# Remove APT repository files (no longer needed)
rm -f /etc/apt/sources.list.d/timescaledb.list
rm -f /etc/apt/trusted.gpg.d/timescale.gpg

# Clean APT cache
rm -rf /var/lib/apt/lists/*
rm -rf /var/cache/apt/*

# Verify installations
echo "=== Installed Extensions ==="
ls -la /usr/lib/postgresql/${POSTGRES_VERSION}/lib/timescaledb*.so || true
ls -la /usr/lib/postgresql/${POSTGRES_VERSION}/lib/vector.so || true
ls -la /usr/lib/postgresql/${POSTGRES_VERSION}/lib/pg_search*.so || true
ls -la /usr/share/postgresql/${POSTGRES_VERSION}/extension/timescaledb*.sql | head -5 || true
ls -la /usr/share/postgresql/${POSTGRES_VERSION}/extension/vector*.sql || true
ls -la /usr/share/postgresql/${POSTGRES_VERSION}/extension/pg_search*.sql || true

EOF

# Switch back to postgres user (UID 26 for CNPG compatibility)
USER 26

# Labels for image metadata
LABEL org.opencontainers.image.title="FRL CloudNativePG TimescaleDB"
LABEL org.opencontainers.image.description="CloudNativePG-compatible PostgreSQL with TimescaleDB, pgvector, pg_trgm, and pg_search (BM25)"
LABEL org.opencontainers.image.source="https://github.com/mimlrd/frl-cloudnativepg-timescale"
LABEL org.opencontainers.image.vendor="MIMLRD"
LABEL maintainer="Firstrepubliclabs Team"