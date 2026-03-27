# PostgreSQL Migration Assistant

Assists with migrating **postgres-data** and **postgres-insights** PostgresClusters to the **postgres-core** cluster in the `indico` namespace.

**Design**: This script is intended to be run **before** Terraform changes are applied. It uses only Terraform outputs that already exist (e.g. from the environment workspace: `kms_key_arn`, `pgbackup_s3_bucket_name`, `node_role_name`, `cluster_region`). All other values (replicas, storage size, storage class, image registry, EFS, service mesh) are set via **CLI arguments** with defaults that match Terraform variable defaults, so no new or updated Terraform outputs are required. That keeps downtime minimal when Terraform is later applied.

## Prerequisites

- **Python**: 3.11+ (standard library only; no pip packages required)
- **Terraform**: workspace with outputs `kms_key_arn`, `pgbackup_s3_bucket_name`, `node_role_name`, `cluster_region` (and for minio-to-s3: `data_s3_bucket_name`, `miniobkp_s3_bucket_name`). No additional outputs are required for calculate-values.
- **kubectl**, **helm**, **terraform** in `PATH`
- **AWS CLI** (for `minio-to-s3`; use `--profile` if needed, default `Indico-Dev`)
- Access to the Kubernetes cluster and Terraform workspace

## Paths and defaults

- **Terraform directory (`--tf-dir`)**: For `minio-to-s3` and `migrate-all`, the default is the **repo root** (parent of `scripts/`), so the script finds Terraform state no matter where you run it from. For `calculate-values` and `install`, the default is the current working directory.
- **Output / values file**: Paths are resolved to absolutes when writing or passing to Helm, so relative paths are interpreted relative to the current working directory. Run from repo root for predictable locations (e.g. `indico-core-migration-values.yaml` in repo root).

## Usage

Run from the **repository root** (recommended):

```bash
# 1. Build indico-core values from Terraform outputs
python scripts/postgres_migration/postgres_migration.py calculate-values --tf-dir . -o indico-core-migration-values.yaml

# 2. Install indico-core Helm chart (postgres-core)
python scripts/postgres_migration/postgres_migration.py install --version VERSION -f indico-core-migration-values.yaml

# 3. Bootstrap: copy schemas from source clusters to postgres-core
python scripts/postgres_migration/postgres_migration.py bootstrap

# 4. Set up logical replication (requires wal_level=logical on source)
python scripts/postgres_migration/postgres_migration.py setup-replication
# Optional: fewer kubectl/psql round-trips (skip route precheck + post-create diagnostics)
python scripts/postgres_migration/postgres_migration.py setup-replication --fast

# 5. Verify replication: subscription workers + row counts (use --replication-only for status only)
python scripts/postgres_migration/postgres_migration.py verify-sync [--exact] [--replication-only]

# 6. Migrate MinIO data to S3 (CronJob → Job, then s3 sync)
python scripts/postgres_migration/postgres_migration.py minio-to-s3 [--profile Indico-Dev]
```

### Run all steps (migrate-all)

```bash
# Dry-run (no install; uses helm template; skips bootstrap/setup-replication/verify-sync)
python scripts/postgres_migration/postgres_migration.py migrate-all --dry-run --version 1.0.0-dev-XXXXX

# Real run (from repo root; --tf-dir defaults to repo root)
python scripts/postgres_migration/postgres_migration.py migrate-all --version 1.0.0-dev-XXXXX
```

### Common options

| Option | Description | Default |
|--------|-------------|---------|
| `--tf-dir` | Terraform directory (for outputs) | cwd for calculate-values/install; repo root for minio-to-s3/migrate-all |
| `--kubeconfig` | Kubeconfig path | `KUBECONFIG` env |
| `--helm-repo` | Helm repo URL for indico-core (OCI or classic) | `oci://harbor.devops.indico.io/indico-charts` |
| `--profile` | AWS profile for `minio-to-s3` s3 sync | `Indico-Dev` |
| `--output` / `-o` | Values file for migrate-all step 1 | `indico-core-migration-values.yaml` (cwd-relative) |

### calculate-values / migrate-all (values generation)

