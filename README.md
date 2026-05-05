# Key Performance Indicators API (KAPI)

This repository contains the code to build and deploy a temporary API service exposing data from the CGIAR Excellence in Agronomy initiative.

The service is based on datasets processed using the carob workflow. The eia-carob repository is included as a submodule and contains the data compilation logic.

## System Architecture

The system is designed as a portable, three-layer architecture that separates data management from application logic.

### Layer 1 — Data Source (CG Labs)
Authoritative source of raw data. The data is stored in the [File Manager](https://datadrive.scio.services/), and transferred from [CG Labs](https://eia.scio.services:18002/) to the deployment environment using rsync over SSH.

Example:

```bash
rsync -avz -e "ssh -i ~/.ssh/<KEY>.pem" \
  ~/carob-eia/data/ \
  user@<VM-IP>:~/carob-eia/data/
```

### Layer 2 — Data Staging (Host)
Data is stored on the host machine filesystem, where paths are defined **only via environment variables** in a .env file. No assumptions are made about disk devices, partitions, or cloud provider.

Example `.env`:

```bash
RAW_DATA=~/carob-eia/data/raw
COMPILED_DATA=~/carob-eia/data/compiled
```

### Layer 3 — Application (Containers)
The application runs as Docker containers managed via `docker-compose`. The containers do **not** depend on host-specific paths and the data is injected via bind mounts defined in `docker-compose.yml` using the variables defined in the `.env` file.

Example:

```yaml
services:
  data:
    volumes:
      - ${RAW_DATA}:/usr/local/data/carob-eia/raw
      - ${COMPILED_DATA}:/usr/local/data/carob-eia/compiled
```

Inside the container, all scripts operate on:

```
/usr/local/data/carob-eia
```

## Data Pipeline

The system consists of two main components:

### 1. Data Compilation Container
- Executes the data pipeline using `carob`
- Reads raw data from `/usr/local/data/carob-eia/raw`
- Writes processed outputs to `/usr/local/data/carob-eia/compiled`

### 2. API Container
- Implements the API using `plumber`
- Serves compiled data via REST endpoints
- Reads from `/usr/local/data/carob-eia/compiled`

## Data Transfer Strategy

The current implementation requires an instance of the data EiA use case data from [File Manager](https://datadrive.scio.services/) Excellence in Agronomy folder on [CG Labs](https://eia.scio.services:18002/). The data can be copied using the `usecase_code` (in File Manager) &rarr; `folder_name` (in CG Labs).

For example:

| Folder in File Manager <br> (`usecase_code`) | &rarr; | Folder in CG Labs <br>(`folder_name`) |
|---|---|---|
| USC012 | &rarr; |Cambodia-DSRC-Validation |
| USC016 | &rarr; |Chinyanja-Solidaridad-Soy-AddOn |
|...|  |...|
| USC016 | &rarr; |Chinyanja-Solidaridad-Soy-NOT |

Then use `rsync` over SSH to transfer the raw source data to the target host (VM). There is also an Azure blob available ([https://kapi.blob.core.windows.net](https://kapi.blob.core.windows.net)), but it hasn't been implemented as data source. You can use `scripts/sync_data.sh` from [CG Labs](https://eia.scio.services:18002/) in order to transfer the data. Change the `.env` file with `scripts/sync_data.sh` or run a variaton of the code below from CG Labs.

```bash
#!/bin/bash

set -e

SOURCE=~/carob-eia/data/
TARGET=<SAMPLE_USER>@<HOST_IP>:~/carob-eia/data/
KEY=~/.ssh/key.pem

rsync -avz \
  --progress \
  -e "ssh -i $KEY" \
  "$SOURCE" \
  "$TARGET"
```

#### Notes
- Use `--dry-run` (`-n`) to preview changes before syncing
- Avoid using `--delete` unless you fully understand the implications
- This step is external to Docker and must be executed before running the containers

## Deployment

### Requirements
- Docker
- Docker Compose
- SSH access to the target machine

### Steps
1. Clone the repository:
```bash
git clone https://github.com/EiA2030/kapi-eia.git
cd kapi-eia
```

2. Configure environment variables:

```bash
cp .env.example .env
```

Edit `.env` with correct variables and paths.


3. Transfer data to the host (if needed):
```bash
rsync -av -e "ssh -i ~/.ssh/key.pem" $SOURCE_DIR $TARGET_USER@$TARGET_HOST:$TARGET_DIR
```

4. Start the services:
```bash
docker compose up -d
```

## API Endpoints

The KAPI service currently exposes two endpoints:

1. Activity Data
Returns standardized activity data for a given use case.
2. KPI Metrics
Returns processed KPI metrics for a given use case.

## Design Principles
- Portability: No dependency on a specific cloud provider
- Separation of concerns: Data, infrastructure, and application are decoupled
- Reproducibility: Environment defined via `.env` and `docker-compose`
- Minimal infrastructure assumptions: No required disk mounting or system-level configuration

## Known Limitations
- Data transfer is manual (rsync-based)
- Hardcoded paths exist within the data pipeline (abstracted via container mounts)
- No built-in data versioning or synchronization guarantees

## Future Improvements
- Replace hardcoded paths with environment-based configuration in R
- Introduce object storage abstraction (e.g. S3-compatible backends)
- Automate data synchronization as part of CI/CD
- Add monitoring and logging for data pipeline execution