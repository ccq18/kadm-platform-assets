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
  k3s/
```

The first implementation slice packages the assets already consumed by bootstrap:

- K3s `v1.36.2+k3s1` install script
- K3s `v1.36.2+k3s1` linux-amd64 binary
- K3s `v1.36.2+k3s1` linux-amd64 airgap image bundle
- Gateway API `v1.5.1` experimental install manifest
- Argo CD `v3.4.4` install manifest
- Argo Rollouts `v1.9.0` install manifest
- Cilium `1.19.5` chart tarball

The workflow is intentionally kept small in this first revision so it can be triggered independently while the larger image-bundle pipeline is still being designed.

Follow-up work should extend this repository to export platform container images into an OCI or tar-based offline image bundle so bootstrap and system deploy do not depend on registry access.

## Local Build

```bash
scripts/build-bundle.sh
```

The generated bundle is written under `dist/`.

## CI

`build-offline-bundle` runs on push to `main` and on manual dispatch. It uploads the bundle as a GitHub Actions artifact.

It also publishes a stable release asset named `kadm-platform-assets.tgz` on the `bundle-latest` release tag so the bootstrap installer can use a fixed download URL.
