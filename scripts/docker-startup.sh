#!/bin/sh
set -eu

# This script initializes the database and imports OpenStreetMap data.

wait_for_postgres() {
  attempt=0
  max_attempts=60
  echo "Waiting for PostgreSQL to be running"

  while [ "$attempt" -lt "$max_attempts" ]; do
    if pg_isready -q; then
      echo "PostgreSQL running"
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 2
  done

  echo "Timeout while waiting for PostgreSQL to be running" >&2
  return 1
}

initialize_database() {
  database_exists=$(psql -d postgres -tA -c "SELECT 1 FROM pg_database WHERE datname = 'gis';")
  if [ "$database_exists" != "1" ]; then
    createdb gis
  fi

  psql -v ON_ERROR_STOP=1 -d gis -c 'CREATE EXTENSION IF NOT EXISTS postgis;'
  psql -v ON_ERROR_STOP=1 -d gis -c 'CREATE EXTENSION IF NOT EXISTS hstore;'
}

write_default_env() {
  if [ -e ".env" ]; then
    return 0
  fi

  cat > .env <<EOF
# Environment settings for importing to a Docker container database
PG_WORK_MEM=${PG_WORK_MEM:-16MB}
PG_MAINTENANCE_WORK_MEM=${PG_MAINTENANCE_WORK_MEM:-256MB}
OSM2PGSQL_CACHE=${OSM2PGSQL_CACHE:-512}
OSM2PGSQL_NUMPROC=${OSM2PGSQL_NUMPROC:-1}
OSM2PGSQL_DATAFILE=${OSM2PGSQL_DATAFILE:-data.osm.pbf}
EXTERNAL_DATA_SCRIPT_FLAGS=${EXTERNAL_DATA_SCRIPT_FLAGS:-}
EOF
  chmod a+rw .env
}

run_import() {
  OSM2PGSQL_CACHE=${OSM2PGSQL_CACHE:-512}
  OSM2PGSQL_NUMPROC=${OSM2PGSQL_NUMPROC:-1}
  OSM2PGSQL_DATAFILE=${OSM2PGSQL_DATAFILE:-data.osm.pbf}
  export OSM2PGSQL_CACHE OSM2PGSQL_NUMPROC OSM2PGSQL_DATAFILE

  osm2pgsql --version
  osm2pgsql \
    --slim \
    --cache "$OSM2PGSQL_CACHE" \
    --number-processes "$OSM2PGSQL_NUMPROC" \
    --database gis \
    --extra-attributes \
    -O flex \
    -S default.lua \
    "$OSM2PGSQL_DATAFILE"
}

case "${1:-}" in
  import)
    wait_for_postgres
    initialize_database
    write_default_env
    run_import
    ;;
  *)
    echo "Usage: $0 import" >&2
    exit 2
    ;;
esac