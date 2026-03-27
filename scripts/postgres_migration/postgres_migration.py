#!/usr/bin/env python3
"""
PostgreSQL Migration Assistant for postgres-core cluster.

Assists with migrating postgres-data and postgres-insights PostgresClusters
to the postgres-core cluster in the indico namespace.

Prerequisites:
- Terraform workspace with outputs: kms_key_arn, pgbackup_s3_bucket_name, node_role_name, cluster_region
- kubectl, helm, terraform in PATH
- Access to the Kubernetes cluster and Terraform workspace

Expected values file (--values-file / -f):
  The values file is passed to the indico-core Helm chart. It should contain at minimum:

  crunchy-postgres:
    enabled: true
    name: postgres-core
    service:
      metadata:
        labels:
          mirror.linkerd.io/exported: "remote-discovery"
    metadata:
      annotations:
        reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
        reflector.v1.k8s.emberstack.com/reflection-auto-enabled: "true"
    instances:
      - name: pgha1
        replicas: 1
        dataVolumeClaimSpec:
          storageClassName: <storage-class>      # e.g. encrypted-gp3, nfs-client
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: <size>                   # e.g. 100Gi
        resources:
          requests:
            cpu: 2000m
            memory: 8000Mi
    pgBackRestConfig:
      global:
        archive-timeout: "10000"
        repo1-path: "/pgbackrest/postgres-core/repo1"
        repo1-retention-full: "5"
        repo1-s3-kms-key-id: "<kms_key_arn>"    # From Terraform output
        repo1-s3-role: <node_role_name>         # From Terraform output
      repos:
        - name: repo1
          s3:
            bucket: <pgbackup_s3_bucket_name>  # From Terraform output
            endpoint: s3.<region>.amazonaws.com
            region: <region>
          schedules:
            full: 30 4 * * 0
            differential: 0 0 * * *

  Optional sections (if indico-core chart expects them):
    secrets.rabbitmq.create, celery-backend, rabbitmq - for non-postgres components
    storage - for EFS/FSX or indicoStorageClass configuration

  Run 'calculate-values' to generate a values file from Terraform outputs, then
  edit as needed (storage class, size, replicas) before running 'install'.

Usage:
  # From repo root (recommended). Default --tf-dir is repo root when using scripts path.
  python scripts/postgres_migration/postgres_migration.py calculate-values [--tf-dir DIR] -o values.yaml
  python scripts/postgres_migration/postgres_migration.py install --version VERSION -f values.yaml [--helm-repo URL]
  python scripts/postgres_migration/postgres_migration.py bootstrap [--indico-namespace NS] [--postgres-core-namespace NS] [--patroni-patch-wait-sec N] [--skip-schema-parity-for DB ...]
  python scripts/postgres_migration/postgres_migration.py setup-replication [--indico-namespace NS] [--wait-initial-copy] [--fast]
  python scripts/postgres_migration/postgres_migration.py verify-sync [--indico-namespace NS] [--exact] [--replication-only]
  python scripts/postgres_migration/postgres_migration.py migration-diagnose --publisher-namespace NS --publisher-cluster NAME --publisher-db DB --target-db default_* [--target-namespace indico]
  python scripts/postgres_migration/postgres_migration.py refresh-matviews [--indico-namespace NS] [--database DB ...] [--public-only] [--dry-run]
  python scripts/postgres_migration/postgres_migration.py cleanup-publisher-slots --publisher-namespace NS --publisher-cluster NAME [--dry-run]
  python scripts/postgres_migration/postgres_migration.py post-upgrade-cleanup [--indico-namespace NS] [--dry-run]
  python scripts/postgres_migration/postgres_migration.py minio-to-s3 [--dry-run] [--skip-backup-job] [--profile AWS_PROFILE]
  python scripts/postgres_migration/postgres_migration.py migrate-all [--dry-run] [--version VERSION] [-o values.yaml]
"""

import argparse
import base64
import json
import os
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from urllib.parse import quote, quote_plus

# Default Terraform dir: repo root (parent of scripts/). Resolve so paths work from any cwd.
_SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_TF_DIR = _SCRIPT_DIR.parent.parent

# On postgres-data, these logical replication slots are application / existing replicas — never drop during migration cleanup.
POSTGRES_DATA_PROTECTED_REPLICATION_SLOTS: frozenset[str] = frozenset(
    {
        "elnino_replication_slot",
        "moonbow_replication_slot",
        "sunbow_replication_slot",
        "cyclone_replication_slot",
        "noct_replication_slot",
    }
)


def _protected_replication_slots_for_publisher(publisher_cluster_name: str) -> frozenset[str]:
    """Slot names that must not be dropped by migration cleanup for this publisher cluster."""
    if publisher_cluster_name == "postgres-data":
        return POSTGRES_DATA_PROTECTED_REPLICATION_SLOTS
    return frozenset()


# Per-database extension stats; not replicated and not meaningful for cross-cluster row compare.
VERIFY_EXCLUDE_ROWCOUNT_RELATIONS: frozenset[str] = frozenset(
    {"pg_stat_statements", "pg_stat_statements_info"}
)

# Safe PostgreSQL identifiers for dynamic SQL in diagnose (must match publisher relnames).
_SAFE_PG_IDENTIFIER_RE = re.compile(r"^[a-zA-Z_][a-zA-Z0-9_]*$")


def _verify_sync_is_heartbeat_changelog_table(table: str) -> bool:
    """High-churn tables where a 1-row drift during COUNT is expected; do not fail verify-sync on row mismatch."""
    return table.endswith("_heartbeat_changelog")


# Applied to postgres-core and every publisher PostgresCluster before bootstrap schema copy (Crunchy Patroni spec).
BOOTSTRAP_PATRONI_POSTGRESQL_PARAMETERS: dict[str, int | str] = {
    "max_connections": 1000,
    "max_logical_replication_workers": 90,
    "max_parallel_workers_per_gather": 20,
    "max_replication_slots": 130,
    "max_stack_depth": 6144,
    "max_wal_senders": 60,
    "max_worker_processes": 90,
    "wal_level": "logical",
    "work_mem": 131072,
}


def _bootstrap_patroni_merge_patch() -> str:
    """JSON merge patch for spec.patroni.dynamicConfiguration.postgresql.parameters (Crunchy PostgresCluster)."""
    payload = {
        "spec": {
            "patroni": {
                "dynamicConfiguration": {
                    "postgresql": {
                        "parameters": dict(BOOTSTRAP_PATRONI_POSTGRESQL_PARAMETERS),
                    }
                }
            }
        }
    }
    return json.dumps(payload, separators=(",", ":"))


def _patch_postgrescluster_patroni_for_bootstrap(
    namespace: str,
    cluster_name: str,
    kubeconfig: str | None,
) -> subprocess.CompletedProcess:
    return run_kubectl(
        [
            "patch",
            "postgrescluster.postgres-operator.crunchydata.com",
            cluster_name,
            "-n",
            namespace,
            "--type",
            "merge",
            "-p",
            _bootstrap_patroni_merge_patch(),
        ],
        kubeconfig=kubeconfig,
        check=False,
    )


def _patch_postgrescluster_helm_resource_policy_keep(
    namespace: str,
    cluster_name: str,
    kubeconfig: str | None,
) -> subprocess.CompletedProcess:
    """Set helm.sh/resource-policy=keep on a PostgresCluster CR (merge patch)."""
    patch = json.dumps(
        {"metadata": {"annotations": {"helm.sh/resource-policy": "keep"}}},
        separators=(",", ":"),
    )
    return run_kubectl(
        [
            "patch",
            "postgrescluster.postgres-operator.crunchydata.com",
            cluster_name,
            "-n",
            namespace,
            "--type",
            "merge",
            "-p",
            patch,
        ],
        kubeconfig=kubeconfig,
        check=False,
    )


def _pod_is_ready(namespace: str, pod_name: str, kubeconfig: str | None) -> bool:
    r = run_kubectl(
        [
            "get",
            "pod",
            "-n",
            namespace,
            pod_name,
            "-o",
            "jsonpath={.status.conditions[?(@.type==\"Ready\")].status}",
        ],
        kubeconfig=kubeconfig,
        check=False,
    )
    return r.returncode == 0 and r.stdout.strip() == "True"


def _wait_postgrescluster_primary_ready(
    namespace: str,
    cluster_name: str,
    kubeconfig: str | None,
    timeout_sec: int,
    *,
    poll_interval_sec: float = 15.0,
) -> subprocess.CompletedProcess:
    """
    Wait until the primary (or master) pod for the cluster reports Ready.

    ``kubectl wait`` on all pods with the cluster label blocks until *every* replica is Ready; a single
    unhealthy replica would stall bootstrap with no output for the full timeout. Migration only needs the
    primary for pg_dump / exec, so we poll the primary only and print progress periodically.
    """
    deadline = time.monotonic() + float(timeout_sec)
    while time.monotonic() < deadline:
        pod = get_primary_pod(cluster_name, namespace, kubeconfig)
        if pod and _pod_is_ready(namespace, pod, kubeconfig):
            progress(f"  {namespace}/{cluster_name}: primary pod {pod} is Ready.")
            return subprocess.CompletedProcess([], 0, "", "")
        remaining = max(0, int(deadline - time.monotonic()))
        if pod:
            detail = f"primary {pod} not Ready yet"
        else:
            detail = "no primary/master pod in API yet (Patroni may still be electing)"
        progress(f"  {namespace}/{cluster_name}: {detail} ({remaining}s left)")
        sleep_for = min(poll_interval_sec, max(0.5, deadline - time.monotonic()))
        time.sleep(sleep_for)
    pod = get_primary_pod(cluster_name, namespace, kubeconfig)
    err = (
        f"primary pod not Ready within {timeout_sec}s for {namespace}/{cluster_name} "
        f"(last pod name: {pod!r})"
    )
    return subprocess.CompletedProcess([], 1, "", err)


def progress(msg: str, step: int | None = None, total: int | None = None) -> None:
    """Print a progress/status line (flushed so it appears immediately)."""
    if step is not None and total is not None:
        print(f"==> [{step}/{total}] {msg}", flush=True)
    else:
        print(f"==> {msg}", flush=True)


def run_cmd(cmd: list[str], capture_output: bool = True, check: bool = True, **kwargs) -> subprocess.CompletedProcess:
    """Run a command and return the result."""
    result = subprocess.run(
        cmd,
        capture_output=capture_output,
        text=True,
        check=check,
        **kwargs,
    )
    return result


def run_kubectl(args: list[str], kubeconfig: str | None = None, check: bool = True) -> subprocess.CompletedProcess:
    """Run kubectl with optional kubeconfig."""
    cmd = ["kubectl"] + args
    if kubeconfig:
        cmd.extend(["--kubeconfig", str(kubeconfig)])
    return run_cmd(cmd, check=check)


def run_helm(args: list[str], kubeconfig: str | None = None) -> subprocess.CompletedProcess:
    """Run helm with optional kubeconfig."""
    cmd = ["helm"] + args
    env = os.environ.copy()
    if kubeconfig:
        env["KUBECONFIG"] = str(kubeconfig)
    return run_cmd(cmd, env=env)


def helm_indico_core_chart_version(namespace: str = "indico", kubeconfig: str | None = None) -> str | None:
    """Return indico-core chart version from an existing Helm release, or None."""
    try:
        proc = run_helm(["list", "-n", namespace, "-o", "json"], kubeconfig=kubeconfig, check=False)
        if proc.returncode != 0 or not (proc.stdout or "").strip():
            return None
        rows = json.loads(proc.stdout)
        prefix = "indico-core-"
        for row in rows:
            if not isinstance(row, dict) or row.get("name") != "indico-core":
                continue
            chart = str(row.get("chart") or "")
            if chart.startswith(prefix):
                return chart[len(prefix) :]
    except (json.JSONDecodeError, TypeError):
        return None
    return None


