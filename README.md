# KADM Platform Assets

This repository owns the offline-first asset bundle used by KADM platform bootstrap flows.

Current scope:

- pinned platform manifest URLs
- pinned chart URLs
- pinned K3s installer assets
- cached Helm archive
- cached KADM bootstrap repository archives
- runtime container image archive for the current platform and app configs
- a reproducible bundle script
- a GitHub Actions workflow that builds and publishes the release bundle

The bundle format is intentionally aligned with the current installer cache layout:

```text
cache/
  manifests/
  charts/
  k3s/
  tools/
  images/
  repos/
metadata/
```

The complete offline bundle packages the assets consumed by bootstrap and by the current runtime:

- K3s `v1.36.2+k3s1` install script
- K3s `v1.36.2+k3s1` linux-amd64 binary
- K3s `v1.36.2+k3s1` linux-amd64 airgap image bundle
- Helm `v3.15.4` linux-amd64 archive
- Gateway API `v1.5.1` experimental install manifest
- Argo CD `v3.4.4` install manifest
- Argo Rollouts `v1.9.0` install manifest
- Cilium `1.19.5` chart tarball
- runtime images referenced by the pinned Argo CD and Argo Rollouts manifests, Cilium defaults used by KADM, the KADM release console overlay, and current `kadm-app-configs` production overlays
- source archives for `kadm-platform-system`, `kadm-release-console`, and `kadm-app-configs`

The generated bundle is expected to be large. The current project is expected to produce roughly a 1.1 GB to 1.5 GB release asset after runtime images are included. Generated bundles must not be committed to Git.

## Local Build

```bash
scripts/build-bundle.sh
```

The generated bundle is written under `dist/`.

To inspect the runtime image list without pulling or saving images:

```bash
scripts/build-bundle.sh --list-images
```

Private GHCR images require credentials when building the full image archive:

```bash
export KADM_GHCR_USERNAME=<github-user>
export KADM_GHCR_TOKEN=<token-with-package-read>
scripts/build-bundle.sh
```

## CI

`build-offline-bundle` runs on push to `main` and on manual dispatch.

It publishes a stable release asset named `kadm-platform-assets.tgz` on the `bundle-latest` release tag so the bootstrap installer can use a fixed download URL.

The workflow intentionally does not upload the full bundle as a long-lived GitHub Actions artifact. Large bundles should be distributed through GitHub Release assets to avoid exhausting Actions artifact storage quotas.
