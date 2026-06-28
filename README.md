# KADM Platform Assets

`kadm-platform-assets` 负责构建和发布 KADM 平台离线资源包。安装入口不在本仓库，而在 `kadm-platform-system/bootstrap/install-kadm.sh`。

## Release 地址

最新稳定平台离线包发布在：

- Release page: <https://github.com/ccq18/kadm-platform-assets/releases/tag/bundle-latest>
- Stable asset URL: <https://github.com/ccq18/kadm-platform-assets/releases/download/bundle-latest/kadm-platform-assets.tgz>

安装脚本默认使用 stable asset URL。除非测试特定构建，否则不要把安装文档绑定到某个版本化文件名。

## Bundle 内容

生成的 `kadm-platform-assets.tgz` 与安装缓存布局一致：

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

当前完整平台 bundle 包含：

- K3s `v1.36.2+k3s1` install script、linux-amd64 binary、airgap image bundle
- Helm `v3.15.4` linux-amd64 archive
- Gateway API `v1.5.1` experimental install manifest
- Argo CD `v3.4.4` install manifest
- Argo Rollouts `v1.9.0` install manifest
- Cilium `1.19.5` chart
- 平台运行镜像：Argo CD、Argo Rollouts、Cilium、KADM Release Console
- `kadm-platform-system` 源码归档，包含 `console/`
- `kadm-app-configs` 源码归档

业务应用镜像不包含在平台 bundle 中。应用镜像由应用仓库 CI 推送到 GHCR；完全离线应用分发应使用单独的应用镜像包。

当前平台 bundle 约 900 MB。`dist/` 是构建产物目录，不能提交到 Git。

## 使用方式

服务器默认安装：

```bash
export KADM_GITHUB_TOKEN=<github-token>

curl -fsSL https://raw.githubusercontent.com/ccq18/kadm-platform-system/main/bootstrap/install-kadm.sh | \
  bash -s -- all \
    --cluster kadm-test \
    --access-host root@<public-ip> \
    --private-ip <private-ip>
```

使用本地资源包：

```bash
export KADM_ASSET_BUNDLE_URL=file:///opt/kadm/kadm-platform-assets.tgz
export KADM_GITHUB_TOKEN=<github-token>

curl -fsSL https://raw.githubusercontent.com/ccq18/kadm-platform-system/main/bootstrap/install-kadm.sh | \
  bash -s -- prepare
```

`file://` 路径必须存在于执行安装脚本的机器上。

## 本地构建

```bash
scripts/build-bundle.sh
```

只查看运行镜像清单：

```bash
scripts/build-bundle.sh --list-images
```

跳过镜像导出，构建非完整 bundle：

```bash
scripts/build-bundle.sh --skip-image-export
```

私有 GHCR 包需要凭据：

```bash
export KADM_GHCR_USERNAME=<github-user>
export KADM_GHCR_TOKEN=<token-with-package-read>
scripts/build-bundle.sh
```

## CI

`Build Offline Bundle` 在以下情况下运行：

- 手动触发 `workflow_dispatch`
- `main` 分支中 workflow、`scripts/**` 或 `versions/**` 改动

README-only 改动不会自动重建约 900 MB 的离线包。

手动触发：

```bash
gh workflow run build-offline-bundle.yaml --ref main
gh run watch
```

CI 使用 `GITHUB_TOKEN` 读取 GitHub/GHCR。只有当包权限没有授予本仓库时，才需要额外配置 `KADM_GHCR_USERNAME` 和 `KADM_GHCR_TOKEN` secrets。

---

# KADM Platform Assets

`kadm-platform-assets` builds and publishes the KADM offline platform bundle. The install entrypoint lives in `kadm-platform-system/bootstrap/install-kadm.sh`, not in this repository.

## Release URLs

The latest stable platform bundle is published at:

- Release page: <https://github.com/ccq18/kadm-platform-assets/releases/tag/bundle-latest>
- Stable asset URL: <https://github.com/ccq18/kadm-platform-assets/releases/download/bundle-latest/kadm-platform-assets.tgz>

Installers use the stable asset URL by default. Use versioned asset names only when testing a specific build.

## Bundle Contents

The generated `kadm-platform-assets.tgz` matches the installer cache layout:

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

The current complete platform bundle includes:

- K3s `v1.36.2+k3s1` install script, linux-amd64 binary, and airgap image bundle
- Helm `v3.15.4` linux-amd64 archive
- Gateway API `v1.5.1` experimental install manifest
- Argo CD `v3.4.4` install manifest
- Argo Rollouts `v1.9.0` install manifest
- Cilium `1.19.5` chart
- Platform runtime images for Argo CD, Argo Rollouts, Cilium, and KADM Release Console
- Source archive for `kadm-platform-system`, including `console/`
- Source archive for `kadm-app-configs`

Business application images are not included in the platform bundle. Application images are pushed to GHCR by application repository CI. Fully offline application distribution should use a separate application image bundle.

The current platform bundle is about 900 MB. `dist/` is generated output and must not be committed to Git.

## Usage

Default server install:

```bash
export KADM_GITHUB_TOKEN=<github-token>

curl -fsSL https://raw.githubusercontent.com/ccq18/kadm-platform-system/main/bootstrap/install-kadm.sh | \
  bash -s -- all \
    --cluster kadm-test \
    --access-host root@<public-ip> \
    --private-ip <private-ip>
```

Use a local bundle:

```bash
export KADM_ASSET_BUNDLE_URL=file:///opt/kadm/kadm-platform-assets.tgz
export KADM_GITHUB_TOKEN=<github-token>

curl -fsSL https://raw.githubusercontent.com/ccq18/kadm-platform-system/main/bootstrap/install-kadm.sh | \
  bash -s -- prepare
```

The `file://` path must exist on the machine running the installer.

## Local Build

```bash
scripts/build-bundle.sh
```

Print only the runtime image list:

```bash
scripts/build-bundle.sh --list-images
```

Build a non-complete bundle without exporting images:

```bash
scripts/build-bundle.sh --skip-image-export
```

Private GHCR packages need credentials:

```bash
export KADM_GHCR_USERNAME=<github-user>
export KADM_GHCR_TOKEN=<token-with-package-read>
scripts/build-bundle.sh
```

## CI

`Build Offline Bundle` runs on:

- Manual `workflow_dispatch`
- Pushes to `main` that change the workflow, `scripts/**`, or `versions/**`

README-only changes do not automatically rebuild the roughly 900 MB offline bundle.

Manual trigger:

```bash
gh workflow run build-offline-bundle.yaml --ref main
gh run watch
```

CI uses `GITHUB_TOKEN` for GitHub/GHCR reads. Configure `KADM_GHCR_USERNAME` and `KADM_GHCR_TOKEN` secrets only when package permissions are not granted to this repository.
