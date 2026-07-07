# CachyOS Kernel Workflow

This repo builds stock-Arch-installable kernel packages from the upstream CachyOS sources.

The point is narrow:

- keep the CachyOS `bore` kernel tuning
- keep the Clang ThinLTO path
- target `generic_v3` inside the kernel config so a GitHub runner does not accidentally build for its own CPU
- emit normal `x86_64` Arch packages so stock `pacman` accepts them
- give you a patch queue for small hardware-specific fixes

### This exists because the prebuilt CachyOS `x86_64_v3` packages are rejected by stock Arch `pacman` with `package architecture is not valid`.

## What The Workflow Builds

Default output:

- `linux-cachyos-bore-lto`
- `linux-cachyos-bore-lto-headers`

Current scope:

- `bore`
- Clang
- ThinLTO
- `generic_v3`

Not enabled by default:

- AutoFDO
- Propeller

Upstream ships these only on the default `linux-cachyos` package (EEVDF), not on `linux-cachyos-bore`. They need a profile file from a two-pass build (build, profile a real workload with `perf record`, rebuild with the profile), and that profile is CPU-specific. A profile captured on a GitHub Actions runner would be tuned to the runner's CPU, not yours, so the payoff is thin.

Upstream base:

- repository: `https://github.com/CachyOS/linux-cachyos`
- package directory: `linux-cachyos-bore`
- scheduler: `bore`
- LLVM LTO mode: `thin`

## Why This Repo Forces `generic_v3`

Upstream CachyOS exposes `_processor_opt`, and the PKGBUILD defaults to `native` when it is left empty. On GitHub Actions that would optimize the kernel for the runner CPU instead of a portable `x86-64-v3` target.

This repo sets:

- `_processor_opt=generic_v3`
- `_use_llvm_lto=thin`
- `_use_lto_suffix=yes`
- `_cc_harder=yes`

It also unsets `CI` and `GITHUB_RUN_ID` before `makepkg`, because the upstream PKGBUILD detects CI and otherwise flips the kernel from `-O3` to `-Os`.

Use `patches/*.patch` only for concrete issues you can name.

## Layout

- `config/build.env`
- `scripts/build-kernel.sh`
- `patches/README.md`
- `.github/workflows/build.yml`

## Usage

Run the `Build CachyOS Kernel` workflow from the Actions tab (manual `workflow_dispatch`), or run it on the `0 0 */5 * *` schedule (every 5 days at midnight UTC). Manual runs let you override `upstream_ref` and `processor_opt`. Scheduled runs build whatever upstream `master` points at.

The workflow uploads package artifacts from `out/` as GitHub Actions artifacts.

On your Arch system, install the resulting packages with:

```bash
sudo pacman -U ./linux-cachyos-bore-lto-*.pkg.tar.zst ./linux-cachyos-bore-lto-headers-*.pkg.tar.zst
```

Then regenerate boot entries if needed:

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

### Scheduled Builds And Upstream Sync

On the 5-day schedule, `check-upstream` compares CachyOS's `linux-cachyos` HEAD against the hash on the `tracking` branch and skips the build if they match. After a successful build, two steps run:

- `Sync upstream bore dir` mirrors `linux-cachyos-bore/` into `upstream/linux-cachyos-bore/` on `master`.
- `Update tracking branch` records the built hash on `tracking` for the next comparison.

Both are skipped on manual `workflow_dispatch` runs.

## Sources

- CachyOS kernel repo: https://github.com/CachyOS/linux-cachyos
- CachyOS kernel wiki: https://wiki.cachyos.org/features/kernel
