# ci/

Supporting material for the pipeline in [`.github/workflows/ci.yml`](../.github/workflows/ci.yml)
(GitHub requires workflows to live in `.github/workflows/`).

The workflow is self-contained today. Its scanner settings are inline: Trivy gates on
fixable HIGH/CRITICAL findings, and every run uploads a full SARIF report to the Security tab.
Run the same checks locally before pushing:

```bash
cd app
ruff check . && ruff format --check .
pytest -W error
docker build -t sampleapi:scan .
docker run --rm -v //var/run/docker.sock:/var/run/docker.sock aquasec/trivy:0.74.0   image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 sampleapi:scan
```

See [docs/phases/03-ci.md](../docs/phases/03-ci.md) for the design.
