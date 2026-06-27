# KADM Platform Assets

This repository owns the offline-first asset bundle used by KADM platform bootstrap flows.

Current scope in the first commit:

- pinned platform manifest URLs
- pinned chart URLs
- a reproducible bundle script
- a GitHub Actions workflow that builds and uploads the bundle

The bundle format is intentionally aligned with the current installer cache layout:

```text
cache/
  manifests/
  charts/
```

The first implementation slice packages the assets already consumed by bootstrap:

- Gateway API `v1.5.1` experimental install manifest
- Argo CD `v3.4.4` install manifest
- Argo Rollouts `v1.9.0` install manifest
- Cilium `1.19.5` chart tarball

Follow-up work should extend this repository to export platform container images into an OCI or tar-based offline image bundle so bootstrap and system deploy do not depend on registry access.

## Local Build

```bash
scripts/build-bundle.sh
```

The generated bundle is written under `dist/`.

## CI

`build-offline-bundle` runs on push to `main` and on manual dispatch. It uploads the bundle as a GitHub Actions artifact.