These options set postgres-core and indico-core values; they do **not** read from Terraform (so the script works before apply). Defaults match Terraform variable defaults where applicable.

| Option | Description | Default |
|--------|-------------|---------|
| `--az-count` | Instance replicas (1–3) | `2` |
| `--postgres-volume-size` | Postgres PVC size | `100Gi` |
| `--storage-class` | Storage class for postgres volumes | `encrypted-gp3` |
| `--image-registry` | Image registry (rabbitmq, celery-backend) | `harbor.devops.indico.io` |
| `--indico-storage-class-name` | Storage class for rabbitmq persistence | `indico-sc` |
| `--include-efs` | Use EFS-backed storage for rabbitmq | off |
| `--enable-service-mesh` | Export services for service mesh | off |

## Commands summary

| Command | Description |
|---------|-------------|
| `calculate-values` | Generate indico-core values YAML from Terraform (env outputs) + CLI; run before Terraform apply |
| `install` | Install/upgrade indico-core Helm chart (postgres-core) |
| `bootstrap` | Copy **schemas only** from source clusters to postgres-core (databases + `pg_dump -s` / restore). Does **not** create publications/subscriptions—use `setup-replication` |
| `setup-replication` | Create replication user, publication, subscription (logical replication). Before each `CREATE SUBSCRIPTION`, **postgres-core** is probed from its primary pod with `psql` using the same publisher host (`<cluster>-primary.<ns>.svc`), **rep_migration**, and database name as the subscription will use (`connect_timeout=10`). If that fails, the script skips that DB and reports a publisher-unreachable error. If `CREATE SUBSCRIPTION` reports **already exists** (e.g. a prior `DROP` failed because the publisher slot was already gone), the script **disables** the subscription, runs **`ALTER SUBSCRIPTION ... SET (slot_name = NONE)`** (PostgreSQL 15+; avoids remote slot drop on `DROP SUBSCRIPTION`), **drops** the subscription locally, **drops the logical slot** on the publisher if present, and **recreates** the subscription. |
| `cleanup-publisher-slots` | **Destructive:** on a publisher primary, drop logical slots matching this migration: `sub_<namespace>_<cluster>_` (hyphens → underscores) and all `pg_<oid>_sync_*` table-sync slots. On **`postgres-data`**, never drops application slots: `elnino_replication_slot`, `moonbow_replication_slot`, `sunbow_replication_slot`, `cyclone_replication_slot`, `noct_replication_slot`. `setup-replication` runs this cleanup on each publisher **before** creating subscriptions. See below. |
| `verify-sync` | **Subscription health:** all non-template DBs on postgres-core (worker active / no worker, enabled, LSN, last send/receipt) plus GUC hints. **Row sync:** compares `public` table counts source vs target (default: `n_live_tup` estimates). Flags: `--exact` (COUNT(\*)), `--replication-only` (skip row counts). If many mismatches show source `0` and target `>0`, the script prints a hint to try `--exact` or `ANALYZE` on sources. `migrate-all` step 6 runs `verify-sync --replication-only`. |
| `minio-to-s3` | Run minio-backup Job per namespace, then sync S3 miniobkp → data bucket |
| `migrate-all` | Run steps 1–6 in order; step 6 is `verify-sync --replication-only`; supports `--dry-run` |

### Speeding up `setup-replication`

- **Built-in:** The script creates **`rep_migration` once per source cluster** (not once per database) and runs **publication + `GRANT` in one `psql`** per DB to cut `kubectl exec` overhead.
- **`--fast`:** Skips the per-DB **route precheck** (postgres-core → publisher) and skips the post-create **3s sleep** plus worker/connectivity diagnostics. Use when the path is already verified; still run **`verify-sync`** after. **`migrate-all --fast`** passes this through to step 4.
- **Where time usually goes:** Wall clock is often dominated by PostgreSQL **initial table copy** and apply workers, not the Python script. On **postgres-core**, raise **`max_logical_replication_workers`** (and **`max_worker_processes`**) so many subscriptions can run concurrently (see below).

## Logical replication: many subscriptions / “no worker”

PostgreSQL limits how many **logical replication apply workers** can run at once on a **single server** (`max_logical_replication_workers`, default **4**). Each subscription (even in a different database on the same instance) needs a worker. If you have more subscriptions than that limit, `verify-sync` will show **no worker** for the extras until slots free up—they are not necessarily broken.

