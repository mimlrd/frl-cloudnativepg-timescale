# FRL CloudNativePG TimescaleDB

CloudNativePG-compatible PostgreSQL images with TimescaleDB, pgvector, and pg_trgm extensions pre-installed.

## Overview

This project builds Docker images that combine:
- **CloudNativePG PostgreSQL** - Official PostgreSQL images optimized for Kubernetes
- **TimescaleDB** - Time-series database extension
- **pgvector** - Vector similarity search for AI/ML applications
- **pg_trgm** - Trigram-based text similarity search

These images are designed for use with the [CloudNativePG](https://cloudnative-pg.io/) operator in Kubernetes environments.

## Why This Image?

The official TimescaleDB-HA image is **not compatible** with CloudNativePG due to:
- Different UID/GID (70:70 vs CNPG's 26:26)
- Non-standard data directory paths (`/home/postgres/pgdata` vs `/var/lib/postgresql/data`)
- Different PostgreSQL build configuration

This image starts from the official CNPG base image and adds TimescaleDB + pgvector on top, ensuring full compatibility.

## Supported Versions

| PostgreSQL | CNPG Base Tag | TimescaleDB | pgvector |
|------------|---------------|-------------|----------|
| 17         | 17.2-bookworm | 2.25.0      | 0.8.0    |
| 16         | 16.6-bookworm | 2.25.0      | 0.8.0    |
| 15         | 15.10-bookworm| 2.25.0      | 0.8.0    |

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

  storage:
    size: 50Gi
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `REGISTRY` | `ghcr.io/mimlrd` | Container registry for pushing images |
| `IMAGE_NAME` | `frl-cloudnativepg-timescale` | Base image name |
| `TIMESCALE_VERSION` | (latest) | Specific TimescaleDB version |
| `PGVECTOR_VERSION` | `0.8.0` | pgvector version |

## Build Arguments

| Argument | Description |
|----------|-------------|
| `CNPG_TAG` | CloudNativePG base image tag (e.g., `17.2-bookworm`) |
| `POSTGRES_VERSION` | PostgreSQL major version (e.g., `17`) |
| `TIMESCALE_VERSION` | TimescaleDB Debian package version |
| `PGVECTOR_VERSION` | pgvector version to build from source |

## Extension Installation

After deploying a cluster with this image, you can create the extensions:

```sql
-- Connect to your database
\c rag

-- Install extensions
CREATE EXTENSION IF NOT EXISTS timescaledb;
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Verify installations
\dx
```

**Expected output:**
```
                                   List of installed extensions
    Name     | Version |   Schema   |                  Description
-------------+---------+------------+-----------------------------------------------
 pg_trgm     | 1.6     | public     | text similarity measurement and index searching
 plpgsql     | 1.0     | pg_catalog | PL/pgSQL procedural language
 timescaledb | 2.25.0  | public     | Enables scalable inserts and complex queries
 vector      | 0.8.0   | public     | vector data type and access methods
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

### Checking Installed Versions

```bash
# Inside the container
kubectl exec -it <pod-name> -n <namespace> -- bash

# Check library versions
ls -la /usr/lib/postgresql/17/lib/timescaledb*.so
ls -la /usr/lib/postgresql/17/lib/vector.so

# Check SQL script versions
ls /usr/share/postgresql/17/extension/timescaledb--*.sql | tail -5
ls /usr/share/postgresql/17/extension/vector--*.sql
```

## CI/CD Integration

This repository includes a GitHub Actions workflow (`.github/workflows/build.yml`) that:
- Builds all PostgreSQL versions (15, 16, 17) on push to main
- Rebuilds weekly (Mondays) to get security updates
- Tests images on pull requests
- Pushes to GitHub Container Registry automatically

Images are published to: `ghcr.io/mimlrd/frl-cloudnativepg-timescale`

## Related Resources

- [CloudNativePG Documentation](https://cloudnative-pg.io/documentation/)
- [TimescaleDB Documentation](https://docs.timescale.com/)
- [pgvector Documentation](https://github.com/pgvector/pgvector)
- [Original Clevyr Image](https://github.com/clevyr/docker-cloudnativepg-timescale)

## License

Apache-2.0