def cmd_calculate_values(
    tf_dir: Path,
    output_file: Path | None,
    dry_run: bool = False,
    *,
    az_count: int = 2,
    postgres_volume_size: str = "100Gi",
    storage_class: str = "encrypted-gp3",
    image_registry: str = "harbor.devops.indico.io",
    indico_storage_class_name: str = "indico-sc",
    include_efs: bool = True,
    enable_service_mesh: bool = False,
) -> int:
    """
    Build indico-core values from Terraform outputs and CLI parameters.

    Terraform outputs used (must exist before apply, e.g. from environment workspace):
    kms_key_arn, pgbackup_s3_bucket_name, node_role_name, cluster_region.

    All other values (replicas, storage, storage class, registry, EFS, service mesh)
    are taken from CLI arguments with defaults that match Terraform variable defaults,
    so the script can be run before Terraform changes are applied.
    """
    tf_dir = Path(tf_dir).resolve()
    progress("Initializing Terraform...")
    init_result = run_cmd(
        ["terraform", f"-chdir={tf_dir}", "init", "-input=false"],
        capture_output=True,
        check=False,
    )
    if init_result.returncode != 0:
        print("Warning: terraform init failed, attempting output anyway...", file=sys.stderr)
    progress("Reading Terraform outputs...")
    result = run_cmd(
        ["terraform", f"-chdir={tf_dir}", "output", "-json"],
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        print("Error: Could not read terraform outputs. Ensure workspace is initialized.", file=sys.stderr)
        return 1

    try:
        outputs = json.loads(result.stdout)
    except json.JSONDecodeError as e:
        print(f"Error: Failed to parse terraform output: {e}", file=sys.stderr)
        return 1

    def get_output(name: str, default: str = "") -> str:
        o = outputs.get(name, {})
        if not isinstance(o, dict) or o.get("sensitive"):
            return default
        v = o.get("value")
        if v is None:
            return default
        if isinstance(v, list):
            return str(v[0]) if v else default
        return str(v)

    kms_key_arn = get_output("kms_key_arn")
    pgbackup_bucket = get_output("pgbackup_s3_bucket_name")
    node_role_name = get_output("node_role_name")
    region = get_output("cluster_region") or "us-east-1"

    # All other values come from CLI (defaults match Terraform variables); no Terraform outputs required.
    az_count = max(1, min(3, az_count))
    rabbitmq_persistence_storage_class = indico_storage_class_name if include_efs else ""
    service_mesh_export = "remote-discovery" if enable_service_mesh else "disabled"

    if not pgbackup_bucket or not node_role_name:
        print("Warning: pgbackup_s3_bucket_name and node_role_name outputs recommended for pgBackRest", file=sys.stderr)

    # Build indico-core values override (postgres-core config)
    # Aligns with application.tf crunchy_instances_values: postgres_volume_size, az_count, storage_class
    out_hint = str(output_file) if output_file else "values.yaml"
    output = f"""# indico-core values built from Terraform outputs
# Use: helm upgrade -f {out_hint} indico-core indico-core --version <version> ...
crunchy-postgres:
  enabled: true
  name: postgres-core
  service:
    metadata:
      labels:
        mirror.linkerd.io/exported: "remote-discovery"
  metadata:
    annotations:
      reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
      reflector.v1.k8s.emberstack.com/reflection-auto-enabled: "true"
  instances:
  - name: pgha1
    replicas: {az_count}
    dataVolumeClaimSpec:
      storageClassName: {storage_class}
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: {postgres_volume_size}
    resources:
      requests:
        cpu: 2000m
        memory: 8000Mi
  pgBackRestConfig:
    global:
      archive-timeout: "10000"
      repo1-path: "/pgbackrest/postgres-core/repo1"
      repo1-retention-full: "5"
      repo1-s3-key-type: auto
      repo1-s3-kms-key-id: "{kms_key_arn}"
      repo1-s3-role: {node_role_name}
    repos:
    - name: repo1
      s3:
        bucket: {pgbackup_bucket}
        endpoint: s3.{region}.amazonaws.com
        region: {region}
      schedules:
        full: 30 4 * * 0
        differential: 0 0 * * *
    jobs:
      resources:
        requests:
          cpu: 1000m
          memory: 3000Mi
secrets:
  rabbitmq:
    create: true
celery-backend:
  enabled: true
  image:
    repository: {image_registry}/docker.dragonflydb.io/dragonflydb/dragonfly
rabbitmq:
  enabled: true
  rabbitmq:
    image:
      registry: {image_registry}/dockerhub-proxy
    persistence:
      storageClass: {rabbitmq_persistence_storage_class}
    service:
      labels:
        mirror.linkerd.io/exported: {service_mesh_export}
"""
    if dry_run:
        output += """
indicoConfigs:
  manage: false
"""

    progress("Writing values..." if output_file else "Output (stdout):")
    if output_file:
        out_path = Path(output_file).resolve()
        out_path.write_text(output)
        print(f"Wrote indico-core values to {out_path}")
    else:
        print(output)
    progress("calculate-values complete.")
    return 0


def cmd_install(
    version: str,
    values_file: Path | None,
    tf_dir: Path,
    kubeconfig: str | None,
    helm_repo: str | None,
    dry_run: bool = False,
) -> int:
    """Install indico-core helm chart with specified version."""
    if not version:
        print("Error: --version is required", file=sys.stderr)
        return 1

    if helm_repo:
        repo = helm_repo.rstrip("/")
        if repo.startswith("oci://"):
            # OCI registries: use full chart URL; no "helm repo add" needed
            chart_ref = f"{repo}/indico-core"
        else:
            progress("Adding Helm repo and updating...")
            if not dry_run:
                run_helm(["repo", "add", "indico", helm_repo], kubeconfig=kubeconfig)
                run_helm(["repo", "update"], kubeconfig=kubeconfig)
            chart_ref = "indico/indico-core"
    else:
        chart_ref = "indico-core"  # Assumes repo already configured

    # values-file: YAML with crunchy-postgres config for postgres-core (see module docstring)
    values_path = Path(values_file).resolve() if values_file else None
    if not values_path or not values_path.exists():
        print(
            "Error: --values-file is required. Run 'calculate-values' first to generate from Terraform outputs.",
            file=sys.stderr,
        )
        return 1
    values_args = ["-f", str(values_path)]

    if dry_run:
        # Use helm template so we don't hit the cluster; upgrade --install --dry-run
        # would still check existing resources and fail on pre-existing indico-configs ConfigMap.
        helm_args = [
            "template", "indico-core", chart_ref,
            "--version", version,
            "--namespace", "indico",
            "--set", "indicoConfigs.manage=false",
        ]
        helm_args.extend(values_args)
    else:
        helm_args = [
            "upgrade", "--install", "indico-core", chart_ref,
            "--version", version,
            "--namespace", "indico",
            "--create-namespace",
        ]
        helm_args.append("--wait")
        helm_args.extend(values_args)

    progress("Installing indico-core Helm chart (this may take several minutes)..." if not dry_run else "Would install indico-core Helm chart (dry-run)...")
    try:
        if kubeconfig:
            run_helm(helm_args, kubeconfig=kubeconfig)
        else:
            run_helm(helm_args)
    except subprocess.CalledProcessError as e:
        if e.stdout:
            print(e.stdout, file=sys.stderr)
        if e.stderr:
            print(e.stderr, file=sys.stderr)
        raise
    progress("indico-core helm chart installed successfully." if not dry_run else "Dry-run: install step complete.")
    return 0


def get_postgres_clusters(kubeconfig: str | None) -> list[dict]:
    """List all PostgresClusters across all namespaces."""
    result = run_kubectl(
        [
            "get", "postgresclusters.postgres-operator.crunchydata.com",
            "--all-namespaces", "-o", "json",
        ],
        kubeconfig=kubeconfig,
    )
    data = json.loads(result.stdout)
    return [
        {
            "name": item["metadata"]["name"],
            "namespace": item["metadata"]["namespace"],
        }
        for item in data.get("items", [])
    ]


def get_primary_pod(cluster: str, namespace: str, kubeconfig: str | None) -> str | None:
    """Get the primary pod name for a PostgresCluster (tries master and primary roles)."""
    for role in ("master", "primary"):
        result = run_kubectl(
            [
                "get", "pods", "-n", namespace,
                "-l", f"postgres-operator.crunchydata.com/cluster={cluster},postgres-operator.crunchydata.com/role={role}",
                "-o", "jsonpath={.items[0].metadata.name}",
            ],
            kubeconfig=kubeconfig,
            check=False,
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    return None


def get_databases_from_cluster(cluster: str, namespace: str, kubeconfig: str | None) -> list[str]:
    """Get list of databases from a PostgresCluster."""
    pod = get_primary_pod(cluster, namespace, kubeconfig)
    if not pod:
        return []

    result = run_kubectl(
        [
            "exec", "-n", namespace, pod, "-c", "database", "--",
            "psql", "-t", "-A", "-c",
            "SELECT datname FROM pg_database WHERE datistemplate = false AND datname NOT IN ('postgres');",
        ],
        kubeconfig=kubeconfig,
    )
    return [db.strip() for db in result.stdout.strip().split("\n") if db.strip()]


def get_secret(cluster: str, namespace: str, secret_suffix: str, kubeconfig: str | None) -> dict[str, str]:
    """Get connection details from a Kubernetes secret."""
    secret_name = f"{cluster}-pguser-{secret_suffix}"
    result = run_kubectl(
        ["get", "secret", "-n", namespace, secret_name, "-o", "json"],
        kubeconfig=kubeconfig,
    )
    data = json.loads(result.stdout)
    return {
        k: base64.b64decode(v).decode() if isinstance(v, str) else ""
        for k, v in data.get("data", {}).items()
    }


def _ownership_to_indico_sql(target_db_escaped: str) -> str:
    """SQL to set database owner and reassign only user-schema objects to indico (avoids system objects).
    Tables/views are altered first; sequences linked to tables (SERIAL/IDENTITY) are skipped so we avoid
    'cannot change owner of sequence ... is linked to table' (linked sequences stay with table owner).
    """
    return f'''ALTER DATABASE "{target_db_escaped}" OWNER TO indico;
DO $$
DECLARE
  r RECORD;
  obj_kind TEXT;
BEGIN
  -- User schemas only (exclude pg_catalog, information_schema, pg_toast)
  FOR r IN (SELECT nspname FROM pg_namespace
            WHERE nspname NOT IN ('pg_catalog','information_schema','pg_toast'))
  LOOP
    EXECUTE format('ALTER SCHEMA %I OWNER TO indico', r.nspname);
  END LOOP;
  -- Tables, views, materialized views first (no sequences yet)
  FOR r IN (SELECT n.nspname, c.relname, c.relkind
            FROM pg_class c
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname NOT IN ('pg_catalog','information_schema','pg_toast')
              AND c.relkind IN ('r','v','m'))
  LOOP
    obj_kind := CASE r.relkind WHEN 'r' THEN 'TABLE' WHEN 'v' THEN 'VIEW' WHEN 'm' THEN 'MATERIALIZED VIEW' END;
    EXECUTE format('ALTER %s %I.%I OWNER TO indico', obj_kind, r.nspname, r.relname);
  END LOOP;
  -- Standalone sequences only (skip sequences linked to a table/SERIAL/IDENTITY - those cannot be re-owned separately)
  FOR r IN (SELECT n.nspname, c.relname
            FROM pg_class c
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname NOT IN ('pg_catalog','information_schema','pg_toast')
              AND c.relkind = 'S'
              AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = c.oid AND d.deptype = 'a'))
  LOOP
    EXECUTE format('ALTER SEQUENCE %I.%I OWNER TO indico', r.nspname, r.relname);
  END LOOP;
  -- Types (enums, etc.) in user schemas
  FOR r IN (SELECT n.nspname, t.typname
            FROM pg_type t
            JOIN pg_namespace n ON n.oid = t.typnamespace
            WHERE n.nspname NOT IN ('pg_catalog','information_schema','pg_toast')
              AND t.typtype = 'e')
  LOOP
    EXECUTE format('ALTER TYPE %I.%I OWNER TO indico', r.nspname, r.typname);
  END LOOP;
  -- Functions and procedures in user schemas
  FOR r IN (SELECT p.oid
            FROM pg_proc p
            JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname NOT IN ('pg_catalog','information_schema','pg_toast'))
  LOOP
    EXECUTE format('ALTER FUNCTION %s OWNER TO indico', r.oid::regprocedure);
  END LOOP;
END $$;'''


# User relations in ``public`` used for bootstrap schema parity and verify-sync row counts (matches typical pg_dump scope).
_PUBLIC_SCHEMA_RELATIONS_SQL = (
    "SELECT c.relname FROM pg_class c "
    "JOIN pg_namespace n ON n.oid = c.relnamespace "
    "WHERE n.nspname = 'public' AND c.relkind IN ('r','m','p','v','f') ORDER BY 1;"
)


def _fetch_public_relation_names(
    pod: str,
    namespace: str,
    db: str,
    kubeconfig: str | None,
) -> list[str]:
    result = run_kubectl(
        [
            "exec",
            "-n",
            namespace,
            pod,
            "-c",
            "database",
            "--",
            "psql",
            "-t",
            "-A",
            "-d",
            db,
            "-c",
            _PUBLIC_SCHEMA_RELATIONS_SQL,
        ],
        kubeconfig=kubeconfig,
        check=False,
    )
    if result.returncode != 0:
        return []
    return [r.strip() for r in result.stdout.strip().split("\n") if r.strip()]


def _fetch_extension_names(
    pod: str,
    namespace: str,
    db: str,
    kubeconfig: str | None,
) -> list[str]:
    result = run_kubectl(
        [
            "exec",
            "-n",
            namespace,
            pod,
            "-c",
            "database",
            "--",
            "psql",
            "-t",
            "-A",
            "-d",
            db,
            "-c",
            "SELECT extname FROM pg_extension ORDER BY 1;",
        ],
        kubeconfig=kubeconfig,
        check=False,
    )
    if result.returncode != 0:
        return []
    return [r.strip() for r in result.stdout.strip().split("\n") if r.strip()]


def _bootstrap_skip_schema_parity_for_db(
    *,
    skip_schema_parity: bool,
    skip_schema_parity_for: frozenset[str] | None,
    source_db: str,
    target_db: str,
) -> bool:
    """Whether to skip the post-restore public relation parity check for this database pair."""
    if skip_schema_parity:
        return True
    if not skip_schema_parity_for:
        return False
    return source_db in skip_schema_parity_for or target_db in skip_schema_parity_for


def _skip_schema_parity_for_names(cli_values: list[str] | None) -> frozenset[str] | None:
    """Build a frozenset from repeated ``--skip-schema-parity-for`` args; comma-separated names are split."""
    if not cli_values:
        return None
    names: set[str] = set()
    for item in cli_values:
        for piece in item.split(","):
            s = piece.strip()
            if s:
                names.add(s)
    return frozenset(names) if names else None


def cmd_bootstrap(
    indico_ns: str,
    postgres_core_ns: str,
    kubeconfig: str | None,
    *,
    skip_patroni_patch: bool = False,
    patroni_patch_pod_timeout_sec: int = 600,
    patroni_patch_wait_sec: int = 90,
    skip_schema_parity: bool = False,
    skip_schema_parity_for: frozenset[str] | None = None,
) -> int:
    """
    Bootstrap postgres-core for migration:
    Patch Patroni ``postgresql.parameters`` on postgres-core and every publisher cluster (logical replication
    GUCs), wait for pods to become Ready and an extra pause for reload/restart, then create prefixed databases
    and copy **schemas only** (pg_dump -s / pg_restore), set indico ownership.
    After each restore, compares ``public`` relations (tables, matviews, views, partitioned roots, foreign tables)
    on source vs target; fails if anything present on the publisher is missing on postgres-core (common when
    extensions such as TimescaleDB differ).
    Logical replication (publications/subscriptions) is **not** configured here—run ``setup-replication``.
    """
    progress("Locating source PostgresClusters...")
    target_cluster = "postgres-core"
    sources = [
        c for c in get_postgres_clusters(kubeconfig)
        if c["name"] != target_cluster or c["namespace"] != postgres_core_ns
    ]

    if not sources:
        print("No source PostgresClusters found (excluding postgres-core).")
        return 0

    patch_targets = sorted(
        {(s["namespace"], s["name"]) for s in sources} | {(postgres_core_ns, target_cluster)}
    )
    if not skip_patroni_patch:
        progress(
            f"Patching {len(patch_targets)} PostgresCluster(s) (Patroni postgresql.parameters for migration)..."
        )
        for ns, cl_name in patch_targets:
            progress(f"  patch {ns}/{cl_name}")
            pr = _patch_postgrescluster_patroni_for_bootstrap(ns, cl_name, kubeconfig)
            if pr.returncode != 0:
                print(
                    f"Error: kubectl patch failed for PostgresCluster {ns}/{cl_name} "
                    f"(exit {pr.returncode})",
                    file=sys.stderr,
                )
                if pr.stderr:
                    print(pr.stderr, file=sys.stderr)
                if pr.stdout:
                    print(pr.stdout, file=sys.stderr)
                return 1
        progress(
            "Waiting for each cluster's primary pod to become Ready after Patroni change "
            f"(timeout {patroni_patch_pod_timeout_sec}s per cluster; status every ~15s)..."
        )
        for ns, cl_name in patch_targets:
            wr = _wait_postgrescluster_primary_ready(ns, cl_name, kubeconfig, patroni_patch_pod_timeout_sec)
            if wr.returncode != 0:
                print(f"Error: {wr.stderr}", file=sys.stderr)
                return 1
        progress(
            f"Waiting {patroni_patch_wait_sec}s for PostgreSQL to apply configuration (reload or restart)..."
        )
        time.sleep(float(patroni_patch_wait_sec))
    else:
        progress("Skipping Patroni patch (--skip-patroni-patch).")

    progress(f"Found {len(sources)} source cluster(s). Locating postgres-core primary...")
    core_pod = get_primary_pod(target_cluster, postgres_core_ns, kubeconfig)
    if not core_pod:
        print(f"Error: postgres-core primary pod not found in {postgres_core_ns}", file=sys.stderr)
        return 1

    # Ensure indico role exists on postgres-core (required for ALTER DATABASE / REASSIGN OWNED BY)
    progress("Ensuring indico role exists on postgres-core...")
    ensure_indico = run_kubectl(
        [
            "exec", "-n", postgres_core_ns, core_pod, "-c", "database", "--",
            "psql", "-d", "postgres", "-c",
            "DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'indico') "
            "THEN CREATE ROLE indico WITH LOGIN; END IF; END $$;",
        ],
        kubeconfig=kubeconfig,
        check=False,
    )
    if ensure_indico.returncode != 0:
        print("Warning: Could not ensure indico role exists; ownership changes may fail.", file=sys.stderr)
        if ensure_indico.stderr:
            print(ensure_indico.stderr, file=sys.stderr)

    for idx, src in enumerate(sources, 1):
        src_name, src_ns = src["name"], src["namespace"]
        progress(f"Processing {src_ns}/{src_name}", step=idx, total=len(sources))
        src_pod = get_primary_pod(src_name, src_ns, kubeconfig)
        if not src_pod:
            print(f"Warning: Skipping {src_name}/{src_ns} - primary pod not found")
            continue

        dbs = get_databases_from_cluster(src_name, src_ns, kubeconfig)
        if not dbs:
            print(f"Info: No databases in {src_name}/{src_ns}")
            continue

        # Get replication user - try indico first, then postgres
        rep_user = "indico"
        try:
            get_secret(src_name, src_ns, "indico", kubeconfig)
        except subprocess.CalledProcessError:
            rep_user = "postgres"

        for db in dbs:
            target_db = f"{src_ns}_{db}"
            progress(f"  Migrating {src_ns}/{src_name}/{db} -> {target_db}")

            # 1. Create database on target (postgres-core) with namespace prefix; set owner so DB is indico-owned from the start
            run_kubectl(
                [
                    "exec", "-n", postgres_core_ns, core_pod, "-c", "database", "--",
                    "psql", "-c", f'CREATE DATABASE "{target_db}" OWNER indico;',
                ],
                kubeconfig=kubeconfig,
                check=False,
            )
            # Continue even if database already exists (idempotent)

            # 2. Dump schema from source and restore to target via pipe (binary).
            # pg_restore --no-owner strips ownership: objects are created owned by the restoring user (postgres).
            # --clean --if-exists makes re-runs drop existing objects first (idempotent).
            kc = ["--kubeconfig", kubeconfig] if kubeconfig else []
            dump_cmd = ["kubectl"] + kc + [
                "exec", "-n", src_ns, src_pod, "-c", "database", "--",
                "pg_dump", "-Fc", "-s", "-d", db,
            ]
            restore_cmd = ["kubectl"] + kc + [
                "exec", "-i", "-n", postgres_core_ns, core_pod, "-c", "database", "--",
                "pg_restore", "--no-acl", "--no-owner", "--clean", "--if-exists", "-d", target_db,
            ]
            dump_proc = subprocess.Popen(dump_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            restore_proc = subprocess.Popen(
                restore_cmd, stdin=dump_proc.stdout, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            )
            dump_proc.stdout.close()
            _restore_out, restore_err = restore_proc.communicate()
            dump_rc = dump_proc.wait()
            dump_err = dump_proc.stderr.read() if dump_proc.stderr is not None else b""
            if dump_rc != 0:
                print(f"    Error: pg_dump failed for {src_ns}/{src_name}/{db} (exit {dump_rc})", file=sys.stderr)
                if dump_err.strip():
                    print(dump_err.decode(errors="replace"), file=sys.stderr)
                return 1
            if restore_proc.returncode != 0:
                print(
                    f"    Error: pg_restore failed for {target_db} (exit {restore_proc.returncode})",
                    file=sys.stderr,
                )
                if restore_err:
                    print(restore_err.decode(errors="replace")[:8000], file=sys.stderr)
                return 1
            if restore_err and restore_err.strip():
                # pg_restore sometimes reports recoverable notices on stderr with exit 0
                print(f"    Note: pg_restore stderr: {restore_err.decode(errors='replace')[:2000]}", file=sys.stderr)

            # 3. Set database and object owner to indico. Only reassign objects in user schemas
            # (not pg_catalog/information_schema) to avoid "required by the database system" errors.
            target_db_escaped = target_db.replace('"', '""')
            ownership_sql = _ownership_to_indico_sql(target_db_escaped)
            ownership_result = run_kubectl(
                [
                    "exec", "-n", postgres_core_ns, core_pod, "-c", "database", "--",
                    "psql", "-d", target_db, "-v", "ON_ERROR_STOP=1", "-c", ownership_sql,
                ],
                kubeconfig=kubeconfig,
                check=False,
            )
            if ownership_result.returncode != 0:
                print(f"    Error: Failed to set ownership to indico for {target_db}", file=sys.stderr)
                if ownership_result.stderr:
                    print(ownership_result.stderr, file=sys.stderr)
                return 1

            if not _bootstrap_skip_schema_parity_for_db(
                skip_schema_parity=skip_schema_parity,
                skip_schema_parity_for=skip_schema_parity_for,
                source_db=db,
                target_db=target_db,
            ):
                src_rel = set(_fetch_public_relation_names(src_pod, src_ns, db, kubeconfig))
                tgt_rel = set(_fetch_public_relation_names(core_pod, postgres_core_ns, target_db, kubeconfig))
                missing_on_target = sorted(src_rel - tgt_rel)
                if missing_on_target:
                    print(
                        f"    Error: schema parity check failed for {src_ns}/{src_name}/{db} -> {target_db}: "
                        f"{len(missing_on_target)} relation(s) on the publisher are missing on postgres-core after "
                        "pg_restore.",
                        file=sys.stderr,
                    )
                    print(f"      Missing: {', '.join(missing_on_target)}", file=sys.stderr)
                    ex_src = _fetch_extension_names(src_pod, src_ns, db, kubeconfig)
                    ex_tgt = _fetch_extension_names(core_pod, postgres_core_ns, target_db, kubeconfig)
                    only_src = sorted(set(ex_src) - set(ex_tgt))
                    if only_src:
                        print(
                            f"      Extensions on publisher but not on target DB: {', '.join(only_src)}",
                            file=sys.stderr,
                        )
                    print(
                        "      Fix: install matching extensions on postgres-core (same DB), then re-run bootstrap "
                        "for this database, or inspect pg_restore stderr above. "
                        "Use --skip-schema-parity (all DBs) or --skip-schema-parity-for meteor (single DB) only if "
                        "you accept an incomplete schema.",
                        file=sys.stderr,
                    )
                    return 1
            else:
                if skip_schema_parity_for and (
                    db in skip_schema_parity_for or target_db in skip_schema_parity_for
                ):
                    print(
                        f"    Note: skipped schema parity for {src_ns}/{src_name}/{db} -> {target_db} "
                        "(--skip-schema-parity-for).",
                        file=sys.stderr,
                    )

            # 4. Logical replication setup: requires manual steps or separate script
            # - Create replication user on source (REPLICATION privilege)
            # - Set wal_level=logical on source PostgresCluster
            # - Create publication on source: CREATE PUBLICATION pub FOR ALL TABLES;
            # - Create subscription on target
            print(f"    Schema copied. Set up logical replication for {target_db} (see docs).")
    progress("Bootstrap complete. Run 'setup-replication' to configure logical replication.")
    return 0


def _fetch_logical_replication_gucs(
    core_pod: str,
    indico_ns: str,
    kubeconfig: str | None,
) -> tuple[int | None, int | None]:
    """Read max_logical_replication_workers and max_worker_processes from postgres-core."""
    guc_result = run_kubectl(
        [
            "exec", "-n", indico_ns, core_pod, "-c", "database", "--",
            "psql", "-t", "-A", "-F", "|", "-d", "postgres", "-c",
            "SELECT name, setting FROM pg_settings WHERE name IN ('max_logical_replication_workers','max_worker_processes');",
        ],
        kubeconfig=kubeconfig,
        check=False,
    )
    max_lr: int | None = None
    max_workers: int | None = None
    if guc_result.returncode == 0 and guc_result.stdout.strip():
        for line in guc_result.stdout.strip().split("\n"):
            parts = line.strip().split("|")
            if len(parts) >= 2:
                k, v = parts[0].strip(), parts[1].strip()
                if k == "max_logical_replication_workers":
                    try:
                        max_lr = int(v)
                    except ValueError:
                        pass
                elif k == "max_worker_processes":
                    try:
                        max_workers = int(v)
                    except ValueError:
                        pass
    return max_lr, max_workers


def _emit_replication_worker_guidance(
    *,
    subscription_count: int,
    max_lr: int | None,
    max_workers: int | None,
    no_worker_count: int = 0,
    active_count: int = 0,
    from_setup_replication: bool = False,
) -> None:
    """Explain 'no worker' / row mismatch when logical replication workers are capped cluster-wide."""
    show_gucs = False
    if from_setup_replication and max_lr is not None and subscription_count > max_lr:
        show_gucs = True
        print("", file=sys.stderr)
        print(
            f"==> You configure {subscription_count} subscription(s) but postgres-core "
            f"max_logical_replication_workers={max_lr}.",
            file=sys.stderr,
        )
        print(
            "    Re-running setup-replication will not fix 'no worker' or row-count mismatch.",
            file=sys.stderr,
        )
        print(
            "    Raise max_logical_replication_workers (and max_worker_processes) on postgres-core via Helm / "
            "Crunchy PostgresCluster / Patroni parameters, then apply and let the cluster reload or restart per operator docs.",
            file=sys.stderr,
        )
        print(
            f"    Target: max_logical_replication_workers >= {subscription_count}; "
            "max_worker_processes high enough (e.g. max_logical_replication_workers + 8).",
            file=sys.stderr,
        )

    if no_worker_count > 0:
        show_gucs = True
        print(
            f"\n  Note: {no_worker_count} subscription(s) show 'no worker'; {active_count} active (of {subscription_count} total).",
            file=sys.stderr,
        )
        if max_lr is not None and subscription_count > max_lr:
            print(
                f"  Likely cause: max_logical_replication_workers={max_lr} on postgres-core, but you have {subscription_count} subscriptions.",
                file=sys.stderr,
            )
            print(
                "  PostgreSQL only runs that many logical replication apply workers at once cluster-wide; "
                "extras wait without a worker row in pg_stat_subscription.",
                file=sys.stderr,
            )
            print(
                f"  Fix: raise max_logical_replication_workers to >= {subscription_count} (and max_worker_processes high enough, "
                "e.g. max_logical_replication_workers + 8) in the postgres-core PostgresCluster spec.",
                file=sys.stderr,
            )
        elif not (max_lr is not None and subscription_count > max_lr):
            print("  If limits look fine, check network/auth and postgres-core pod logs.", file=sys.stderr)

    if show_gucs and (max_lr is not None or max_workers is not None):
        print(
            f"  Current GUCs: max_logical_replication_workers={max_lr}, max_worker_processes={max_workers}",
            file=sys.stderr,
        )


def _subscription_create_already_exists(result: subprocess.CompletedProcess) -> bool:
    text = f"{result.stderr or ''} {result.stdout or ''}".lower()
    return "already exists" in text


def _subscription_error_is_replication_slots_exhausted(result: subprocess.CompletedProcess) -> bool:
    text = f"{result.stderr or ''} {result.stdout or ''}".lower()
    return (
        "replication slots are in use" in text
        or "max_replication_slots" in text
        or (
            "could not create replication slot" in text
            and "slots are in use" in text
        )
    )


def _emit_publisher_max_replication_slots_hint(
    src_ns: str,
    src_name: str,
    src_pod: str,
    kubeconfig: str | None,
) -> None:
    """CREATE SUBSCRIPTION creates a logical replication slot on the publisher; explain max_replication_slots."""
    r = run_kubectl(
        [
            "exec", "-n", src_ns, src_pod, "-c", "database", "--",
            "psql", "-t", "-A", "-F", "|", "-d", "postgres", "-c",
            "SELECT (SELECT setting FROM pg_settings WHERE name = 'max_replication_slots'), "
            "(SELECT count(*)::text FROM pg_replication_slots WHERE slot_type = 'logical');",
        ],
        kubeconfig=kubeconfig,
        check=False,
    )
    max_s: int | None = None
    logical: int | None = None
    if r.returncode == 0 and (r.stdout or "").strip():
        parts = r.stdout.strip().split("|")
        if len(parts) >= 2:
            try:
                max_s = int(parts[0].strip())
            except ValueError:
                pass
            try:
                logical = int(parts[1].strip())
            except ValueError:
                pass
    print(
        "  Hint: Logical replication slots are allocated on the **publisher** "
        f"({src_ns}/{src_name}), separate from postgres-core’s logical *apply* worker limits.",
        file=sys.stderr,
    )
    if max_s is not None and logical is not None:
        print(
            f"  Publisher snapshot: max_replication_slots={max_s}, logical slots currently={logical}.",
            file=sys.stderr,
        )
        print(
            "  Fix: raise max_replication_slots on this PostgresCluster to at least the number of logical "
            f"subscriptions you need from this server (you are at the limit: {logical} logical slot(s), "
            f"max allowed {max_s}). Typical values for many DBs: 32–64. Configure in Helm/Crunchy/Patroni, "
            "then reload/restart per operator docs. Or free slots: "
            "`SELECT slot_name, active FROM pg_replication_slots WHERE slot_type = 'logical';`",
            file=sys.stderr,
        )
        rnames = run_kubectl(
            [
                "exec", "-n", src_ns, src_pod, "-c", "database", "--",
                "psql", "-t", "-A", "-d", "postgres", "-c",
                "SELECT string_agg(slot_name, ', ' ORDER BY slot_name) "
                "FROM (SELECT slot_name FROM pg_replication_slots WHERE slot_type = 'logical' LIMIT 25) s;",
            ],
            kubeconfig=kubeconfig,
            check=False,
        )
        if rnames.returncode == 0 and (rnames.stdout or "").strip():
            names = (rnames.stdout or "").strip()
            if len(names) > 400:
                names = names[:400] + "..."
            print(
                f"  Logical slot names on publisher (sample): {names}",
                file=sys.stderr,
            )
        r_sync = run_kubectl(
            [
                "exec", "-n", src_ns, src_pod, "-c", "database", "--",
                "psql", "-t", "-A", "-d", "postgres", "-c",
                "SELECT count(*)::text FROM pg_replication_slots WHERE slot_type = 'logical' "
                "AND slot_name ~ '^pg_[0-9]+_sync_';",
            ],
            kubeconfig=kubeconfig,
            check=False,
        )
        sync_n: int | None = None
        if r_sync.returncode == 0 and (r_sync.stdout or "").strip():
            try:
                sync_n = int((r_sync.stdout or "").strip())
            except ValueError:
                pass
        if sync_n is not None and sync_n > 0:
            print(
                f"  Table-sync slots (pg_<oid>_sync_<...>): {sync_n} — PostgreSQL creates these on the publisher "
                "during **initial table copy** (often one per table while copying). "
                "They are **separate** from your long-lived app slots and from the single `sub_*` slot per DB. "
                "Starting many subscriptions **before** earlier ones finish initial copy stacks sync slots and "
                "can exhaust max_replication_slots even when cleanup is correct. "
                "Default `setup-replication` creates subscriptions **in parallel** (no wait); size "
                "`max_replication_slots` on the publisher accordingly, or use `--wait-initial-copy` to serialize. "
                "Orphans from failed runs: check `active`; drop inactive with `pg_drop_replication_slot(name)` "
                "or raise max_replication_slots.",
                file=sys.stderr,
            )
        print(
            "  Note: Orphan **main** slots (`sub_*`) are dropped before each CREATE when possible. "
            "That does not remove stray **sync** slots—`setup-replication` also prunes inactive `pg_*_sync_*` "
            "after each DB when possible.",
            file=sys.stderr,
        )
    else:
        print(
            "  Fix: raise max_replication_slots on the publisher PostgresCluster or drop unused logical slots "
            "on the publisher primary.",
            file=sys.stderr,
        )


def _pg_subscription_exists_on_subscriber(
    core_pod: str,
    indico_ns: str,
    target_db: str,
    sub_name: str,
    kubeconfig: str | None,
) -> bool:
    sn_lit = sub_name.replace("'", "''")
    r = run_kubectl(
        [
            "exec", "-n", indico_ns, core_pod, "-c", "database", "--",
            "psql", "-U", "postgres", "-t", "-A", "-d", target_db, "-v", "ON_ERROR_STOP=1", "-c",
            f"SELECT count(*)::text FROM pg_subscription "
            f"WHERE subname = '{sn_lit}' "
            f"AND subdbid = (SELECT oid FROM pg_database WHERE datname = current_database());",
        ],
        kubeconfig=kubeconfig,
        check=False,
    )
    if r.returncode != 0:
        return False
    out = (r.stdout or "").strip()
    try:
        return int(out) > 0
    except ValueError:
        return False


def _subscription_debug_row(
    core_pod: str,
    indico_ns: str,
    target_db: str,
    sub_name: str,
    kubeconfig: str | None,
) -> str:
    """Return concise debug info for one subscription in a DB (password redacted)."""
    sn_lit = sub_name.replace("'", "''")
    r = run_kubectl(
        [
            "exec", "-n", indico_ns, core_pod, "-c", "database", "--",
            "psql", "-U", "postgres", "-t", "-A", "-d", target_db, "-v", "ON_ERROR_STOP=1", "-c",
            "SELECT s.subname, r.rolname, s.subenabled, COALESCE(s.subslotname,'<null>'), "
            "COALESCE(array_to_string(s.subpublications, ','), '<none>'), COALESCE(s.subconninfo, '<null>') "
            "FROM pg_subscription s "
            "JOIN pg_roles r ON r.oid = s.subowner "
            f"WHERE s.subname = '{sn_lit}' "
            "AND s.subdbid = (SELECT oid FROM pg_database WHERE datname = current_database()) "
            "LIMIT 1;",
        ],
        kubeconfig=kubeconfig,
        check=False,
    )
    if r.returncode != 0:
        return f"{sub_name}|<query-failed>|{(r.stderr or '').strip()[:250]}"
    line = (r.stdout or "").strip()
    if not line:
        return f"{sub_name}|<not-found>"
    # Redact password in subconninfo for safe terminal logs.
    return re.sub(r"(password=)([^\s]+)", r"\1<redacted>", line)


def _drop_subscription_on_subscriber_for_recreate(
    core_pod: str,
    indico_ns: str,
    target_db: str,
    sub_name: str,
    kubeconfig: str | None,
    indico_password: str | None = None,
) -> bool:
    """Remove subscription on postgres-core without requiring a successful remote slot drop.

    Plain ``DROP SUBSCRIPTION`` contacts the publisher to drop the slot; if the publisher errors
    (e.g. slot already gone), the drop fails and the local subscription remains.

    PostgreSQL 15+ (incl. 17): ``ALTER SUBSCRIPTION ... DISABLE`` then
    ``ALTER SUBSCRIPTION ... SET (slot_name = NONE)``, then ``DROP SUBSCRIPTION`` — no remote slot
    drop is attempted (see PostgreSQL docs for DROP SUBSCRIPTION).

    Requires PostgreSQL **15+** (``slot_name = NONE``). On older versions, drop the subscription
    manually (e.g. PG 14 ``DROP SUBSCRIPTION ... NOSLOT``).
    """
    if not _pg_subscription_exists_on_subscriber(core_pod, indico_ns, target_db, sub_name, kubeconfig):
        return True

    # Keep DDL as standalone statements (not inside DO/transaction block).
    # Try likely subscription-owner roles in order: indico, default psql user, postgres.
    sub_ident = '"' + sub_name.replace('"', '""') + '"'

    def _run_cleanup_with_psql_user(psql_user: str | None) -> list[str]:
        user_args = ["-U", psql_user] if psql_user else []
        psql_cmd = ["psql", *user_args, "-d", target_db, "-v", "ON_ERROR_STOP=0"]
        if psql_user == "indico" and indico_password:
            # Force TCP so pg_hba "host" entries apply for indico.
            psql_cmd = ["env", f"PGPASSWORD={indico_password}", "psql", "-h", "127.0.0.1", *user_args, "-d", target_db, "-v", "ON_ERROR_STOP=0"]
        diagnostics: list[str] = []
        cmds = [
            ("ALTER SUBSCRIPTION DISABLE", f"ALTER SUBSCRIPTION {sub_ident} DISABLE;"),
            ("ALTER SUBSCRIPTION SET (slot_name = NONE)", f"ALTER SUBSCRIPTION {sub_ident} SET (slot_name = NONE);"),
            ("DROP SUBSCRIPTION", f"DROP SUBSCRIPTION IF EXISTS {sub_ident};"),
        ]
        for label, sql in cmds:
            r = run_kubectl(
                [
                    "exec", "-n", indico_ns, core_pod, "-c", "database", "--",
                    *psql_cmd, "-c", sql,
                ],
                kubeconfig=kubeconfig,
                check=False,
            )
            merged = ((r.stdout or "") + "\n" + (r.stderr or "")).strip()
            out = merged.lower()
            has_sql_error = "error:" in out
            if (
                (r.returncode != 0 or has_sql_error)
                and "does not exist" not in out
                and "not supported by the remote server version" not in out
            ):
                who = psql_user or "<default>"
                diag = merged[:500]
                diagnostics.append(
                    f"{label} failed for subscription {sub_name} in {target_db} as {who}: {diag}"
                )
        return diagnostics

    diagnostics = _run_cleanup_with_psql_user("indico")
    if _pg_subscription_exists_on_subscriber(core_pod, indico_ns, target_db, sub_name, kubeconfig):
        diagnostics.extend(_run_cleanup_with_psql_user(None))
    if _pg_subscription_exists_on_subscriber(core_pod, indico_ns, target_db, sub_name, kubeconfig):
        diagnostics.extend(_run_cleanup_with_psql_user("postgres"))
    if _pg_subscription_exists_on_subscriber(core_pod, indico_ns, target_db, sub_name, kubeconfig):
        # Ownership can block DDL even for valid login roles; try as postgres with SET ROLE <subscription owner>.
        sub_lit = sub_name.replace("'", "''")
        owner_q = run_kubectl(
            [
                "exec", "-n", indico_ns, core_pod, "-c", "database", "--",
                "psql", "-U", "postgres", "-t", "-A", "-d", target_db, "-v", "ON_ERROR_STOP=1", "-c",
                "SELECT r.rolname FROM pg_subscription s "
                "JOIN pg_roles r ON r.oid = s.subowner "
                f"WHERE s.subname = '{sub_lit}' "
                "AND s.subdbid = (SELECT oid FROM pg_database WHERE datname = current_database()) "
                "LIMIT 1;",
            ],
            kubeconfig=kubeconfig,
            check=False,
        )
        owner = (owner_q.stdout or "").strip()
        if owner:
            owner_ident = '"' + owner.replace('"', '""') + '"'
            for label, sql in [
                ("ALTER SUBSCRIPTION DISABLE (as owner)", f"ALTER SUBSCRIPTION {sub_ident} DISABLE"),
                ("ALTER SUBSCRIPTION SET (slot_name = NONE) (as owner)", f"ALTER SUBSCRIPTION {sub_ident} SET (slot_name = NONE)"),
                ("DROP SUBSCRIPTION (as owner)", f"DROP SUBSCRIPTION IF EXISTS {sub_ident}"),
            ]:
                stmt = f"SET ROLE {owner_ident}; {sql}; RESET ROLE;"
                r = run_kubectl(
                    [
                        "exec", "-n", indico_ns, core_pod, "-c", "database", "--",
                        "psql", "-U", "postgres", "-d", target_db, "-v", "ON_ERROR_STOP=0", "-c", stmt,
                    ],
                    kubeconfig=kubeconfig,
                    check=False,
                )
                merged = ((r.stdout or "") + "\n" + (r.stderr or "")).strip()
                out = merged.lower()
                has_sql_error = "error:" in out
                if (
                    (r.returncode != 0 or has_sql_error)
                    and "does not exist" not in out
                    and "not supported by the remote server version" not in out
                ):
                    diagnostics.append(
                        f"{label} failed for subscription {sub_name} in {target_db} as postgres->owner({owner}): {merged[:500]}"
                    )
        else:
            msg = (owner_q.stderr or owner_q.stdout or "").strip()[:500]
            diagnostics.append(
                f"Owner lookup failed for subscription {sub_name} in {target_db} as postgres: {msg or 'no owner row returned'}"
            )

    if not _pg_subscription_exists_on_subscriber(core_pod, indico_ns, target_db, sub_name, kubeconfig):
        return True

    # Always emit useful server-side state when a subscription remains.
    sub_lit = sub_name.replace("'", "''")
    state_q = run_kubectl(
        [
            "exec", "-n", indico_ns, core_pod, "-c", "database", "--",
            "psql", "-U", "postgres", "-t", "-A", "-d", target_db, "-v", "ON_ERROR_STOP=1", "-c",
            "SELECT s.subname, r.rolname, s.subenabled, COALESCE(s.subslotname,'<null>') "
            "FROM pg_subscription s "
            "JOIN pg_roles r ON r.oid = s.subowner "
            f"WHERE s.subname = '{sub_lit}' "
            "AND s.subdbid = (SELECT oid FROM pg_database WHERE datname = current_database()) "
            "LIMIT 1;",
        ],
        kubeconfig=kubeconfig,
        check=False,
    )
    if state_q.returncode == 0 and (state_q.stdout or "").strip():
        print(
            f"    Remaining subscription state ({target_db}): {(state_q.stdout or '').strip()}",
            file=sys.stderr,
        )
    elif state_q.stderr:
        print(
            f"    Could not read remaining subscription state in {target_db}: {state_q.stderr.strip()[:500]}",
            file=sys.stderr,
        )

    # Force one strict DROP attempt so exact PostgreSQL error is visible.
    pre_cnt = run_kubectl(
        [
            "exec", "-n", indico_ns, core_pod, "-c", "database", "--",
            "psql", "-U", "postgres", "-t", "-A", "-d", target_db, "-v", "ON_ERROR_STOP=1", "-c",
            f"SELECT count(*)::text FROM pg_subscription "
            f"WHERE subname = '{sub_lit}' "
            f"AND subdbid = (SELECT oid FROM pg_database WHERE datname = current_database());",
        ],
        kubeconfig=kubeconfig,
        check=False,
    )
    if pre_cnt.returncode == 0 and (pre_cnt.stdout or "").strip():
        print(f"    Existence count before strict DROP ({target_db}.{sub_name}): {(pre_cnt.stdout or '').strip()}", file=sys.stderr)

    strict_drop = run_kubectl(
        [
            "exec", "-n", indico_ns, core_pod, "-c", "database", "--",
            "psql", "-U", "postgres", "-d", target_db, "-v", "ON_ERROR_STOP=1", "-c",
            f"DROP SUBSCRIPTION IF EXISTS {sub_ident};",
        ],
        kubeconfig=kubeconfig,
        check=False,
    )
    strict_out = ((strict_drop.stdout or "") + "\n" + (strict_drop.stderr or "")).strip()
    if strict_out:
        print(f"    Strict DROP diagnostics for {sub_name} in {target_db}: {strict_out[:700]}", file=sys.stderr)

    post_cnt = run_kubectl(
        [
            "exec", "-n", indico_ns, core_pod, "-c", "database", "--",
            "psql", "-U", "postgres", "-t", "-A", "-d", target_db, "-v", "ON_ERROR_STOP=1", "-c",
            f"SELECT count(*)::text FROM pg_subscription "
            f"WHERE subname = '{sub_lit}' "
            f"AND subdbid = (SELECT oid FROM pg_database WHERE datname = current_database());",
        ],
        kubeconfig=kubeconfig,
        check=False,
    )
    if post_cnt.returncode == 0 and (post_cnt.stdout or "").strip():
        print(f"    Existence count after strict DROP ({target_db}.{sub_name}): {(post_cnt.stdout or '').strip()}", file=sys.stderr)

    # Re-check after strict DROP attempt before declaring failure.
    if not _pg_subscription_exists_on_subscriber(core_pod, indico_ns, target_db, sub_name, kubeconfig):
        return True

    # Show connection context from the same target DB to aid debugging.
    ctx = run_kubectl(
        [
            "exec", "-n", indico_ns, core_pod, "-c", "database", "--",
            "psql", "-U", "postgres", "-t", "-A", "-d", target_db, "-v", "ON_ERROR_STOP=1", "-c",
            "SELECT current_database(), current_user, pg_is_in_recovery()::text, "
            "COALESCE(inet_server_addr()::text,'<local>'), inet_server_port()::text;",
        ],
        kubeconfig=kubeconfig,
        check=False,
    )
    if ctx.returncode == 0 and (ctx.stdout or "").strip():
        print(f"    DB context for failed drop: {(ctx.stdout or '').strip()}", file=sys.stderr)
    elif ctx.stderr:
        print(f"    Could not read DB context: {ctx.stderr.strip()[:500]}", file=sys.stderr)

    for msg in diagnostics[-6:]:
        print(f"    {msg}", file=sys.stderr)
    print(
        f"    Subscription {sub_name} still present in {target_db} on pod {core_pod} after cleanup attempts (-U indico, default user, -U postgres). "
        "Check role privileges/ownership and postgres logs.",
        file=sys.stderr,
    )
    return False


def _migration_subscription_slot_prefix(publisher_namespace: str, publisher_cluster_name: str) -> str:
    """Prefix for main subscription replication slot names (matches setup-replication sub_name pattern)."""
    return f"sub_{publisher_namespace}_{publisher_cluster_name}_".replace("-", "_")


def _list_migration_logical_slots_on_publisher(
    src_pod: str,
    src_ns: str,
    slot_prefix: str,
    kubeconfig: str | None,
) -> list[str]:
    """Logical slots created by this migration: main ``sub_<ns>_<cluster>_`` slots and ``pg_*_sync_*`` table-sync slots."""
    if not re.fullmatch(r"[a-z0-9_]+", slot_prefix):
        raise ValueError(f"unsafe slot_prefix for regex: {slot_prefix!r}")
    plit = slot_prefix.replace("'", "''")
    r = run_kubectl(
        [
            "exec", "-n", src_ns, src_pod, "-c", "database", "--",
            "psql", "-t", "-A", "-d", "postgres", "-c",
            f"SELECT slot_name FROM pg_replication_slots WHERE slot_type = 'logical' "
            f"AND (slot_name ~ '^{plit}' OR slot_name ~ '^pg_[0-9]+_sync_') ORDER BY 1;",
        ],
        kubeconfig=kubeconfig,
        check=False,
    )
    if r.returncode != 0:
        if r.stderr:
            print(f"Warning: could not list replication slots: {r.stderr.strip()[:300]}", file=sys.stderr)
        return []
    return [ln.strip() for ln in (r.stdout or "").splitlines() if ln.strip()]


def _run_migration_publisher_slot_cleanup(
    src_pod: str,
    src_ns: str,
    src_name: str,
    kubeconfig: str | None,
    *,
    dry_run: bool,
    quiet_if_empty: bool,
) -> int:
    """Drop migration-pattern logical slots on this publisher. Returns count dropped (or would drop). Respects postgres-data protected slots."""
    prefix = _migration_subscription_slot_prefix(src_ns, src_name)
    try:
        raw = _list_migration_logical_slots_on_publisher(src_pod, src_ns, prefix, kubeconfig)
    except ValueError as e:
        print(f"  Warning: publisher slot cleanup skipped: {e}", file=sys.stderr)
        return 0
    protected = _protected_replication_slots_for_publisher(src_name)
    to_drop = [s for s in raw if s not in protected]
    skipped = [s for s in raw if s in protected]
    if skipped:
        print(
            f"  Skipping protected slot(s) on postgres-data: {', '.join(sorted(skipped))}",
            file=sys.stderr,
        )
    if not to_drop:
        if not quiet_if_empty:
            progress(
                f"No matching logical slots on {src_ns}/{src_name} "
                f"(prefix {prefix!r}, pg_*_sync_*; protected names excluded)."
            )
        return 0
    progress(
        f"{'Would drop' if dry_run else 'Dropping'} {len(to_drop)} migration logical slot(s) "
        f"on {src_ns}/{src_name}..."
    )
    for sn in to_drop:
        if dry_run:
            print(f"  [dry-run] {sn}")
        else:
            _drop_logical_slot_on_publisher_if_exists(src_pod, src_ns, sn, kubeconfig)
            print(f"  Dropped {sn}")
    return len(to_drop)


def cmd_cleanup_publisher_migration_slots(
    kubeconfig: str | None,
    dry_run: bool,
    *,
    publisher_namespace: str | None,
    publisher_cluster: str | None,
    indico_namespace: str,
    all_migration_sources: bool,
) -> int:
    """Drop logical replication slots on publisher(s) that match this script’s naming (destructive)."""
    target_cluster = "postgres-core"

    def clean_one(pub_ns: str, pub_name: str) -> int:
        pod = get_primary_pod(pub_name, pub_ns, kubeconfig)
        if not pod:
            print(f"Error: primary pod not found for {pub_ns}/{pub_name}", file=sys.stderr)
            return 1
        _run_migration_publisher_slot_cleanup(
            pod, pub_ns, pub_name, kubeconfig, dry_run=dry_run, quiet_if_empty=False
        )
        return 0

    if all_migration_sources:
        sources = [
            c
            for c in get_postgres_clusters(kubeconfig)
            if c["name"] != target_cluster or c["namespace"] != indico_namespace
        ]
        if not sources:
            print("No migration publisher clusters found (excluding postgres-core in indico namespace).")
            return 0
        rc = 0
        for src in sources:
            progress(f"Publisher {src['namespace']}/{src['name']}")
            if clean_one(src["namespace"], src["name"]) != 0:
                rc = 1
        return rc

    if not publisher_namespace or not publisher_cluster:
        print(
            "Error: specify --publisher-namespace and --publisher-cluster, or use --all-migration-sources.",
            file=sys.stderr,
        )
        return 1
    return clean_one(publisher_namespace, publisher_cluster)


def _patch_postgrescluster_shutdown(
    namespace: str,
    cluster_name: str,
    kubeconfig: str | None,
    *,
    shutdown: bool,
) -> subprocess.CompletedProcess:
    """Patch spec.shutdown for a PostgresCluster (Crunchy PG Operator)."""
    patch = json.dumps({"spec": {"shutdown": shutdown}}, separators=(",", ":"))
    return run_kubectl(
        [
            "patch",
            "postgrescluster.postgres-operator.crunchydata.com",
            cluster_name,
            "-n",
            namespace,
            "--type",
            "merge",
            "-p",
            patch,
        ],
        kubeconfig=kubeconfig,
        check=False,
    )


def cmd_post_upgrade_cleanup(
    indico_ns: str,
    kubeconfig: str | None,
    *,
    dry_run: bool = False,
) -> int:
    """
    After cutover/upgrade:
    1) Drop subscriptions from postgres-core (all non-template DBs).
    2) Drop migration logical slots from every publisher PostgresCluster.
    3) Patch publisher PostgresClusters to ``spec.shutdown=true``.

    ``postgres-core`` is never shutdown.
    """
    target_cluster = "postgres-core"
    rc = 0

    core_pod = get_primary_pod(target_cluster, indico_ns, kubeconfig)
    if not core_pod:
        print(f"Error: postgres-core primary pod not found in {indico_ns}", file=sys.stderr)
        return 1
    progress(f"Using postgres-core primary pod: {indico_ns}/{core_pod}")

    indico_password = ""
    try:
        # Secret name resolves to postgres-core-pguser-indico via get_secret().
        indico_password = get_secret(target_cluster, indico_ns, "indico", kubeconfig).get("password", "") or ""
    except subprocess.CalledProcessError:
        print(
            "Warning: could not read postgres-core indico secret; indico cleanup attempt may fail pg_hba.",
            file=sys.stderr,
        )

    progress("Step 1/3: Removing subscriptions from postgres-core...")
    core_dbs = get_databases_from_cluster(target_cluster, indico_ns, kubeconfig)
    for db in core_dbs:
        progress(f"  Enumerating subscriptions in db={db} on pod={core_pod}")
        db_ctx = run_kubectl(
            [
                "exec", "-n", indico_ns, core_pod, "-c", "database", "--",
                "psql", "-U", "postgres", "-t", "-A", "-d", db, "-v", "ON_ERROR_STOP=1", "-c",
                "SELECT current_database(), current_user;",
            ],
            kubeconfig=kubeconfig,
            check=False,
        )
        if db_ctx.returncode == 0 and (db_ctx.stdout or "").strip():
            print(f"    DB context while listing subscriptions: {(db_ctx.stdout or '').strip()}", file=sys.stderr)
        r = run_kubectl(
            [
                "exec",
                "-n",
                indico_ns,
                core_pod,
                "-c",
                "database",
                "--",
                "psql",
                "-U",
                "postgres",
                "-t",
                "-A",
                "-d",
                db,
                "-c",
                "SELECT subname FROM pg_subscription "
                "WHERE subdbid = (SELECT oid FROM pg_database WHERE datname = current_database()) "
                "ORDER BY 1;",
            ],
            kubeconfig=kubeconfig,
            check=False,
        )
        if r.returncode != 0:
            print(f"  Warning: could not list subscriptions in {db}; skipping.", file=sys.stderr)
            if r.stderr:
                print(f"    {r.stderr.strip()[:500]}", file=sys.stderr)
            rc = 1
            continue
        sub_names = [ln.strip() for ln in (r.stdout or "").splitlines() if ln.strip()]
        if not sub_names:
            continue
        for sub_name in sub_names:
            if dry_run:
                print(f"  [dry-run] would drop subscription {db}.{sub_name}")
                continue
            print(
                f"    Subscription debug before drop ({db}): "
                f"{_subscription_debug_row(core_pod, indico_ns, db, sub_name, kubeconfig)}",
                file=sys.stderr,
            )
            ok = _drop_subscription_on_subscriber_for_recreate(
                core_pod,
                indico_ns,
                db,
                sub_name,
                kubeconfig,
                indico_password=indico_password,
            )
            if ok:
                print(f"  Dropped subscription {db}.{sub_name}")
            else:
                rc = 1

    progress("Step 2/3: Removing migration replication slots from publishers...")
    publishers = [
        c for c in get_postgres_clusters(kubeconfig) if c["name"] != target_cluster
    ]
    for pub in publishers:
        pub_ns, pub_name = pub["namespace"], pub["name"]
        pub_pod = get_primary_pod(pub_name, pub_ns, kubeconfig)
        if not pub_pod:
            print(f"  Warning: primary pod not found for {pub_ns}/{pub_name}; skipping.", file=sys.stderr)
            rc = 1
            continue
        progress(f"  Using publisher primary pod for slot cleanup: {pub_ns}/{pub_pod}")
        _run_migration_publisher_slot_cleanup(
            pub_pod,
            pub_ns,
            pub_name,
            kubeconfig,
            dry_run=dry_run,
            quiet_if_empty=True,
        )

    progress("Step 3/3: Shutting down publisher PostgresClusters (excluding postgres-core)...")
    for pub in publishers:
        pub_ns, pub_name = pub["namespace"], pub["name"]
        if dry_run:
            print(f"  [dry-run] would patch {pub_ns}/{pub_name} spec.shutdown=true")
            continue
        pr = _patch_postgrescluster_shutdown(pub_ns, pub_name, kubeconfig, shutdown=True)
        if pr.returncode != 0:
            print(f"  Error: failed to patch shutdown for {pub_ns}/{pub_name}", file=sys.stderr)
            if pr.stderr:
                print(f"    {pr.stderr.strip()[:500]}", file=sys.stderr)
            rc = 1
        else:
            print(f"  Patched {pub_ns}/{pub_name} spec.shutdown=true")

    progress("post-upgrade-cleanup complete." if rc == 0 else "post-upgrade-cleanup completed with warnings/errors.")
    return rc


def _drop_logical_slot_on_publisher_if_exists(
    src_pod: str,
    src_ns: str,
    slot_name: str,
    kubeconfig: str | None,
) -> None:
    """On publisher primary: stop active slot consumer and drop logical slot (default slot name = subscription name)."""
    slot_lit = slot_name.replace("'", "''")
    run_kubectl(
        [
            "exec", "-n", src_ns, src_pod, "-c", "database", "--",
            "psql", "-d", "postgres", "-c",
            f"SELECT pg_terminate_backend(active_pid) FROM pg_replication_slots "
            f"WHERE slot_name = '{slot_lit}' AND active_pid IS NOT NULL;",
        ],
        kubeconfig=kubeconfig,
        check=False,
    )
    run_kubectl(
        [
            "exec", "-n", src_ns, src_pod, "-c", "database", "--",
            "psql", "-d", "postgres", "-c",
            f"SELECT pg_drop_replication_slot('{slot_lit}');",
        ],
        kubeconfig=kubeconfig,
        check=False,
    )


def _wait_subscription_initial_copy_done_on_subscriber(
    core_pod: str,
    indico_ns: str,
    target_db: str,
    sub_name: str,
    kubeconfig: str | None,
    *,
    timeout_sec: int = 86400,
    poll_sec: float = 5.0,
) -> bool:
    """Return True when no ``pg_subscription_rel`` row is still initializing (``i``) or copying (``d``).

    During initial logical replication, PostgreSQL creates many temporary logical **table-sync** slots
    on the **publisher** (names like ``pg_<oid>_sync_*``). They count toward ``max_replication_slots``.
    Creating the next subscription before the previous subscription finishes initial copy stacks those
    slots — so total slots can be **far** above (app slots + one ``sub_*`` per DB), even when cleanup
    and ``sub_*`` logic are correct.
    """
    sn = sub_name.replace("'", "''")
    sql = (
        "SELECT COALESCE(NOT EXISTS (SELECT 1 FROM pg_subscription_rel sr "
        "JOIN pg_subscription s ON s.oid = sr.srsubid "
        f"WHERE s.subname = '{sn}' AND sr.srsubstate IN ('i', 'd')), true);"
    )
    deadline = time.monotonic() + timeout_sec
    start = time.monotonic()
    last_progress = start
    said_waiting = False
    while time.monotonic() < deadline:
        r = run_kubectl(
            [
                "exec", "-n", indico_ns, core_pod, "-c", "database", "--",
                "psql", "-t", "-A", "-d", target_db, "-v", "ON_ERROR_STOP=1", "-c", sql,
            ],
            kubeconfig=kubeconfig,
            check=False,
        )
        if r.returncode == 0:
            out = (r.stdout or "").strip().lower()
            if out in ("t", "true", "1"):
                return True
        if not said_waiting:
            print(
                f"  Waiting for initial table copy on {target_db} ({sub_name}) before next subscription "
                f"(avoids stacking publisher pg_*_sync_* slots)...",
                file=sys.stderr,
            )
            said_waiting = True
        now = time.monotonic()
        if now - last_progress >= 30:
            elapsed = int(now - start)
            print(
                f"    ... still in initial copy ({elapsed}s elapsed, timeout {timeout_sec}s)",
                file=sys.stderr,
            )
            last_progress = now
        time.sleep(poll_sec)
    return False


def _drop_inactive_pg_sync_slots_on_publisher(
    src_pod: str,
    src_ns: str,
    kubeconfig: str | None,
) -> int:
    """Drop inactive logical slots named pg_<oid>_sync_* (finished table-sync); frees max_replication_slots.

    Uses one publisher ``psql`` round-trip (PL/pgSQL loop) instead of two ``kubectl exec``s per slot, which
    was very slow when dozens of table-sync slots finished at once (e.g. 55 slots → 110 execs).
    """
    count_sql = (
        "SELECT count(*)::text FROM pg_replication_slots WHERE slot_type = 'logical' "
        "AND active IS NOT TRUE AND slot_name ~ '^pg_[0-9]+_sync_';"
    )
    bulk_drop = r"""
DO $pg_sync_prune$
DECLARE
  r RECORD;
  pid INTEGER;
BEGIN
  FOR r IN
    SELECT slot_name FROM pg_replication_slots
    WHERE slot_type = 'logical'
      AND active IS NOT TRUE
      AND slot_name ~ '^pg_[0-9]+_sync_'
  LOOP
    BEGIN
      SELECT s.active_pid INTO pid
      FROM pg_replication_slots s
      WHERE s.slot_name = r.slot_name;
      IF pid IS NOT NULL THEN
        PERFORM pg_terminate_backend(pid);
      END IF;
      PERFORM pg_drop_replication_slot(r.slot_name);
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  END LOOP;
END
$pg_sync_prune$;
"""
    r_cnt = run_kubectl(
        [
            "exec", "-n", src_ns, src_pod, "-c", "database", "--",
            "psql", "-t", "-A", "-d", "postgres", "-v", "ON_ERROR_STOP=1", "-c",
            count_sql,
        ],
        kubeconfig=kubeconfig,
        check=False,
    )
    if r_cnt.returncode != 0:
        return 0
    cnt_s = (r_cnt.stdout or "").strip()
    if not cnt_s:
        return 0
    try:
        n = int(cnt_s)
    except ValueError:
        return 0
    if n <= 0:
        return 0

    r_do = run_kubectl(
        [
            "exec", "-n", src_ns, src_pod, "-c", "database", "--",
            "psql", "-d", "postgres", "-v", "ON_ERROR_STOP=1", "-c",
            bulk_drop,
        ],
        kubeconfig=kubeconfig,
        check=False,
    )
    if r_do.returncode != 0:
        if r_do.stderr:
            print(f"  Warning: bulk prune of pg_*_sync_* slots failed: {r_do.stderr.strip()[:400]}", file=sys.stderr)
        return 0
    return n


def _precheck_publisher_reachable_from_core(
    core_pod: str,
    indico_ns: str,
    src_host: str,
    publisher_db: str,
    replication_password: str,
    kubeconfig: str | None,
) -> subprocess.CompletedProcess:
    """From postgres-core primary, connect as rep_migration to publisher DB (same path logical replication uses)."""
    pw_encoded = quote_plus(replication_password, safe="")
    db_in_uri = quote(publisher_db, safe="")
    uri = (
        f"postgresql://rep_migration:{pw_encoded}@{src_host}:5432/{db_in_uri}"
        f"?connect_timeout=10&application_name=setup_replication_precheck"
    )
    return run_kubectl(
        [
            "exec", "-n", indico_ns, core_pod, "-c", "database", "--",
            "psql", uri, "-v", "ON_ERROR_STOP=1", "-c", "SELECT 1 AS replication_route_ok;",
        ],
        kubeconfig=kubeconfig,
        check=False,
    )


def cmd_setup_replication(
    indico_ns: str,
    kubeconfig: str | None,
    replication_password: str = "changeme",
    *,
    wait_initial_copy: bool = False,
    initial_copy_timeout_sec: int = 86400,
    fast: bool = False,
) -> int:
    """
    Set up logical replication from source PostgresClusters to postgres-core.
    Requires: wal_level=logical on source clusters (add to PostgresCluster spec).
    Creates replication user, publication on source, subscription on target.

    By default creates each subscription **without** waiting for the previous DB’s initial copy to finish
    (fast; requires high enough ``max_replication_slots`` on publishers for stacked ``pg_*_sync_*`` slots).
    Pass ``wait_initial_copy=True`` or ``--wait-initial-copy`` to wait between DBs (slower, fewer slots).

    Pass ``fast=True`` or ``--fast`` to skip postgres-core→publisher route precheck per DB and skip the
    post-create sleep/worker diagnostics (fewer round-trips; use when the path is already verified).

    Before creating subscriptions, every PostgresCluster except ``postgres-core`` is patched with
    ``metadata.annotations.helm.sh/resource-policy: keep`` so Helm upgrades are less likely to prune
    publisher clusters during migration.
    """
    skip_route_precheck = fast
    skip_post_create_diagnostics = fast
    target_cluster = "postgres-core"
    progress("Annotating PostgresClusters with helm.sh/resource-policy=keep (except postgres-core)...")
    for c in sorted(get_postgres_clusters(kubeconfig), key=lambda x: (x["namespace"], x["name"])):
        if c["name"] == target_cluster:
            continue
        pr = _patch_postgrescluster_helm_resource_policy_keep(c["namespace"], c["name"], kubeconfig)
        if pr.returncode != 0:
            print(
                f"Error: kubectl patch failed for PostgresCluster {c['namespace']}/{c['name']} "
                "(helm.sh/resource-policy keep).",
                file=sys.stderr,
            )
            if pr.stderr:
                print(pr.stderr.strip(), file=sys.stderr)
            if pr.stdout:
                print(pr.stdout.strip(), file=sys.stderr)
            return 1
        progress(f"  {c['namespace']}/{c['name']}: helm.sh/resource-policy=keep")

    progress("Locating source PostgresClusters...")
    sources = [
        c for c in get_postgres_clusters(kubeconfig)
        if c["name"] != target_cluster or c["namespace"] != indico_ns
    ]

    core_pod = get_primary_pod(target_cluster, indico_ns, kubeconfig)
    if not core_pod:
        print(f"Error: postgres-core primary pod not found in {indico_ns}", file=sys.stderr)
        return 1
    subscription_failures: list[str] = []
    subscription_planned = 0  # one subscription per source DB we process (cluster-wide worker limit applies)
    progress(f"Setting up replication for {len(sources)} source(s)...")
    for idx, src in enumerate(sources, 1):
        src_name, src_ns = src["name"], src["namespace"]
        progress(f"Source {src_ns}/{src_name}", step=idx, total=len(sources))
        src_pod = get_primary_pod(src_name, src_ns, kubeconfig)
        if not src_pod:
            continue

        dbs = get_databases_from_cluster(src_name, src_ns, kubeconfig)
        if not dbs:
            continue

        try:
            get_secret(src_name, src_ns, "indico", kubeconfig)
        except subprocess.CalledProcessError:
            print(f"  Skip {src_ns}/{src_name}: no indico user secret")
            continue

        # Clear migration-pattern slots on publisher first (sub_* + pg_*_sync_*); keeps postgres-data app slots.
        _run_migration_publisher_slot_cleanup(
            src_pod, src_ns, src_name, kubeconfig, dry_run=False, quiet_if_empty=True
        )

        src_host = f"{src_name}-primary.{src_ns}.svc"

        # Check wal_level=logical on source (required for logical replication)
        wal_check = run_kubectl(
            [
                "exec", "-n", src_ns, src_pod, "-c", "database", "--",
                "psql", "-t", "-A", "-d", "postgres", "-c", "SHOW wal_level;",
            ],
            kubeconfig=kubeconfig,
            check=False,
        )
        if wal_check.returncode == 0 and "logical" not in wal_check.stdout.lower():
            print(f"  Warning: {src_ns}/{src_name} wal_level={wal_check.stdout.strip()}, need 'logical' in PostgresCluster spec")

        # Replication role is cluster-wide; one CREATE per source (not per database).
        safe_pw = replication_password.replace("'", "''")
        run_kubectl(
            [
                "exec", "-n", src_ns, src_pod, "-c", "database", "--",
                "psql", "-d", "postgres", "-c",
                f"DO $$ BEGIN CREATE USER rep_migration WITH REPLICATION PASSWORD '{safe_pw}'; "
                f"EXCEPTION WHEN duplicate_object THEN NULL; END $$;",
            ],
            kubeconfig=kubeconfig,
            check=False,
        )

        for db in dbs:
            target_db = f"{src_ns}_{db}"
            # Subscription name becomes replication slot name on publisher; slot names may only contain [a-z0-9_]
            sub_name = f"sub_{src_ns}_{src_name}_{db}".replace("-", "_")[:63]
            pub_name = f"pub_{src_ns}_{db}"
            progress(
                f"  Replication mapping: source={src_ns}/{src_name}/{db} -> "
                f"target_db={target_db}, publication={pub_name}, subscription={sub_name}"
            )

            # Publication + grants in one exec (fewer kubectl round-trips per DB).
            pub_and_grants = (
                f"DROP PUBLICATION IF EXISTS {pub_name}; "
                f"CREATE PUBLICATION {pub_name} FOR ALL TABLES; "
                f"GRANT SELECT ON ALL TABLES IN SCHEMA public TO rep_migration;"
            )
            run_kubectl(
                [
                    "exec", "-n", src_ns, src_pod, "-c", "database", "--",
                    "psql", "-d", db, "-c", pub_and_grants,
                ],
                kubeconfig=kubeconfig,
                check=False,
            )

            # Same route as CREATE SUBSCRIPTION: postgres-core -> publisher primary Service DNS, rep_migration, target DB.
            if not skip_route_precheck:
                route_check = _precheck_publisher_reachable_from_core(
                    core_pod,
                    indico_ns,
                    src_host,
                    db,
                    replication_password,
                    kubeconfig,
                )
                if route_check.returncode != 0:
                    print(
                        f"  Error: postgres-core cannot reach publisher for subscription "
                        f"({src_host}:5432, db={db}, user=rep_migration). "
                        f"Logical replication would fail; fix network/DNS/NetworkPolicy/pg_hba before continuing.",
                        file=sys.stderr,
                    )
                    if route_check.stderr:
                        print(f"    {route_check.stderr.strip()[:500]}", file=sys.stderr)
                    subscription_failures.append(f"{target_db} ({sub_name}) publisher unreachable from core")
                    continue

            subscription_planned += 1

            # Create subscription on target (use rep_migration for logical replication).
            # CREATE SUBSCRIPTION cannot run inside a transaction block, so run DROP and CREATE in separate psql invocations.
            conn_str_rep = f"host={src_host} user=rep_migration dbname={db} password={safe_pw}"
            run_kubectl(
                [
                    "exec", "-n", indico_ns, core_pod, "-c", "database", "--",
                    "psql", "-d", target_db, "-c", f"DROP SUBSCRIPTION IF EXISTS {sub_name};",
                ],
                kubeconfig=kubeconfig,
                check=False,
            )
            # Free publisher slot for this subscription name if orphaned (e.g. prior SET (slot_name = NONE)
            # + DROP on subscriber, or failed remote DROP). Orphans still consume max_replication_slots and
            # look like "duplicates" when re-running setup.
            _drop_logical_slot_on_publisher_if_exists(src_pod, src_ns, sub_name, kubeconfig)

            create_sql = (
                f"CREATE SUBSCRIPTION {sub_name} CONNECTION '{conn_str_rep}' PUBLICATION {pub_name};"
            )
            sub_result = run_kubectl(
                [
                    "exec", "-n", indico_ns, core_pod, "-c", "database", "--",
                    "psql", "-d", target_db, "-v", "ON_ERROR_STOP=1", "-c",
                    create_sql,
                ],
                kubeconfig=kubeconfig,
                check=False,
            )
            if sub_result.returncode != 0 and _subscription_error_is_replication_slots_exhausted(sub_result):
                print(
                    "  Retrying CREATE once after publisher slot cleanup (orphan slot may have blocked quota)...",
                    file=sys.stderr,
                )
                _drop_logical_slot_on_publisher_if_exists(src_pod, src_ns, sub_name, kubeconfig)
                time.sleep(1)
                sub_result = run_kubectl(
                    [
                        "exec", "-n", indico_ns, core_pod, "-c", "database", "--",
                        "psql", "-d", target_db, "-v", "ON_ERROR_STOP=1", "-c",
                        create_sql,
                    ],
                    kubeconfig=kubeconfig,
                    check=False,
                )
            if sub_result.returncode != 0 and _subscription_error_is_replication_slots_exhausted(sub_result):
                print(
                    "  Pruning inactive table-sync slots on publisher and retrying CREATE...",
                    file=sys.stderr,
                )
                n_sync = _drop_inactive_pg_sync_slots_on_publisher(src_pod, src_ns, kubeconfig)
                if n_sync:
                    print(f"    Dropped {n_sync} inactive pg_*_sync_* slot(s).", file=sys.stderr)
                time.sleep(2)
                sub_result = run_kubectl(
                    [
                        "exec", "-n", indico_ns, core_pod, "-c", "database", "--",
                        "psql", "-d", target_db, "-v", "ON_ERROR_STOP=1", "-c",
                        create_sql,
                    ],
                    kubeconfig=kubeconfig,
                    check=False,
                )
            subscription_ok = False
            if sub_result.returncode == 0:
                print(f"  Set up replication: {src_ns}/{src_name}/{db} -> {target_db}")
                print(
                    f"    Subscription debug after create ({target_db}): "
                    f"{_subscription_debug_row(core_pod, indico_ns, target_db, sub_name, kubeconfig)}",
                    file=sys.stderr,
                )
                subscription_ok = True
            elif _subscription_create_already_exists(sub_result):
                # Prior DROP can fail silently (e.g. publisher unreachable during DROP); force drop + slot cleanup + recreate.
                print(
                    f"  Subscription already exists for {target_db} ({sub_name}); dropping and recreating...",
                    file=sys.stderr,
                )
                if not _drop_subscription_on_subscriber_for_recreate(
                    core_pod, indico_ns, target_db, sub_name, kubeconfig
                ):
                    subscription_failures.append(f"{target_db} ({sub_name}) could not drop for recreate")
                    continue
                _drop_logical_slot_on_publisher_if_exists(
                    src_pod, src_ns, sub_name, kubeconfig
                )
                sub_retry = run_kubectl(
                    [
                        "exec", "-n", indico_ns, core_pod, "-c", "database", "--",
                        "psql", "-d", target_db, "-v", "ON_ERROR_STOP=1", "-c",
                        create_sql,
                    ],
                    kubeconfig=kubeconfig,
                    check=False,
                )
                if sub_retry.returncode != 0 and _subscription_error_is_replication_slots_exhausted(sub_retry):
                    print(
                        "  Retrying recreate once after publisher slot cleanup...",
                        file=sys.stderr,
                    )
                    _drop_logical_slot_on_publisher_if_exists(
                        src_pod, src_ns, sub_name, kubeconfig
                    )
                    time.sleep(1)
                    sub_retry = run_kubectl(
                        [
                            "exec", "-n", indico_ns, core_pod, "-c", "database", "--",
                            "psql", "-d", target_db, "-v", "ON_ERROR_STOP=1", "-c",
                            create_sql,
                        ],
                        kubeconfig=kubeconfig,
                        check=False,
                    )
                if sub_retry.returncode != 0 and _subscription_error_is_replication_slots_exhausted(sub_retry):
                    print(
                        "  Pruning inactive table-sync slots on publisher and retrying recreate...",
                        file=sys.stderr,
                    )
                    n_sync2 = _drop_inactive_pg_sync_slots_on_publisher(src_pod, src_ns, kubeconfig)
                    if n_sync2:
                        print(f"    Dropped {n_sync2} inactive pg_*_sync_* slot(s).", file=sys.stderr)
                    time.sleep(2)
                    sub_retry = run_kubectl(
                        [
                            "exec", "-n", indico_ns, core_pod, "-c", "database", "--",
                            "psql", "-d", target_db, "-v", "ON_ERROR_STOP=1", "-c",
                            create_sql,
                        ],
                        kubeconfig=kubeconfig,
                        check=False,
                    )
                if sub_retry.returncode == 0:
                    print(f"  Set up replication: {src_ns}/{src_name}/{db} -> {target_db} (recreated)")
                    subscription_ok = True
                else:
                    print(
                        f"  Error: Failed to recreate subscription for {src_ns}/{src_name}/{db} -> {target_db}",
                        file=sys.stderr,
                    )
                    if sub_retry.stderr:
                        print(sub_retry.stderr, file=sys.stderr)
                    if sub_retry.stdout:
                        print(sub_retry.stdout, file=sys.stderr)
                    if _subscription_error_is_replication_slots_exhausted(sub_retry):
                        _emit_publisher_max_replication_slots_hint(
                            src_ns, src_name, src_pod, kubeconfig
                        )
                    subscription_failures.append(f"{target_db} ({sub_name})")
                    continue
            else:
                print(f"  Error: Failed to create subscription for {src_ns}/{src_name}/{db} -> {target_db}", file=sys.stderr)
                if sub_result.stderr:
                    print(sub_result.stderr, file=sys.stderr)
                if sub_result.stdout:
                    print(sub_result.stdout, file=sys.stderr)
                if _subscription_error_is_replication_slots_exhausted(sub_result):
                    _emit_publisher_max_replication_slots_hint(
                        src_ns, src_name, src_pod, kubeconfig
                    )
                subscription_failures.append(f"{target_db} ({sub_name})")
                continue

            if subscription_ok:
                if wait_initial_copy:
                    if not _wait_subscription_initial_copy_done_on_subscriber(
                        core_pod,
                        indico_ns,
                        target_db,
                        sub_name,
                        kubeconfig,
                        timeout_sec=initial_copy_timeout_sec,
                    ):
                        print(
                            f"  Error: initial copy for {target_db} ({sub_name}) did not finish within "
                            f"{initial_copy_timeout_sec}s. Stopping further subscriptions on this publisher. "
                            f"Fix: re-run setup-replication, or increase --initial-copy-timeout-sec. "
                            f"(Omit --wait-initial-copy next time if you prefer parallel creates + higher "
                            f"max_replication_slots.)",
                            file=sys.stderr,
                        )
                        subscription_failures.append(
                            f"{target_db} ({sub_name}) initial copy wait timeout"
                        )
                        break
                n_pr = _drop_inactive_pg_sync_slots_on_publisher(src_pod, src_ns, kubeconfig)
                if n_pr:
                    print(
                        f"  Pruned {n_pr} inactive table-sync slot(s) on publisher (frees quota for next DB).",
                        file=sys.stderr,
                    )

            # Optional: brief wait + worker row + connectivity hints (skippable for speed).
            if not skip_post_create_diagnostics:
                time.sleep(3)
                sub_name_sql = sub_name.replace("'", "''")
                worker_check = run_kubectl(
                    [
                        "exec", "-n", indico_ns, core_pod, "-c", "database", "--",
                        "psql", "-t", "-A", "-d", target_db, "-c",
                        f"SELECT 1 FROM pg_stat_subscription s JOIN pg_subscription sub ON s.subid = sub.oid WHERE sub.subname = '{sub_name_sql}';",
                    ],
                    kubeconfig=kubeconfig,
                    check=False,
                )
                if worker_check.returncode != 0 or not worker_check.stdout.strip():
                    print(f"  Warning: {target_db} / {sub_name} has no active apply worker after 3s.", file=sys.stderr)
                    print(f"    Publisher: {src_host} (db={db}, user=rep_migration). Check:", file=sys.stderr)
                    print(f"    (1) Network: from postgres-core pod, can you reach {src_host}:5432?", file=sys.stderr)
                    print(f"    (2) Auth: rep_migration on source must allow replication; pg_hba.conf on source.", file=sys.stderr)
                    print(f"    (3) Pod logs: kubectl logs -n {indico_ns} <postgres-core-primary-pod> -c database", file=sys.stderr)
                    try:
                        pw_encoded = quote_plus(replication_password, safe="")
                        uri = f"postgresql://rep_migration:{pw_encoded}@{src_host}:5432/{db}"
                        conn_test = run_kubectl(
                            [
                                "exec", "-n", indico_ns, core_pod, "-c", "database", "--",
                                "psql", uri, "-c", "SELECT 1;",
                            ],
                            kubeconfig=kubeconfig,
                            check=False,
                        )
                        if conn_test.returncode != 0:
                            print(f"    Connectivity test (psql from postgres-core to {src_host}): FAILED", file=sys.stderr)
                            if conn_test.stderr:
                                print(f"    {conn_test.stderr.strip()[:400]}", file=sys.stderr)
                        else:
                            print(
                                f"    Connectivity test to {src_host}: OK (worker may still be starting or check postgres logs).",
                                file=sys.stderr,
                            )
                    except Exception as e:
                        print(f"    Connectivity test skipped: {e}", file=sys.stderr)
    if subscription_failures:
        print(f"Replication setup had {len(subscription_failures)} failure(s). Run 'verify-sync' to check.", file=sys.stderr)
        max_lr, max_workers = _fetch_logical_replication_gucs(core_pod, indico_ns, kubeconfig)
        _emit_replication_worker_guidance(
            subscription_count=subscription_planned,
            max_lr=max_lr,
            max_workers=max_workers,
            from_setup_replication=True,
        )
        return 1
    max_lr, max_workers = _fetch_logical_replication_gucs(core_pod, indico_ns, kubeconfig)
    _emit_replication_worker_guidance(
        subscription_count=subscription_planned,
        max_lr=max_lr,
        max_workers=max_workers,
        from_setup_replication=True,
    )
    progress("Replication setup complete. Run 'verify-sync' to check subscription health and row counts.")
    return 0


def _collect_postgres_core_subscription_status_rows(
    core_pod: str,
    indico_ns: str,
    kubeconfig: str | None,
) -> tuple[list[tuple[str, str, str, str, str, str, str]], list[str], bool]:
    """Return (rows, db_names_scanned, ok). Each row: db, subname, worker, enabled, lsn, send_time, recv_time."""
    list_dbs_result = run_kubectl(
        [
            "exec", "-n", indico_ns, core_pod, "-c", "database", "--",
            "psql", "-t", "-A", "-d", "postgres", "-c",
            "SELECT datname FROM pg_database WHERE datistemplate = false AND datname <> 'postgres' ORDER BY datname;",
        ],
        kubeconfig=kubeconfig,
        check=False,
    )
    if list_dbs_result.returncode != 0:
        return [], [], False
    target_dbs = [db.strip() for db in list_dbs_result.stdout.strip().split("\n") if db.strip()]
    if not target_dbs:
        return [], [], True

    query = """
    SELECT current_database(), sub.subname,
           CASE WHEN s.pid IS NOT NULL THEN 'active' ELSE 'no worker' END,
           sub.subenabled::text,
           COALESCE(s.received_lsn::text, ''), COALESCE(s.last_msg_send_time::text, ''),
           COALESCE(s.last_msg_receipt_time::text, '')
    FROM pg_subscription sub
    LEFT JOIN pg_stat_subscription s ON s.subid = sub.oid
    WHERE sub.subdbid = (SELECT oid FROM pg_database WHERE datname = current_database());
    """
    lines: list[str] = []
    for target_db in target_dbs:
        result = run_kubectl(
            [
                "exec", "-n", indico_ns, core_pod, "-c", "database", "--",
                "psql", "-t", "-A", "-F", "|", "-d", target_db, "-c", query,
            ],
            kubeconfig=kubeconfig,
            check=False,
        )
        if result.returncode == 0 and result.stdout.strip():
            lines.extend(result.stdout.strip().split("\n"))
        elif result.returncode != 0 and result.stderr and "does not exist" not in result.stderr:
            print(f"  Warning: subscription query failed for DB {target_db}: {result.stderr[:200]}", file=sys.stderr)

    rows: list[tuple[str, str, str, str, str, str, str]] = []
    for line in lines:
        parts = line.split("|")
        if len(parts) >= 7:
            rows.append(
                (
                    parts[0].strip(),
                    parts[1].strip(),
                    parts[2].strip(),
                    parts[3].strip(),
                    parts[4].strip(),
                    parts[5].strip(),
                    parts[6].strip(),
                )
            )
    rows.sort(key=lambda r: (r[0], r[1]))
    return rows, target_dbs, True


def _get_tables_and_row_counts(
    pod: str,
    namespace: str,
    db: str,
    kubeconfig: str | None,
    exact: bool,
) -> dict[str, int]:
    """Return dict of relation name -> row count for user objects in ``public`` (relkind r,m,p,v,f).

    Uses the same relation list as bootstrap schema parity (``pg_class``), not only ``pg_stat_user_tables``,
    so views and other objects counted on the publisher also appear here. Estimates use ``n_live_tup`` where
    stats exist (views may show 0 until counted).
    """
    if exact:
        tables = _fetch_public_relation_names(pod, namespace, db, kubeconfig)
        if not tables:
            return {}
        out: dict[str, int] = {}
        for relname in tables:
            quoted = '"' + relname.replace('"', '""') + '"'
            r = run_kubectl(
                [
                    "exec", "-n", namespace, pod, "-c", "database", "--",
                    "psql", "-t", "-A", "-d", db, "-c",
                    f"SELECT count(*) FROM {quoted};",
                ],
                kubeconfig=kubeconfig,
                check=False,
            )
            if r.returncode == 0 and r.stdout.strip():
                try:
                    out[relname] = int(r.stdout.strip())
                except ValueError:
                    out[relname] = -1
            else:
                out[relname] = -1
        for _k in VERIFY_EXCLUDE_ROWCOUNT_RELATIONS:
            out.pop(_k, None)
        return out
    result = run_kubectl(
        [
            "exec", "-n", namespace, pod, "-c", "database", "--",
            "psql", "-t", "-A", "-F", "|", "-d", db, "-c",
            "SELECT c.relname, COALESCE(s.n_live_tup::bigint, 0) "
            "FROM pg_class c "
            "JOIN pg_namespace n ON n.oid = c.relnamespace "
            "LEFT JOIN pg_stat_user_tables s ON s.relid = c.oid "
            "WHERE n.nspname = 'public' AND c.relkind IN ('r','m','p','v','f') "
            "ORDER BY 1;",
        ],
        kubeconfig=kubeconfig,
        check=False,
    )
    if result.returncode != 0 or not result.stdout.strip():
        return {}
    out: dict[str, int] = {}
    for line in result.stdout.strip().split("\n"):
        parts = line.strip().split("|")
        if len(parts) >= 2:
            try:
                out[parts[0].strip()] = int(parts[1].strip())
            except ValueError:
                out[parts[0].strip()] = -1
    for _k in VERIFY_EXCLUDE_ROWCOUNT_RELATIONS:
        out.pop(_k, None)
    return out


def _psql_name_array(names: list[str]) -> str | None:
    """``ARRAY['a','b']::name[]`` for safe identifier-only names; None if any name is unsafe."""
    for n in names:
        if not _SAFE_PG_IDENTIFIER_RE.match(n):
            return None
    inner = ",".join(f"'{n}'" for n in names)
    return f"ARRAY[{inner}]::name[]"


def _fetch_extension_versions(
    pod: str,
    namespace: str,
    db: str,
    kubeconfig: str | None,
) -> list[tuple[str, str]]:
    result = run_kubectl(
        [
            "exec",
            "-n",
            namespace,
            pod,
            "-c",
            "database",
            "--",
            "psql",
            "-t",
            "-A",
            "-F",
            "|",
            "-d",
            db,
            "-c",
            "SELECT extname, extversion FROM pg_extension ORDER BY 1;",
        ],
        kubeconfig=kubeconfig,
        check=False,
    )
    if result.returncode != 0:
        return []
    rows: list[tuple[str, str]] = []
    for line in result.stdout.strip().split("\n"):
        parts = line.strip().split("|")
        if len(parts) >= 2:
            rows.append((parts[0].strip(), parts[1].strip()))
    return rows


def cmd_migration_diagnose(
    kubeconfig: str | None,
    publisher_namespace: str,
    publisher_cluster: str,
    publisher_db: str,
    target_namespace: str,
    target_db: str,
) -> int:
    """
    Explain likely causes when ``public`` relations exist on the publisher but not on postgres-core after bootstrap.

    Prints extension version diffs, then for each missing relation: relkind, owner, extension membership,
    and (for views / matviews) a truncated definition. Read the closing notes for pg_restore vs logical replication.
    """
    progress("Locating primary pods...")
    src_pod = get_primary_pod(publisher_cluster, publisher_namespace, kubeconfig)
    tgt_pod = get_primary_pod("postgres-core", target_namespace, kubeconfig)
    if not src_pod:
        print(
            f"Error: primary pod not found for {publisher_namespace}/{publisher_cluster}",
            file=sys.stderr,
        )
        return 1
    if not tgt_pod:
        print(f"Error: postgres-core primary pod not found in {target_namespace}", file=sys.stderr)
        return 1

    src_rels = set(_fetch_public_relation_names(src_pod, publisher_namespace, publisher_db, kubeconfig))
    tgt_rels = set(_fetch_public_relation_names(tgt_pod, target_namespace, target_db, kubeconfig))
    missing_on_target = sorted(src_rels - tgt_rels)
    extra_on_target = sorted(tgt_rels - src_rels)

    print("\n=== Extensions: publisher vs target ===\n")
    src_ext = _fetch_extension_versions(src_pod, publisher_namespace, publisher_db, kubeconfig)
    tgt_ext = _fetch_extension_versions(tgt_pod, target_namespace, target_db, kubeconfig)
    src_map = dict(src_ext)
    tgt_map = dict(tgt_ext)
    all_ext = sorted(set(src_map) | set(tgt_map))
    if not all_ext:
        print("(no extensions listed — check psql errors)")
    else:
        print(f"{'extname':<28} {'publisher ver':<18} {'target ver':<18}")
        print("-" * 66)
        for name in all_ext:
            sv = src_map.get(name, "—")
            tv = tgt_map.get(name, "—")
            flag = ""
            if name in src_map and name not in tgt_map:
                flag = "  << missing on target"
            elif name not in src_map and name in tgt_map:
                flag = "  << only on target"
            elif src_map.get(name) != tgt_map.get(name):
                flag = "  << version mismatch"
            print(f"{name:<28} {sv:<18} {tv:<18}{flag}")

    only_src_ext = sorted(set(src_map) - set(tgt_map))
    if only_src_ext:
        print(
            f"\nPublisher-only extensions (often explain failed pg_restore DDL on target): {', '.join(only_src_ext)}",
        )

    print("\n=== public relations: counts ===\n")
    print(f"  publisher {publisher_db}: {len(src_rels)} relations")
    print(f"  target    {target_db}: {len(tgt_rels)} relations")
    print(f"  on publisher only (missing on target): {len(missing_on_target)}")
    if extra_on_target:
        print(f"  on target only (extra): {len(extra_on_target)} — {', '.join(extra_on_target[:20])}")
        if len(extra_on_target) > 20:
            print(f"    ... and {len(extra_on_target) - 20} more")

    if not missing_on_target:
        print("\nNo missing relations; schema list matches for public (r/m/p/v/f).")
        print("\nNotes:")
        print(
            "  - Row-level verify issues may still be materialized views (not in logical replication) or "
            "concurrent writes."
        )
        return 0

    print("\n=== Missing on target: metadata from publisher (relkind / owner / extension) ===\n")
    arr_sql = _psql_name_array(missing_on_target)
    if not arr_sql:
        print("  (cannot run batch query: unexpected relation names)", file=sys.stderr)
        return 1
    meta_sql = (
        "SELECT c.relname, c.relkind, pg_catalog.pg_get_userbyid(c.relowner), "
        "COALESCE( "
        "(SELECT string_agg(e.extname || ' ' || e.extversion, ', ' ORDER BY e.extname) "
        " FROM pg_depend d2 JOIN pg_extension e ON e.oid = d2.refobjid "
        " WHERE d2.objid = c.oid AND d2.deptype = 'e' "
        "   AND d2.refclassid = 'pg_extension'::regclass), "
        "''"
        ") "
        "FROM pg_class c "
        "JOIN pg_namespace n ON n.oid = c.relnamespace "
        f"WHERE n.nspname = 'public' AND c.relname = ANY({arr_sql}) "
        "ORDER BY 1;"
    )
    meta = run_kubectl(
        [
            "exec",
            "-n",
            publisher_namespace,
            src_pod,
            "-c",
            "database",
            "--",
            "psql",
            "-t",
            "-A",
            "-F",
            "|",
            "-d",
            publisher_db,
            "-c",
            meta_sql,
        ],
        kubeconfig=kubeconfig,
        check=False,
    )
    if meta.returncode != 0:
        print(f"Error running metadata query: {meta.stderr}", file=sys.stderr)
        return 1
    kind_map: dict[str, str] = {}
    print(f"{'relname':<36} {'kind':<4} {'owner':<20} {'extension':<30}")
    print("-" * 96)
    for line in meta.stdout.strip().split("\n"):
        parts = line.strip().split("|")
        if len(parts) >= 4:
            relname, rk, owner, ext = (parts[0].strip(), parts[1].strip(), parts[2].strip(), parts[3].strip())
            kind_map[relname] = rk
            rk_exp = {"r": "table", "m": "matview", "v": "view", "p": "part.root", "f": "foreign"}.get(rk, rk)
            print(f"{relname:<36} {rk_exp:<4} {owner:<20} {ext:<30}")

    views = [n for n in missing_on_target if kind_map.get(n) == "v"]
    matviews = [n for n in missing_on_target if kind_map.get(n) == "m"]

    if views:
        print("\n=== View definitions on publisher (truncated) ===\n")
        v_arr = _psql_name_array(views)
        if v_arr:
            vsql = (
                "SELECT c.relname, LEFT(pg_catalog.pg_get_viewdef(c.oid, true), 4000) "
                "FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace "
                f"WHERE n.nspname = 'public' AND c.relkind = 'v' AND c.relname = ANY({v_arr}) ORDER BY 1;"
            )
            vr = run_kubectl(
                [
                    "exec",
                    "-n",
                    publisher_namespace,
                    src_pod,
                    "-c",
                    "database",
                    "--",
                    "psql",
                    "-t",
                    "-A",
                    "-F",
                    "|",
                    "-d",
                    publisher_db,
                    "-c",
                    vsql,
                ],
                kubeconfig=kubeconfig,
                check=False,
            )
            if vr.returncode == 0 and vr.stdout.strip():
                for line in vr.stdout.strip().split("\n"):
                    pv = line.split("|", 1)
                    if len(pv) >= 2:
                        print(f"--- {pv[0].strip()} ---\n{pv[1].strip()[:2000]}\n")

    if matviews:
        print("\n=== Materialized views missing on target ===\n")
        mv_arr = _psql_name_array(matviews)
        if mv_arr:
            msql = (
                "SELECT matviewname, LEFT(definition, 4000) FROM pg_matviews "
                f"WHERE schemaname = 'public' AND matviewname = ANY({mv_arr}) ORDER BY 1;"
            )
            mr = run_kubectl(
                [
                    "exec",
                    "-n",
                    publisher_namespace,
                    src_pod,
                    "-c",
                    "database",
                    "--",
                    "psql",
                    "-t",
                    "-A",
                    "-F",
                    "|",
                    "-d",
                    publisher_db,
                    "-c",
                    msql,
                ],
                kubeconfig=kubeconfig,
                check=False,
            )
            if mr.returncode == 0 and mr.stdout.strip():
                for line in mr.stdout.strip().split("\n"):
                    pm = line.split("|", 1)
                    if len(pm) >= 2:
                        print(f"--- {pm[0].strip()} (matview) ---\n{pm[1].strip()[:2000]}\n")

    print("\n=== How to read this ===\n")
    print(
        "  • Publisher-only extension: install the same extension on postgres-core in the target database, "
        "then re-run bootstrap (schema-only dump/restore) for that DB."
    )
    print(
        "  • relkind view/matview with no extension: pg_restore may have failed silently earlier; check "
        "bootstrap pg_restore stderr, or run pg_dump -s on the publisher and pg_restore -v on a scratch DB."
    )
    print(
        "  • Materialized views are not replicated by PostgreSQL logical replication; after the object exists "
        "on the subscriber, run: python ... refresh-matviews [--database default_meteor] (or REFRESH manually)."
    )
    print(
        "  • Timescale continuous aggregates / compressed hypertables often need the same TimescaleDB version "
        "on both clusters."
    )
    return 1


def _list_matview_qualified_names(
    pod: str,
    namespace: str,
    db: str,
    kubeconfig: str | None,
    *,
    public_schema_only: bool,
) -> tuple[list[str], str]:
    """Return (qualified names, error message). Error non-empty if listing failed."""
    extra = " AND schemaname = 'public' " if public_schema_only else ""
    sql = (
        "SELECT format('%I.%I', schemaname, matviewname) FROM pg_matviews "
        "WHERE schemaname NOT IN ('pg_catalog', 'information_schema') "
        f"{extra}"
        "ORDER BY schemaname, matviewname;"
    )
    result = run_kubectl(
        [
            "exec",
            "-n",
            namespace,
            pod,
            "-c",
            "database",
            "--",
            "psql",
            "-t",
            "-A",
            "-d",
            db,
            "-c",
            sql,
        ],
        kubeconfig=kubeconfig,
        check=False,
    )
    if result.returncode != 0:
        err = (result.stderr or result.stdout or "psql failed").strip()
        return [], err[:500]
    return [r.strip() for r in result.stdout.strip().split("\n") if r.strip()], ""


def _refresh_materialized_view_one(
    pod: str,
    namespace: str,
    db: str,
    kubeconfig: str | None,
    qualified_name: str,
    *,
    concurrent_first: bool,
) -> tuple[bool, str]:
    """
    Run REFRESH for one matview. Tries CONCURRENTLY first when ``concurrent_first`` is True, then plain REFRESH.
    Returns (success, detail line for logging).
    """
    if concurrent_first:
        sql_c = f"REFRESH MATERIALIZED VIEW CONCURRENTLY {qualified_name}"
        r = run_kubectl(
            [
                "exec",
                "-n",
                namespace,
                pod,
                "-c",
                "database",
                "--",
                "psql",
                "-d",
                db,
                "-v",
                "ON_ERROR_STOP=1",
                "-c",
                sql_c,
            ],
            kubeconfig=kubeconfig,
            check=False,
        )
        if r.returncode == 0:
            return True, "CONCURRENTLY"
        err = (r.stderr or r.stdout or "").strip()
        progress(f"    CONCURRENTLY failed for {qualified_name}; trying non-concurrent. ({err[:300]})")

    sql = f"REFRESH MATERIALIZED VIEW {qualified_name}"
    r2 = run_kubectl(
        [
            "exec",
            "-n",
            namespace,
            pod,
            "-c",
            "database",
            "--",
            "psql",
            "-d",
            db,
            "-v",
            "ON_ERROR_STOP=1",
            "-c",
            sql,
        ],
        kubeconfig=kubeconfig,
        check=False,
    )
    if r2.returncode == 0:
        return True, "non-concurrent"
    err = (r2.stderr or r2.stdout or "").strip()
    return False, err[:800] if err else "unknown error"


def cmd_refresh_matviews(
    indico_ns: str,
    kubeconfig: str | None,
    databases: list[str] | None,
    *,
    public_schema_only: bool = False,
    concurrent_first: bool = True,
    dry_run: bool = False,
) -> int:
    """
    Run ``REFRESH MATERIALIZED VIEW`` on postgres-core. Logical replication does not apply to matviews; run this
    after base tables have caught up (e.g. after ``verify-sync``). Tries ``CONCURRENTLY`` first when enabled
    (requires a unique index on the matview); falls back to a plain ``REFRESH`` on failure.
    """
    target_cluster = "postgres-core"
    progress(f"Locating postgres-core primary in {indico_ns}...")
    core_pod = get_primary_pod(target_cluster, indico_ns, kubeconfig)
    if not core_pod:
        print(f"Error: postgres-core primary pod not found in {indico_ns}", file=sys.stderr)
        return 1

    if databases:
        dbs = list(databases)
    else:
        dbs = get_databases_from_cluster(target_cluster, indico_ns, kubeconfig)
    if not dbs:
        print("No databases to process.", file=sys.stderr)
        return 1

    scope = "schema public only" if public_schema_only else "all non-system schemas"
    progress(
        f"{'Would refresh' if dry_run else 'Refreshing'} materialized views ({scope}) on "
        f"{len(dbs)} database(s)..."
    )

    any_fail = False
    total_mv = 0
    for db in dbs:
        qualified, list_err = _list_matview_qualified_names(
            core_pod, indico_ns, db, kubeconfig, public_schema_only=public_schema_only
        )
        if list_err:
            any_fail = True
            print(f"  {db}: could not list matviews: {list_err}", file=sys.stderr)
            continue
        if not qualified:
            progress(f"  {db}: no materialized views")
            continue
        progress(f"  {db}: {len(qualified)} materialized view(s)")
        for qn in qualified:
            total_mv += 1
            if dry_run:
                print(f"    [dry-run] REFRESH {qn}  (database {db})")
                continue
            ok, detail = _refresh_materialized_view_one(
                core_pod,
                indico_ns,
                db,
                kubeconfig,
                qn,
                concurrent_first=concurrent_first,
            )
            if ok:
                print(f"    OK {qn} ({detail})")
            else:
                any_fail = True
                print(f"    FAILED {qn}: {detail}", file=sys.stderr)

    if dry_run:
        progress(f"dry-run: {total_mv} materialized view(s) listed.")
        return 0
    if any_fail:
        print("One or more REFRESH commands failed.", file=sys.stderr)
        return 1
    progress(f"refresh-matviews complete ({total_mv} refreshed).")
    return 0


def cmd_verify_sync(
    indico_ns: str,
    kubeconfig: str | None,
    exact: bool = False,
    replication_only: bool = False,
) -> int:
    """Subscription/worker/LSN status on every postgres-core DB, plus optional source vs target row counts."""
    if replication_only:
        progress("Checking replication (subscription status on postgres-core only)...")
    else:
        progress("Verifying replication (subscription status + row count comparison)...")
    target_cluster = "postgres-core"
    sources = [
        c for c in get_postgres_clusters(kubeconfig)
        if c["name"] != target_cluster or c["namespace"] != indico_ns
    ]
    core_pod = get_primary_pod(target_cluster, indico_ns, kubeconfig)
    if not core_pod:
        print(f"Error: postgres-core primary pod not found in {indico_ns}", file=sys.stderr)
        return 1

    target_dbs_for_compare: list[str] = []
    for src in sources:
        src_name, src_ns = src["name"], src["namespace"]
        src_pod = get_primary_pod(src_name, src_ns, kubeconfig)
        if not src_pod:
            continue
        dbs = get_databases_from_cluster(src_name, src_ns, kubeconfig)
        for db in dbs:
            target_dbs_for_compare.append(f"{src_ns}_{db}")

    progress("Subscription / worker status on postgres-core (all non-template databases)...")
    rows_core, all_core_dbs, dbs_list_ok = _collect_postgres_core_subscription_status_rows(
        core_pod, indico_ns, kubeconfig
    )
    if not dbs_list_ok:
        print("Error: Could not list databases on postgres-core.", file=sys.stderr)
        return 1
    if not all_core_dbs:
        print("No non-template databases found on postgres-core (only 'postgres').")
        return 0

    dbs_with_subscription_rows = {r[0] for r in rows_core}
    merged: list[tuple[str, str, str, str, str, str, str]] = list(rows_core)
    for exp in sorted(set(target_dbs_for_compare)):
        if exp not in dbs_with_subscription_rows:
            merged.append((exp, "(no subscription)", "n/a", "", "", "", ""))
    merged.sort(key=lambda r: (r[0], r[1]))

    if not rows_core and not merged:
        print("No subscriptions found in any of the following databases:")
        print("  " + ", ".join(all_core_dbs))
        print("Run 'bootstrap' first to copy schemas, then 'setup-replication' to create subscriptions.")
        return 0

    if merged:
        col_db, col_sub, col_worker, col_en, col_lsn, col_send, col_recv = 22, 48, 10, 7, 18, 26, 26
        print(
            f"\n{'Target DB':<{col_db}} | {'Subscription':<{col_sub}} | {'Worker':<{col_worker}} | "
            f"{'Enabled':<{col_en}} | {'Received LSN':<{col_lsn}} | {'Last Send':<{col_send}} | Last Receipt"
        )
        print("-" * (col_db + col_sub + col_worker + col_en + col_lsn + col_send + col_recv + 18))
        for db, subname, worker, enabled, lsn, send_time, recv_time in merged:
            print(
                f"{db:<{col_db}} | {subname:<{col_sub}} | {worker:<{col_worker}} | {enabled:<{col_en}} | "
                f"{lsn:<{col_lsn}} | {send_time:<{col_send}} | {recv_time}"
            )

    no_worker_count = sum(1 for r in merged if r[2] == "no worker")
    any_no_sub = any(r[1] == "(no subscription)" for r in merged)
    any_no_worker = no_worker_count > 0 or any_no_sub
    if any_no_worker:
        print(
            "\n  Note: 'no worker' / missing subscription: apply worker not connected or subscription missing; "
            "replication may be stalled or not configured for that database.",
            file=sys.stderr,
        )
        sub_rows = [r for r in merged if r[1] != "(no subscription)"]
        sub_total = len(sub_rows)
        no_worker_n = sum(1 for r in sub_rows if r[2] == "no worker")
        active_n = sum(1 for r in sub_rows if r[2] == "active")
        max_lr, max_workers = _fetch_logical_replication_gucs(core_pod, indico_ns, kubeconfig)
        _emit_replication_worker_guidance(
            subscription_count=sub_total,
            max_lr=max_lr,
            max_workers=max_workers,
            no_worker_count=no_worker_n,
            active_count=active_n,
        )
    print()

    if replication_only:
        progress("Skipping row counts (--replication-only).")
        return 0

    count_type = "exact (COUNT(*))" if exact else "estimate (pg_class + n_live_tup)"
    progress(f"Using {count_type} for row counts.")

    rows: list[tuple[str, str, str, str, str]] = []  # target_db, table, src_count, tgt_count, status
    any_mismatch = False
    heartbeat_changelog_drifts_ignored = 0
    for src in sources:
        src_name, src_ns = src["name"], src["namespace"]
        src_pod = get_primary_pod(src_name, src_ns, kubeconfig)
        if not src_pod:
            continue
        dbs = get_databases_from_cluster(src_name, src_ns, kubeconfig)
        if not dbs:
            continue
        for db in dbs:
            target_db = f"{src_ns}_{db}"
            progress(f"  Comparing {src_ns}/{src_name}/{db} -> {target_db}")
            src_counts = _get_tables_and_row_counts(src_pod, src_ns, db, kubeconfig, exact)
            tgt_counts = _get_tables_and_row_counts(core_pod, indico_ns, target_db, kubeconfig, exact)
            all_tables = sorted(set(src_counts) | set(tgt_counts))
            for table in all_tables:
                src_c = src_counts.get(table, -1)
                tgt_c = tgt_counts.get(table, -1)
                if src_c == -1:
                    status = "missing on source"
                elif tgt_c == -1:
                    status = "MISMATCH (missing on target)"
                    any_mismatch = True
                elif src_c != tgt_c:
                    if _verify_sync_is_heartbeat_changelog_table(table):
                        status = "OK (heartbeat_changelog drift ignored)"
                        heartbeat_changelog_drifts_ignored += 1
                    else:
                        status = "MISMATCH"
                        any_mismatch = True
                else:
                    status = "OK"
                rows.append((target_db, table, str(src_c) if src_c >= 0 else "n/a", str(tgt_c) if tgt_c >= 0 else "n/a", status))

    if not rows:
        print("No relations to compare (no source clusters/databases or no user objects in public schema).")
        return 0

    col_db, col_table, col_src, col_tgt, col_status = 22, 32, 14, 14, 24
    print(f"{'Target DB':<{col_db}} | {'Table':<{col_table}} | {'Source Rows':<{col_src}} | {'Target Rows':<{col_tgt}} | Status")
    print("-" * (col_db + col_table + col_src + col_tgt + col_status + 12))
    for target_db, table, src_count, tgt_count, status in rows:
        print(f"{target_db:<{col_db}} | {table:<{col_table}} | {src_count:>{col_src}} | {tgt_count:>{col_tgt}} | {status}")

    if any_mismatch:
        print("\nOne or more tables are out of sync.", file=sys.stderr)
        if not exact:
            mismatch_rows = [r for r in rows if r[4] == "MISMATCH"]
            src_zero_tgt_positive = 0
            for _db, _tbl, sc, tc, _st in mismatch_rows:
                if sc != "0":
                    continue
                try:
                    if int(tc) > 0:
                        src_zero_tgt_positive += 1
                except ValueError:
                    pass
            if src_zero_tgt_positive >= 3:
                print(
                    "  Hint: many mismatches show Source Rows = 0 while Target Rows > 0; estimates use "
                    "n_live_tup (often stale for lightly analyzed relations). Re-run with --exact or run ANALYZE.",
                    file=sys.stderr,
                )
        any_missing_tgt = any(r[4] == "MISMATCH (missing on target)" for r in rows)
        if any_missing_tgt:
            print(
                "  Hint: objects missing on the subscriber were not created by pg_restore on postgres-core "
                "(bootstrap). Compare SELECT extname, extversion FROM pg_extension on publisher vs target DB; "
                "install matching extensions (e.g. TimescaleDB), then re-run bootstrap for that database.",
                file=sys.stderr,
            )
        any_count_only = any(r[4] == "MISMATCH" for r in rows)
        if any_count_only and not any_missing_tgt:
            print(
                "  Hint: logical replication does not apply to materialized views; REFRESH them on the subscriber "
                "if needed. Single-row gaps on changelog tables are often concurrent inserts during verify.",
                file=sys.stderr,
            )
        if any_no_worker:
            max_lr, max_workers = _fetch_logical_replication_gucs(core_pod, indico_ns, kubeconfig)
            sub_rows_footer = [r for r in merged if r[1] != "(no subscription)"]
            sub_total = len(sub_rows_footer)
            if max_lr is not None and sub_total > max_lr:
                print(
                    "Many mismatches are expected while subscriptions exceed max_logical_replication_workers: "
                    "raise that GUC on postgres-core (see messages above); re-running setup-replication alone will not help.",
                    file=sys.stderr,
                )
            else:
                print(
                    "Some databases show 'no worker' above; fix replication (check pod logs, subscription status) "
                    "then run verify-sync again.",
                    file=sys.stderr,
                )
        else:
            print("Replication workers are active; wait for replication to catch up and run verify-sync again.", file=sys.stderr)
        return 1
    if heartbeat_changelog_drifts_ignored > 0:
        progress(
            f"{heartbeat_changelog_drifts_ignored} *_heartbeat_changelog row difference(s) treated as OK "
            "(non-fatal high-churn tables)."
        )
    progress("All compared tables are in sync.")
    return 0


def get_minio_backup_cronjobs(kubeconfig: str | None) -> list[dict]:
    """Find all CronJobs named 'minio-backup'. Returns list of {namespace, name}."""
    result = run_kubectl(
        ["get", "cronjobs", "--all-namespaces", "-o", "json"],
        kubeconfig=kubeconfig,
    )
    data = json.loads(result.stdout)
    out = []
    for item in data.get("items", []):
        name = item.get("metadata", {}).get("name", "")
        if name != "minio-backup":
            continue
        namespace = item.get("metadata", {}).get("namespace", "")
        out.append({"namespace": namespace, "name": name})
    return out


def cmd_minio_to_s3(
    miniobkp_bucket: str | None,
    data_bucket: str | None,
    tf_dir: Path,
    kubeconfig: str | None,
    job_timeout_seconds: int,
    dry_run: bool,
    delete: bool,
    skip_backup_job: bool,
    aws_profile: str = "Indico-Dev",
) -> int:
    """
    Migrate MinIO data to S3 by:
    1. Locating CronJob 'minio-backup' (per namespace)
    2. Creating a Job from each CronJob and waiting for completion (runs backup to miniobkp bucket)
    3. Syncing s3://miniobkp_bucket/{namespace}/insights-bucket/blob/ -> s3://data_bucket/blob/{namespace}/

    Dry-run: may query Terraform and list CronJobs; does not create any Job or run any copy/sync.
    """
    # Bucket names from Terraform state (outputs data_s3_bucket_name, miniobkp_s3_bucket_name)
    # Dry-run may query Terraform; no Job or sync is executed when dry_run is True
    tf_dir = Path(tf_dir).resolve()
    if not data_bucket or not miniobkp_bucket:
        progress("Resolving bucket names from Terraform...")
        progress("Initializing Terraform...")
        init_result = run_cmd(
            ["terraform", f"-chdir={tf_dir}", "init", "-input=false"],
            capture_output=True,
            check=False,
        )
        if init_result.returncode != 0 and init_result.stderr:
            print(f"Terraform init (in {tf_dir}): {init_result.stderr.strip()}", file=sys.stderr)
        progress("Reading Terraform outputs...")
        result = run_cmd(
            ["terraform", f"-chdir={tf_dir}", "output", "-json"],
            capture_output=True,
            check=False,
        )
        if result.returncode != 0 and result.stderr:
            print(f"Terraform output: {result.stderr.strip()}", file=sys.stderr)
        if result.returncode == 0:
            try:
                outputs = json.loads(result.stdout)
                def get_out(name: str) -> str:
                    o = outputs.get(name, {})
                    if not isinstance(o, dict):
                        return ""
                    v = o.get("value")
                    return str(v) if v is not None else ""
                if not data_bucket:
                    data_bucket = get_out("data_s3_bucket_name")
                if not miniobkp_bucket:
                    miniobkp_bucket = get_out("miniobkp_s3_bucket_name")
            except json.JSONDecodeError:
                pass
        if not data_bucket or not miniobkp_bucket:
            if dry_run:
                # Dry-run never fails: use placeholders so user can see intended commands
                data_bucket = data_bucket or "<data_s3_bucket_name>"
                miniobkp_bucket = miniobkp_bucket or "<miniobkp_s3_bucket_name>"
                print("Note: Terraform outputs unavailable; showing commands with placeholders.", file=sys.stderr)
            else:
                print(
                    "Error: Could not read Terraform outputs (data_s3_bucket_name, miniobkp_s3_bucket_name). "
                    "Provide --data-bucket and --miniobkp-bucket, or run from a Terraform workspace with state.",
                    file=sys.stderr,
                )
                return 1

    progress("Locating minio-backup CronJobs...")
    cronjobs = get_minio_backup_cronjobs(kubeconfig)
    if not cronjobs:
        print("No CronJob 'minio-backup' found in any namespace.")
        return 0
    progress(f"Found {len(cronjobs)} minio-backup CronJob(s).")
    for idx, cj in enumerate(cronjobs, 1):
        ns = cj["namespace"]
        src = f"s3://{miniobkp_bucket}/{ns}/insights-bucket/blob/"
        dest = f"s3://{data_bucket}/blob/{ns}/"
        progress(f"Namespace {ns}", step=idx, total=len(cronjobs))
        print(f"  Sync: {src} -> {dest}")

        if dry_run:
            # Dry-run: no Job creation and no physical copy/sync
            print(f"  [dry-run] Would create Job from CronJob minio-backup in {ns} and wait for completion")
            sync_cmd = ["aws", "--profile", aws_profile, "s3", "sync", src, dest]
            if delete:
                sync_cmd.append("--delete")
            print(f"  [dry-run] Would run: {' '.join(sync_cmd)}")
            continue

        # 1 & 2: Create Job from CronJob and wait for completion (only when not dry-run)
        job_name = f"minio-backup-migration-{int(time.time())}"
        if not skip_backup_job:
            progress(f"  Creating backup Job in {ns}...")
            run_kubectl(
                ["create", "job", "-n", ns, job_name, "--from=cronjob/minio-backup"],
                kubeconfig=kubeconfig,
            )
            progress(f"  Waiting for backup Job (timeout {job_timeout_seconds}s)...")
            run_kubectl(
                ["wait", "--for=condition=complete", f"job/{job_name}", "-n", ns, f"--timeout={job_timeout_seconds}s"],
                kubeconfig=kubeconfig,
                check=False,
            )
            progress(f"  Cleaning up Job in {ns}...")
            run_kubectl(["delete", "job", "-n", ns, job_name], kubeconfig=kubeconfig, check=False)

        # 3: Sync miniobkp -> data bucket (only when not dry-run)
        sync_cmd = ["aws", "--profile", aws_profile, "s3", "sync", src, dest, "--only-show-errors"]
        if delete:
            sync_cmd.append("--delete")
        proc = subprocess.Popen(
            sync_cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        spinner = "|/-\\"
        idx = 0
        while proc.poll() is None:
            sys.stdout.write(f"\r  Syncing S3 ({ns})... {spinner[idx % len(spinner)]} ")
            sys.stdout.flush()
            idx += 1
            time.sleep(0.12)
        sys.stdout.write(f"\r  Syncing S3 ({ns})... done.\n")
        sys.stdout.flush()
        if proc.returncode != 0 and proc.stderr:
            out = proc.stderr.read()
            if out:
                print(out, file=sys.stderr)
    progress("minio-to-s3 complete.")
    return 0


def cmd_migrate_all(
    tf_dir: Path,
    output_file: Path,
    version: str | None,
    helm_repo: str | None,
    kubeconfig: str | None,
    indico_namespace: str,
    replication_password: str,
    miniobkp_bucket: str | None,
    data_bucket: str | None,
    job_timeout: int,
    skip_backup_job: bool,
    minio_delete: bool,
    dry_run: bool,
    aws_profile: str = "Indico-Dev",
    *,
    az_count: int = 2,
    postgres_volume_size: str = "100Gi",
    storage_class: str = "encrypted-gp3",
    image_registry: str = "harbor.devops.indico.io",
    indico_storage_class_name: str = "indico-sc",
    include_efs: bool = False,
    enable_service_mesh: bool = False,
    wait_initial_copy: bool = False,
    initial_copy_timeout_sec: int = 86400,
    fast: bool = False,
    bootstrap_skip_patroni_patch: bool = False,
    bootstrap_patroni_patch_pod_timeout_sec: int = 600,
    bootstrap_patroni_patch_wait_sec: int = 90,
    bootstrap_skip_schema_parity: bool = False,
    bootstrap_skip_schema_parity_for: frozenset[str] | None = None,
) -> int:
    """
    Run all migration steps in order:
    1. calculate-values  2. install  3. bootstrap  4. setup-replication  5. minio-to-s3  6. verify-sync --replication-only
    With --dry-run: no destructive changes; install uses helm --dry-run, bootstrap/setup-replication are skipped (printed), minio-to-s3 uses its dry-run.
    """
    steps = 6
    tf_dir = Path(tf_dir).resolve()
    output_path = Path(output_file).resolve()
    kc = str(kubeconfig) if kubeconfig else None

    try:
        progress("Step 1/6: calculate-values", step=1, total=steps)
        rc = cmd_calculate_values(
            tf_dir,
            output_path,
            dry_run=dry_run,
            az_count=az_count,
            postgres_volume_size=postgres_volume_size,
            storage_class=storage_class,
            image_registry=image_registry,
            indico_storage_class_name=indico_storage_class_name,
            include_efs=include_efs,
            enable_service_mesh=enable_service_mesh,
        )
        if rc != 0:
            return rc

        effective_version = version
        if not effective_version:
            effective_version = helm_indico_core_chart_version(indico_namespace, kc)
            if effective_version:
                progress(f"Using indico-core chart version from existing Helm release: {effective_version}")

        if not effective_version:
            if dry_run:
                progress(
                    "Step 2/6: Would install indico-core (pass --version for template, or install release in cluster to auto-detect)",
                    step=2,
                    total=steps,
                )
            else:
                print(
                    "Error: migrate-all install step needs the indico-core Helm chart version.\n"
                    "  Pass:  --version <VER>   (match the chart version your Terraform workspace uses for indico-core)\n"
                    "  Or:    ensure release 'indico-core' exists in namespace "
                    f"{indico_namespace!r} so the version can be read from helm list.",
                    file=sys.stderr,
                )
                return 1
        else:
            progress("Step 2/6: install", step=2, total=steps)
            rc = cmd_install(effective_version, output_path, tf_dir, kc, helm_repo, dry_run=dry_run)
            if rc != 0:
                return rc

        progress("Step 3/6: bootstrap", step=3, total=steps)
        if dry_run:
            progress("  (dry-run: skipping bootstrap; would copy schemas from source clusters)")
        else:
            rc = cmd_bootstrap(
                indico_namespace,
                indico_namespace,
                kc,
                skip_patroni_patch=bootstrap_skip_patroni_patch,
                patroni_patch_pod_timeout_sec=bootstrap_patroni_patch_pod_timeout_sec,
                patroni_patch_wait_sec=bootstrap_patroni_patch_wait_sec,
                skip_schema_parity=bootstrap_skip_schema_parity,
                skip_schema_parity_for=bootstrap_skip_schema_parity_for,
            )
            if rc != 0:
                return rc

        progress("Step 4/6: setup-replication", step=4, total=steps)
        if dry_run:
            progress("  (dry-run: skipping setup-replication; would create publications/subscriptions)")
        else:
            rc = cmd_setup_replication(
                indico_namespace,
                kc,
                replication_password,
                wait_initial_copy=wait_initial_copy,
                initial_copy_timeout_sec=initial_copy_timeout_sec,
                fast=fast,
            )
            if rc != 0:
                return rc

        progress("Step 5/6: minio-to-s3", step=5, total=steps)
        rc = cmd_minio_to_s3(miniobkp_bucket, data_bucket, tf_dir, kc, job_timeout, dry_run, minio_delete, skip_backup_job, aws_profile)
        if rc != 0:
            return rc

        progress("Step 6/6: verify-sync --replication-only", step=6, total=steps)
        if dry_run:
            progress("  (dry-run: skipping verify-sync; postgres-core not installed)")
        else:
            rc = cmd_verify_sync(indico_namespace, kc, exact=False, replication_only=True)
            if rc != 0:
                return rc

        progress("migrate-all complete." if not dry_run else "migrate-all dry-run complete.")
        return 0
    finally:
        # Clean up temporary values file created in step 1
        if output_path.exists():
            try:
                output_path.unlink()
                progress("Removed temporary values file.")
            except OSError as e:
                print(f"Warning: Could not remove temporary file {output_path}: {e}", file=sys.stderr)


def main() -> int:
    parser = argparse.ArgumentParser(description="PostgreSQL migration assistant for postgres-core")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # calculate-values (CLI params match Terraform var defaults; no new Terraform outputs required)
    p_calc = subparsers.add_parser(
        "calculate-values",
        help="Compute indico-core values from Terraform (cluster/env) + CLI. Run before Terraform apply.",
    )
    p_calc.add_argument("--tf-dir", type=Path, default=Path.cwd(), help="Terraform directory")
    p_calc.add_argument(
        "--output", "-o", type=Path,
        help="Output file for indico-core values YAML (use with install -f)",
    )
    p_calc.add_argument("--az-count", type=int, default=2, metavar="N", help="Instance replicas 1-3 (default: 2)")
    p_calc.add_argument("--postgres-volume-size", default="100Gi", help="Postgres PVC size (default: 100Gi)")
    p_calc.add_argument("--storage-class", default="encrypted-gp3", help="Storage class for postgres volumes (default: encrypted-gp3)")
    p_calc.add_argument("--image-registry", default="harbor.devops.indico.io", help="Image registry for rabbitmq/celery-backend (default: harbor.devops.indico.io)")
    p_calc.add_argument("--indico-storage-class-name", default="indico-sc", help="Storage class for rabbitmq persistence (default: indico-sc)")
    p_calc.add_argument("--include-efs", action="store_true", help="Use EFS-backed storage for rabbitmq (default: false)")
    p_calc.add_argument("--enable-service-mesh", action="store_true", help="Export services for service mesh (default: false)")

    # install
    p_install = subparsers.add_parser("install", help="Install indico-core helm chart")
    p_install.add_argument("--version", "-v", required=True, help="Helm chart version")
    p_install.add_argument(
        "--values-file", "-f", type=Path,
        help="Values YAML for indico-core (crunchy-postgres/postgres-core config). Run calculate-values to generate.",
    )
    p_install.add_argument("--tf-dir", type=Path, default=Path.cwd(), help="Terraform directory for values")
    p_install.add_argument("--kubeconfig", type=Path, help="Kubeconfig path")
    p_install.add_argument(
        "--helm-repo",
        default="oci://harbor.devops.indico.io/indico-charts",
        help="Helm repository URL for indico charts (default: ipa_repo value)",
    )

    # bootstrap
    p_bootstrap = subparsers.add_parser(
        "bootstrap",
        help="Bootstrap postgres-core: copy schemas from sources (no logical replication; use setup-replication)",
    )
    p_bootstrap.add_argument("--indico-namespace", default="indico", help="Namespace containing postgres-core")
    p_bootstrap.add_argument("--postgres-core-namespace", default="indico", help="Namespace of postgres-core")
    p_bootstrap.add_argument("--kubeconfig", type=Path, help="Kubeconfig path")
    p_bootstrap.add_argument(
        "--skip-patroni-patch",
        action="store_true",
        help="Do not patch Patroni parameters or wait; only copy schemas (advanced)",
    )
    p_bootstrap.add_argument(
        "--patroni-patch-pod-timeout-sec",
        type=int,
        default=600,
        metavar="SEC",
        help="Max seconds to wait per cluster for primary pod Ready after Patroni patch (default: 600)",
    )
    p_bootstrap.add_argument(
        "--patroni-patch-wait-sec",
        type=int,
        default=90,
        metavar="SEC",
        help="Extra sleep after pods are Ready for PostgreSQL reload/restart (default: 90)",
    )
    p_bootstrap.add_argument(
        "--skip-schema-parity",
        action="store_true",
        help="Skip post-restore schema parity for every database (prefer --skip-schema-parity-for for one DB)",
    )
    p_bootstrap.add_argument(
        "--skip-schema-parity-for",
        action="append",
        default=[],
        metavar="DB",
        help=(
            "Skip parity only for this source or postgres-core target DB name; repeat or use commas, "
            "e.g. --skip-schema-parity-for meteor or --skip-schema-parity-for default_meteor"
        ),
    )

    # setup-replication
    p_setup = subparsers.add_parser("setup-replication", help="Set up logical replication")
    p_setup.add_argument("--indico-namespace", default="indico", help="Namespace containing postgres-core")
    p_setup.add_argument("--kubeconfig", type=Path, help="Kubeconfig path")
    p_setup.add_argument("--replication-password", default="changeme", help="Password for rep_migration user")
    p_setup.add_argument(
        "--wait-initial-copy",
        action="store_true",
        help=(
            "After each CREATE SUBSCRIPTION, wait on postgres-core until initial table copy finishes before "
            "creating the next (slower; uses fewer publisher pg_*_sync_* slots). Default is parallel creates—"
            "raise max_replication_slots on publishers instead"
        ),
    )
    p_setup.add_argument(
        "--initial-copy-timeout-sec",
        type=int,
        default=86400,
        metavar="SEC",
        help="With --wait-initial-copy: max seconds to wait per DB before stopping further subs on this publisher",
    )
    p_setup.add_argument(
        "--fast",
        action="store_true",
        help=(
            "Skip per-DB route precheck (postgres-core → publisher) and skip post-create 3s sleep + worker/diagnostic "
            "queries (fewer kubectl/psql round-trips). Use after the path is known good; run verify-sync after."
        ),
    )

    # cleanup-publisher-slots
    p_clean_pub = subparsers.add_parser(
        "cleanup-publisher-slots",
        help="Drop migration logical slots on a publisher (sub_* + pg_*_sync_*); never drops postgres-data app slots",
    )
    p_clean_pub.add_argument(
        "--publisher-namespace",
        help="Kubernetes namespace of the publisher PostgresCluster (e.g. insights)",
    )
    p_clean_pub.add_argument(
        "--publisher-cluster",
        help="Publisher cluster resource name (e.g. postgres-insights)",
    )
    p_clean_pub.add_argument(
        "--all-migration-sources",
        action="store_true",
        help="Clean every publisher used by setup-replication (all PostgresClusters except postgres-core in --indico-namespace)",
    )
    p_clean_pub.add_argument(
        "--indico-namespace",
        default="indico",
        help="Namespace where postgres-core lives; used with --all-migration-sources (default: indico)",
    )
    p_clean_pub.add_argument("--kubeconfig", type=Path, help="Kubeconfig path")
    p_clean_pub.add_argument(
        "--dry-run",
        action="store_true",
        help="List slots that would be dropped; do not drop",
    )

    # post-upgrade-cleanup
    p_post = subparsers.add_parser(
        "post-upgrade-cleanup",
        help=(
            "After cutover, remove subscriptions from postgres-core, remove migration slots on "
            "publishers, and patch publisher PostgresClusters to spec.shutdown=true"
        ),
    )
    p_post.add_argument(
        "--indico-namespace",
        default="indico",
        help="Namespace containing postgres-core (default: indico)",
    )
    p_post.add_argument("--kubeconfig", type=Path, help="Kubeconfig path")
    p_post.add_argument(
        "--dry-run",
        action="store_true",
        help="Show intended subscription/slot/shutdown actions without making changes",
    )

    # verify-sync
    p_verify = subparsers.add_parser(
        "verify-sync",
        help="Subscription/worker/LSN status on postgres-core plus optional source vs target row counts",
    )
    p_verify.add_argument("--indico-namespace", default="indico", help="Namespace containing postgres-core")
    p_verify.add_argument("--kubeconfig", type=Path, help="Kubeconfig path")
    p_verify.add_argument(
        "--exact",
        action="store_true",
        help="Use exact COUNT(*) per table (slower); default is estimate from pg_stat_user_tables.n_live_tup",
    )
    p_verify.add_argument(
        "--replication-only",
        action="store_true",
        help="Only print subscription apply worker status (all postgres-core DBs); skip row count comparison",
    )

    p_diag = subparsers.add_parser(
        "migration-diagnose",
        help="Explain missing public relations: extension diff + relkind/owner/extension + view/matview defs (publisher)",
    )
    p_diag.add_argument(
        "--publisher-namespace",
        required=True,
        help="Kubernetes namespace of the publisher PostgresCluster (e.g. default)",
    )
    p_diag.add_argument(
        "--publisher-cluster",
        required=True,
        help="Publisher PostgresCluster name (e.g. postgres-data)",
    )
    p_diag.add_argument(
        "--publisher-db",
        required=True,
        help="Database name on the publisher (e.g. meteor)",
    )
    p_diag.add_argument(
        "--target-namespace",
        default="indico",
        help="Namespace where postgres-core runs (default: indico)",
    )
    p_diag.add_argument(
        "--target-db",
        required=True,
        help="Prefixed database on postgres-core (e.g. default_meteor)",
    )
    p_diag.add_argument("--kubeconfig", type=Path, help="Kubeconfig path")

    p_refresh_mv = subparsers.add_parser(
        "refresh-matviews",
        help="REFRESH MATERIALIZED VIEW on postgres-core subscriber DBs (run after replication has caught up)",
    )
    p_refresh_mv.add_argument(
        "--indico-namespace",
        default="indico",
        help="Namespace containing postgres-core (default: indico)",
    )
    p_refresh_mv.add_argument("--kubeconfig", type=Path, help="Kubeconfig path")
    p_refresh_mv.add_argument(
        "--database",
        action="append",
        default=[],
        metavar="DB",
        help=(
            "Postgres database on postgres-core to process (repeatable). "
            "Default: all non-template databases except postgres"
        ),
    )
    p_refresh_mv.add_argument(
        "--public-only",
        action="store_true",
        help="Only refresh matviews in schema public (default: all non-system schemas)",
    )
    p_refresh_mv.add_argument(
        "--no-concurrent-first",
        action="store_true",
        help="Skip CONCURRENTLY; use plain REFRESH only (stronger locks)",
    )
    p_refresh_mv.add_argument(
        "--dry-run",
        action="store_true",
        help="List matviews that would be refreshed; do not run REFRESH",
    )

    # minio-to-s3
    p_minio = subparsers.add_parser(
        "minio-to-s3",
        help="Migrate MinIO to S3: run minio-backup CronJob as Job, then sync miniobkp bucket -> data bucket",
    )
    p_minio.add_argument(
        "--miniobkp-bucket",
        help="MinIO backup S3 bucket (default: from Terraform output miniobkp_s3_bucket_name)",
    )
    p_minio.add_argument(
        "--data-bucket",
        help="Data S3 bucket (default: from Terraform output data_s3_bucket_name)",
    )
    p_minio.add_argument(
        "--tf-dir",
        type=Path,
        default=DEFAULT_TF_DIR,
        help="Terraform dir for bucket outputs (default: repo root)",
    )
    p_minio.add_argument("--kubeconfig", type=Path, help="Kubeconfig path")
    p_minio.add_argument(
        "--job-timeout",
        type=int,
        default=3600,
        help="Timeout in seconds for backup Job (default: 3600)",
    )
    p_minio.add_argument("--dry-run", action="store_true", help="Print commands only, no Job create or sync")
    p_minio.add_argument(
        "--skip-backup-job",
        action="store_true",
        help="Skip creating/waiting for backup Job; only run S3 sync (miniobkp -> data)",
    )
    p_minio.add_argument(
        "--delete",
        action="store_true",
        help="Delete objects in data bucket not in source (aws s3 sync --delete)",
    )
    p_minio.add_argument(
        "--profile",
        default="Indico-Dev",
        help="AWS profile for s3 sync (default: Indico-Dev)",
    )

    # migrate-all: run all steps in order (1. calculate-values 2. install 3. bootstrap 4. setup-replication 5. minio-to-s3 6. verify-sync --replication-only)
    p_all = subparsers.add_parser(
        "migrate-all",
        help="Run all migration steps in order; supports --dry-run",
    )
    p_all.add_argument("--dry-run", action="store_true", help="No destructive changes; show what would be done")
    p_all.add_argument("--tf-dir", type=Path, default=DEFAULT_TF_DIR, help="Terraform directory (default: repo root)")
    p_all.add_argument("--output", "-o", type=Path, default=Path("indico-core-migration-values.yaml"), help="Output file for step 1 (used as values for step 2); resolved from cwd unless absolute")
    p_all.add_argument(
        "--version",
        "-v",
        help="Helm chart version for install; if omitted, uses helm list when release indico-core already exists",
    )
    p_all.add_argument(
        "--helm-repo",
        default="oci://harbor.devops.indico.io/indico-charts",
        help="Helm repository URL for indico charts (default: ipa_repo value)",
    )
    p_all.add_argument("--kubeconfig", type=Path, help="Kubeconfig path")
    p_all.add_argument("--indico-namespace", default="indico", help="Namespace for postgres-core and replication")
    p_all.add_argument("--replication-password", default="changeme", help="Password for rep_migration user")
    p_all.add_argument("--miniobkp-bucket", help="MinIO backup S3 bucket (default: from Terraform)")
    p_all.add_argument("--data-bucket", help="Data S3 bucket (default: from Terraform)")
    p_all.add_argument("--job-timeout", type=int, default=3600, help="Timeout for minio backup Job (seconds)")
    p_all.add_argument("--skip-backup-job", action="store_true", help="In minio-to-s3, skip backup Job; only run S3 sync")
    p_all.add_argument("--delete", action="store_true", dest="minio_delete", help="In minio-to-s3, use aws s3 sync --delete")
    p_all.add_argument("--profile", default="Indico-Dev", help="AWS profile for minio-to-s3 s3 sync (default: Indico-Dev)")
    p_all.add_argument("--az-count", type=int, default=2, metavar="N", help="Instance replicas 1-3 for calculate-values (default: 2)")
    p_all.add_argument("--postgres-volume-size", default="100Gi", help="Postgres PVC size for calculate-values (default: 100Gi)")
    p_all.add_argument("--storage-class", default="encrypted-gp3", help="Storage class for calculate-values (default: encrypted-gp3)")
    p_all.add_argument("--image-registry", default="harbor.devops.indico.io", help="Image registry for calculate-values (default: harbor.devops.indico.io)")
    p_all.add_argument("--indico-storage-class-name", default="indico-sc", help="Storage class for rabbitmq for calculate-values (default: indico-sc)")
    p_all.add_argument("--include-efs", action="store_true", help="Use EFS for rabbitmq in calculate-values (default: false)")
    p_all.add_argument("--enable-service-mesh", action="store_true", help="Enable service mesh export in calculate-values (default: false)")
    p_all.add_argument(
        "--wait-initial-copy",
        action="store_true",
        help="Pass-through to setup-replication: wait between subscriptions (slower, fewer publisher slots)",
    )
    p_all.add_argument(
        "--initial-copy-timeout-sec",
        type=int,
        default=86400,
        metavar="SEC",
        help="Pass-through to setup-replication: used only with --wait-initial-copy (default: 86400)",
    )
    p_all.add_argument(
        "--fast",
        action="store_true",
        help="Pass-through to setup-replication: skip route precheck and post-create diagnostics",
    )
    p_all.add_argument(
        "--bootstrap-skip-patroni-patch",
        action="store_true",
        help="Pass-through to bootstrap: skip Patroni GUC patch and waits",
    )
    p_all.add_argument(
        "--bootstrap-patroni-patch-pod-timeout-sec",
        type=int,
        default=600,
        metavar="SEC",
        help="Pass-through to bootstrap: max seconds per cluster for primary Ready after Patroni patch (default: 600)",
    )
    p_all.add_argument(
        "--bootstrap-patroni-patch-wait-sec",
        type=int,
        default=90,
        metavar="SEC",
        help="Pass-through to bootstrap: extra sleep after pods Ready (default: 90)",
    )
    p_all.add_argument(
        "--bootstrap-skip-schema-parity",
        action="store_true",
        help="Pass-through to bootstrap: skip post-restore public schema parity check for all DBs",
    )
    p_all.add_argument(
        "--bootstrap-skip-schema-parity-for",
        action="append",
        default=[],
        metavar="DB",
        help="Pass-through to bootstrap: same as bootstrap --skip-schema-parity-for (repeatable)",
    )

    args = parser.parse_args()

    if args.command == "calculate-values":
        calc_args = args
        if getattr(calc_args, "az_count", 2) < 1 or getattr(calc_args, "az_count", 2) > 3:
            print("Error: --az-count must be between 1 and 3.", file=sys.stderr)
            return 1
        return cmd_calculate_values(
            calc_args.tf_dir,
            calc_args.output,
            az_count=getattr(calc_args, "az_count", 2),
            postgres_volume_size=getattr(calc_args, "postgres_volume_size", "100Gi"),
            storage_class=getattr(calc_args, "storage_class", "encrypted-gp3"),
            image_registry=getattr(calc_args, "image_registry", "harbor.devops.indico.io"),
            indico_storage_class_name=getattr(calc_args, "indico_storage_class_name", "indico-sc"),
            include_efs=getattr(calc_args, "include_efs", False),
            enable_service_mesh=getattr(calc_args, "enable_service_mesh", False),
        )
    if args.command == "install":
        return cmd_install(
            args.version,
            getattr(args, "values_file", None),
            args.tf_dir,
            str(args.kubeconfig) if args.kubeconfig else None,
            getattr(args, "helm_repo", None),
            dry_run=getattr(args, "dry_run", False),
        )
    if args.command == "bootstrap":
        return cmd_bootstrap(
            args.indico_namespace,
            args.postgres_core_namespace,
            str(args.kubeconfig) if args.kubeconfig else None,
            skip_patroni_patch=getattr(args, "skip_patroni_patch", False),
            patroni_patch_pod_timeout_sec=getattr(args, "patroni_patch_pod_timeout_sec", 600),
            patroni_patch_wait_sec=getattr(args, "patroni_patch_wait_sec", 90),
            skip_schema_parity=getattr(args, "skip_schema_parity", False),
            skip_schema_parity_for=_skip_schema_parity_for_names(
                getattr(args, "skip_schema_parity_for", None) or []
            ),
        )
    if args.command == "setup-replication":
        return cmd_setup_replication(
            args.indico_namespace,
            str(args.kubeconfig) if args.kubeconfig else None,
            args.replication_password,
            wait_initial_copy=getattr(args, "wait_initial_copy", False),
            initial_copy_timeout_sec=getattr(args, "initial_copy_timeout_sec", 86400),
            fast=getattr(args, "fast", False),
        )
    if args.command == "cleanup-publisher-slots":
        return cmd_cleanup_publisher_migration_slots(
            str(args.kubeconfig) if args.kubeconfig else None,
            args.dry_run,
            publisher_namespace=getattr(args, "publisher_namespace", None),
            publisher_cluster=getattr(args, "publisher_cluster", None),
            indico_namespace=getattr(args, "indico_namespace", "indico"),
            all_migration_sources=getattr(args, "all_migration_sources", False),
        )
    if args.command == "post-upgrade-cleanup":
        return cmd_post_upgrade_cleanup(
            args.indico_namespace,
            str(args.kubeconfig) if args.kubeconfig else None,
            dry_run=getattr(args, "dry_run", False),
        )
    if args.command == "verify-sync":
        return cmd_verify_sync(
            args.indico_namespace,
            str(args.kubeconfig) if args.kubeconfig else None,
            exact=getattr(args, "exact", False),
            replication_only=getattr(args, "replication_only", False),
        )
    if args.command == "migration-diagnose":
        return cmd_migration_diagnose(
            str(args.kubeconfig) if args.kubeconfig else None,
            args.publisher_namespace,
            args.publisher_cluster,
            args.publisher_db,
            args.target_namespace,
            args.target_db,
        )
    if args.command == "refresh-matviews":
        db_list: list[str] | None = getattr(args, "database", None) or []
        return cmd_refresh_matviews(
            args.indico_namespace,
            str(args.kubeconfig) if args.kubeconfig else None,
            db_list if db_list else None,
            public_schema_only=getattr(args, "public_only", False),
            concurrent_first=not getattr(args, "no_concurrent_first", False),
            dry_run=getattr(args, "dry_run", False),
        )
    if args.command == "minio-to-s3":
        return cmd_minio_to_s3(
            args.miniobkp_bucket,
            args.data_bucket,
            args.tf_dir,
            str(args.kubeconfig) if args.kubeconfig else None,
            args.job_timeout,
            getattr(args, "dry_run", False),
            getattr(args, "delete", False),
            args.skip_backup_job,
            getattr(args, "profile", "Indico-Dev"),
        )
    if args.command == "migrate-all":
        if getattr(args, "az_count", 2) < 1 or getattr(args, "az_count", 2) > 3:
            print("Error: --az-count must be between 1 and 3.", file=sys.stderr)
            return 1
        return cmd_migrate_all(
            args.tf_dir,
            args.output,
            getattr(args, "version", None),
            getattr(args, "helm_repo", None),
            str(args.kubeconfig) if args.kubeconfig else None,
            args.indico_namespace,
            args.replication_password,
            getattr(args, "miniobkp_bucket", None),
            getattr(args, "data_bucket", None),
            args.job_timeout,
            args.skip_backup_job,
            getattr(args, "minio_delete", False),
            args.dry_run,
            getattr(args, "profile", "Indico-Dev"),
            az_count=getattr(args, "az_count", 2),
            postgres_volume_size=getattr(args, "postgres_volume_size", "100Gi"),
            storage_class=getattr(args, "storage_class", "encrypted-gp3"),
            image_registry=getattr(args, "image_registry", "harbor.devops.indico.io"),
            indico_storage_class_name=getattr(args, "indico_storage_class_name", "indico-sc"),
            include_efs=getattr(args, "include_efs", False),
            enable_service_mesh=getattr(args, "enable_service_mesh", False),
            wait_initial_copy=getattr(args, "wait_initial_copy", False),
            initial_copy_timeout_sec=getattr(args, "initial_copy_timeout_sec", 86400),
            fast=getattr(args, "fast", False),
            bootstrap_skip_patroni_patch=getattr(args, "bootstrap_skip_patroni_patch", False),
            bootstrap_patroni_patch_pod_timeout_sec=getattr(
                args, "bootstrap_patroni_patch_pod_timeout_sec", 600
            ),
            bootstrap_patroni_patch_wait_sec=getattr(args, "bootstrap_patroni_patch_wait_sec", 90),
            bootstrap_skip_schema_parity=getattr(args, "bootstrap_skip_schema_parity", False),
            bootstrap_skip_schema_parity_for=_skip_schema_parity_for_names(
                getattr(args, "bootstrap_skip_schema_parity_for", None) or []
            ),
        )

    return 0


if __name__ == "__main__":
    sys.exit(main())