**Fix:** On **postgres-core**, set `max_logical_replication_workers` to at least your subscription count (e.g. one per migrated DB), and raise `max_worker_processes` enough to cover those workers plus other background work (often `max_logical_replication_workers + 8` or per your operator docs). Configure this in the Crunchy Postgres / PostgresCluster spec for postgres-core (e.g. `postgresql.parameters`).

`verify-sync` prints current GUC values and hints when subscriptions show **no worker** and count exceeds `max_logical_replication_workers`. After a successful `setup-replication`, the script also warns if your subscription count is over that limit—**re-running `setup-replication` does not raise the server limit**; change postgres-core configuration instead.

## Publisher: `max_replication_slots`

Each `CREATE SUBSCRIPTION` creates a **logical replication slot on the publisher** (`postgres-data`, `postgres-insights`, etc.), not on postgres-core. The publisher GUC **`max_replication_slots`** caps how many logical slots can exist cluster-wide.

**Why slot count is much higher than “5 app slots + one per DB”:** During **initial table copy**, PostgreSQL also allocates many extra logical slots on the **publisher** named like **`pg_<oid>_sync_<...>`** (often one per table while that table is being copied). Those are **in addition to** your long-lived application slots and the single **`sub_<ns>_<cluster>_<db>`** slot per subscription. If the script fires **`CREATE SUBSCRIPTION` for database B while database A is still in initial copy**, publisher slot usage is roughly **(app slots) + (all `sub_*` created so far) + (all active `pg_*_sync_*` from every subscription still copying)** — so **dozens or ~100+** is expected without serialization, even when cleanup and naming are correct.

**Default behavior:** `setup-replication` creates subscriptions **one after another without waiting** for each DB’s initial copy to finish (fast). You must set publisher **`max_replication_slots`** high enough for stacked **`pg_*_sync_*`** slots during parallel initial copy (often **well above** “app slots + number of databases”; **128–512** is common for large multi-DB migrations—validate against `pg_replication_slots` during a test run). Optional: **`--wait-initial-copy`** waits on postgres-core until each subscription’s initial copy finishes before the next DB (slower, fewer slots); use **`--initial-copy-timeout-sec`** with that flag. After each DB the script still **prunes inactive** `pg_*_sync_*` when possible.

**If you still hit the limit:** Raise **`max_replication_slots`** further, run **`cleanup-publisher-slots`** to drop orphan sync slots, or use **`--wait-initial-copy`**. `setup-replication` prints publisher slot usage when this error occurs.

**Orphan slots:** If the subscriber was removed while the publisher slot stayed, that slot still counts. The script **drops the publisher slot matching the subscription name** before each `CREATE SUBSCRIPTION`, **retries** after slot cleanup and after **pruning inactive `pg_*_sync_*`**, when creation fails with “slots are in use”.

### `cleanup-publisher-slots` (bulk publisher cleanup)

When you are confident a publisher (e.g. **postgres-insights**) only has migration-related logical slots, run:

```bash
python scripts/postgres_migration/postgres_migration.py cleanup-publisher-slots \
  --publisher-namespace insights \
  --publisher-cluster postgres-insights \
  --dry-run   # remove --dry-run to actually drop
```

This removes:

- All logical slots whose names start with `sub_<ns>_<cluster>_` (same rule as `setup-replication`, hyphens → underscores).
- All logical slots matching `pg_<digits>_sync_*` on **that** publisher (leftover table sync).

**`--all-migration-sources`** runs the same logic on every PostgresCluster discovered for `setup-replication` (everything except `postgres-core` in `--indico-namespace`). Only use that if **each** such publisher has no other logical replication using `pg_*_sync_*` names.

**postgres-data protected slots:** If a slot name is both migration-like and in the protected set (unlikely), it is skipped. The five application slots listed above are not selected by the migration patterns anyway; the filter is a safety net.

## Requirements

See [requirements.txt](./requirements.txt). No Python pip dependencies; requires `terraform`, `kubectl`, `helm`, and (for minio-to-s3) `aws` in `PATH`.
