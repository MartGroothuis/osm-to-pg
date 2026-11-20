# OSM naar PostgreSQL

Importeer OpenStreetMap-data in PostgreSQL/PostGIS en serveer vector tiles met
Martin. De standaardconfiguratie gebruikt een extract van Overijssel.

## Snel starten

Vereist: Docker met Docker Compose.

```sh
git clone <repository-url>
cd osm-to-pg
docker compose up --build
```

De eerste import kan even duren. Volg de voortgang met:

```sh
docker compose logs -f import
```

Daarna zijn PostgreSQL/PostGIS beschikbaar op `localhost:5432` en de Martin-webinterface
op `http://localhost:3005/`. Kies **Tiles** en vervolgens **Inspect** om een
vector-tilebron te bekijken.

Stop de containers met `Ctrl+C`. Om ze op de achtergrond te starten, gebruik
`docker compose up --build -d`; stop ze daarna met `docker compose down`.

## Instellingen

- Pas de resource-instellingen aan in `.env`, zoals `OSM2PGSQL_CACHE`,
  `OSM2PGSQL_NUMPROC` en `PG_WORK_MEM`.
- De standaarddata-URL staat bij `OSM2PGSQL_DATAFILE` in `docker-compose.yml`.
  Pas deze aan om een ander `.osm.pbf`-bestand of extract te importeren.
- De importdefinities staan in `default.lua`; Martin is ingesteld via
  `config.yaml`.

De database gebruikt standaard de gebruikersnaam en het wachtwoord `postgres`.
Gebruik deze configuratie alleen voor lokaal gebruik.
