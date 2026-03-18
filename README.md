# FRL CloudNativePG TimescaleDB

CloudNativePG-compatible PostgreSQL images with TimescaleDB, pgvector, pg_trgm, and pg_search (ParadeDB BM25) extensions pre-installed.

## Overview

This project builds Docker images that combine:
- **CloudNativePG PostgreSQL** - Official PostgreSQL images optimized for Kubernetes
- **TimescaleDB** - Time-series database extension
- **pgvector** - Vector similarity search for AI/ML applications
- **pg_trgm** - Trigram-based text similarity search
- **pg_search** (ParadeDB) - BM25 full-text search with ICU tokenization (Tantivy-powered)

These images are designed for use with the [CloudNativePG](https://cloudnative-pg.io/) operator in Kubernetes environments.

## Why This Image?

The official TimescaleDB-HA image is **not compatible** with CloudNativePG due to:
- Different UID/GID (70:70 vs CNPG's 26:26)
- Non-standard data directory paths (`/home/postgres/pgdata` vs `/var/lib/postgresql/data`)
- Different PostgreSQL build configuration

This image starts from the official CNPG base image and adds TimescaleDB + pgvector + pg_search on top, ensuring full compatibility.

## Supported Versions

| PostgreSQL | CNPG Base Tag | TimescaleDB | pgvector | pg_search |
|------------|---------------|-------------|----------|-----------|
| 17         | 17.2-bookworm | 2.25.0      | 0.8.0    | 0.22.1    |
| 16         | 16.6-bookworm | 2.25.0      | 0.8.0    | 0.22.1    |
| 15         | 15.10-bookworm| 2.25.0      | 0.8.0    | 0.22.1    |

> **Note**: On PostgreSQL 17+, pg_search auto-loads without needing `shared_preload_libraries`. On pg15/pg16 you must add `pg_search` to `shared_preload_libraries`.

## Quick Start

### Building Locally

```bash
# Build for PostgreSQL 17 (default)
./build.sh

# Build for a specific PostgreSQL version
./build.sh --pg-version 16

# Build all supported versions
./build.sh --all

# Build and push to registry
./build.sh --push

# Build without cache
./build.sh --no-cache

# Override pg_search version
PG_SEARCH_VERSION=0.22.1 ./build.sh
```

### Using with CloudNativePG

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: rag-timescaledb
spec:
  instances: 3
  imageName: ghcr.io/mimlrd/frl-cloudnativepg-timescale:17

  postgresql:
    shared_preload_libraries:
      - timescaledb
    parameters:
      timescaledb.telemetry_level: "off"

  bootstrap:
    initdb:
      database: rag
      owner: rag_app
      postInitApplicationSQL:
        - CREATE EXTENSION IF NOT EXISTS timescaledb;
        - CREATE EXTENSION IF NOT EXISTS vector;
        - CREATE EXTENSION IF NOT EXISTS pg_trgm;
        - CREATE EXTENSION IF NOT EXISTS pg_search;
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `REGISTRY` | `ghcr.io/mimlrd` | Container registry for pushing images |
| `IMAGE_NAME` | `frl-cloudnativepg-timescale` | Base image name |
| `TIMESCALE_VERSION` | (latest) | Specific TimescaleDB version |
| `PGVECTOR_VERSION` | `0.8.0` | pgvector version |
| `PG_SEARCH_VERSION` | `0.22.1` | ParadeDB pg_search version |

## Build Arguments

| Argument | Description |
|----------|-------------|
| `CNPG_TAG` | CloudNativePG base image tag (e.g., `17.2-bookworm`) |
| `POSTGRES_VERSION` | PostgreSQL major version (e.g., `17`) |
| `TIMESCALE_VERSION` | TimescaleDB Debian package version |
| `PGVECTOR_VERSION` | pgvector version to build from source |
| `PG_SEARCH_VERSION` | ParadeDB pg_search version (`.deb` from GitHub releases) |

## Extension Installation

After deploying a cluster with this image, you can create the extensions:

```sql
-- Connect to your database
\c rag

-- Install extensions
CREATE EXTENSION IF NOT EXISTS timescaledb;
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS pg_search;

-- Verify installations
\dx
```

**Expected output:**
```
                                   List of installed extensions
    Name     | Version |   Schema   |                  Description
-------------+---------+------------+-----------------------------------------------
 pg_search   | 0.22.1  | public     | Full-text search with BM25 scoring
 pg_trgm     | 1.6     | public     | text similarity measurement and index searching
 plpgsql     | 1.0     | pg_catalog | PL/pgSQL procedural language
 timescaledb | 2.25.0  | public     | Enables scalable inserts and complex queries
 vector      | 0.8.0   | public     | vector data type and access methods
```

## BM25 Full-Text Search (pg_search)

pg_search enables Elastic-quality full-text search within PostgreSQL via the Tantivy search engine. Key features:

- **BM25 scoring** with proper term-frequency/inverse-document-frequency
- **ICU tokenization** for language-aware text processing (French, German, Spanish, etc.)
- **Index-based search** using the `bm25` index type and `@@@` operator

Example BM25 index:
```sql
CREATE INDEX idx_chunks_bm25 ON chunks USING bm25 (chunk_id, text, section_path)
WITH (
    key_field = 'chunk_id',
    text_fields = '{"text": {"tokenizer": {"type": "icu", "language": "fra"}}}'
);

-- Query with BM25 scoring
SELECT chunk_id, pdb.score(chunk_id) AS score
FROM chunks
WHERE text @@@ 'contrat de prestation'
ORDER BY score DESC;
```

## Troubleshooting

### Extension Version Mismatch

If you see errors like:
```
ERROR: extension "timescaledb" has no installation script for version "X.Y.Z"
```

This means the library version doesn't match the available SQL scripts. Solutions:
1. Specify the exact version when creating the extension:
   ```sql
   CREATE EXTENSION timescaledb VERSION '2.17.2';
   ```
2. Check available versions:
   ```sql
   SELECT * FROM pg_available_extension_versions WHERE name = 'timescaledb';
   ```

### pg_search Not Loading (pg15/pg16)

On PostgreSQL 15 and 16, pg_search must be added to `shared_preload_libraries`:
```yaml
postgresql:
  shared_preload_libraries:
    - timescaledb
    - pg_search
```

On PostgreSQL 17+, this is **not required** — pg_search auto-loads.

### Checking Installed Versions

```bash
# Inside the container
kubectl exec -it <pod-name> -n <namespace> -- bash

# Check library versions
ls -la /usr/lib/postgresql/17/lib/timescaledb*.so
ls -la /usr/lib/postgresql/17/lib/vector.so
ls -la /usr/lib/postgresql/17/lib/pg_search*.so

# Check SQL script versions
ls /usr/share/postgresql/17/extension/timescaledb--*.sql | tail -5
ls /usr/share/postgresql/17/extension/vector--*.sql
ls /usr/share/postgresql/17/extension/pg_search--*.sql
```

## CI/CD Integration

This repository includes a GitHub Actions workflow (`.github/workflows/build.yml`) that:
- Builds all PostgreSQL versions (15, 16, 17) on push to main
- Rebuilds weekly (Mondays) to get security updates
- Tests images on pull requests (verifies all extensions are available)
- Pushes to GitHub Container Registry automatically

Images are published to: `ghcr.io/mimlrd/frl-cloudnativepg-timescale`

## Related Resources

- [CloudNativePG Documentation](https://cloudnative-pg.io/documentation/)
- [TimescaleDB Documentation](https://docs.timescale.com/)
- [pgvector Documentation](https://github.com/pgvector/pgvector)
- [ParadeDB pg_search Documentation](https://docs.paradedb.com/)
- [Original Clevyr Image](https://github.com/clevyr/docker-cloudnativepg-timescale)

## License

Apache-2.0
