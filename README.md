# KADM Platform Assets

This repository owns the offline-first asset bundle used by KADM platform bootstrap flows.

Current scope:

- pinned platform manifest URLs
- pinned chart URLs
- pinned K3s installer assets
- cached Helm archive
- cached KADM bootstrap repository archives
- runtime container image archive for the current platform components
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
- runtime images referenced by the pinned Argo CD and Argo Rollouts manifests, Cilium defaults used by KADM, and the KADM release console overlay
- source archives for `kadm-platform-system`, `kadm-release-console`, and `kadm-app-configs`

The generated bundle is expected to be large. The current platform-only bundle is roughly 900 MB after runtime images are included. Generated bundles must not be committed to Git.

Application runtime images referenced by `kadm-app-configs` are intentionally not included in this platform bundle. They should be distributed by the application release pipeline or a separate application image bundle.

## Release

The latest complete offline platform bundle is published to:

- Release page: <https://github.com/ccq18/kadm-platform-assets/releases/tag/bundle-latest>
- Stable asset URL: <https://github.com/ccq18/kadm-platform-assets/releases/download/bundle-latest/kadm-platform-assets.tgz>

The stable asset name is always `kadm-platform-assets.tgz`. Versioned assets are also uploaded for inspection, but installers should use the stable URL unless testing a specific build.

## Usage

On the first server, run the bootstrap installer. By default it downloads the stable `bundle-latest` asset, restores the bundled KADM repositories, imports the offline cache, installs K3s, imports platform runtime images into K3s containerd, and configures delivery:

```bash
curl -fsSL https://raw.githubusercontent.com/ccq18/kadm-platform-system/main/bootstrap/install-kadm.sh | \
  bash -s -- all \
    --cluster kadm-test \
    --access-host root@47.102.134.76 \
    --private-ip 10.0.1.40 \
    --dns-upstream 1.1.1.1 \
    --dns-upstream 8.8.8.8
```

To use a different bundle URL, set `KADM_ASSET_BUNDLE_URL`:

```bash
export KADM_ASSET_BUNDLE_URL=https://github.com/ccq18/kadm-platform-assets/releases/download/bundle-latest/kadm-platform-assets.tgz

curl -fsSL https://raw.githubusercontent.com/ccq18/kadm-platform-system/main/bootstrap/install-kadm.sh | \
  bash -s -- prepare
```

The `all` action runs `prepare` and then `deploy`. Use `prepare` alone to pre-download and import the bundle before making cluster changes; use `deploy` later to install K3s and platform components from the imported cache.

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

In GitHub Actions, the workflow uses `GITHUB_TOKEN` with `packages: read` by default. Set `KADM_GHCR_USERNAME` and `KADM_GHCR_TOKEN` repository secrets only when the packages are not granted to this repository.

## CI

`build-offline-bundle` runs on push to `main` and on manual dispatch.

It publishes a stable release asset named `kadm-platform-assets.tgz` on the `bundle-latest` release tag so the bootstrap installer can use a fixed download URL.

Manual trigger:

```bash
gh workflow run build-offline-bundle.yaml --ref main
gh run watch
```

The workflow intentionally does not upload the full bundle as a long-lived GitHub Actions artifact. Large bundles should be distributed through GitHub Release assets to avoid exhausting Actions artifact storage quotas.
