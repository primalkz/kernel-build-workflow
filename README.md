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

Those are a separate upstream build lane. If you want them later, retarget `UPSTREAM_SUBDIR` to the relevant upstream package directory and verify its PKGBUILD knobs before building.

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

Push this repo to GitHub, then run the `Build CachyOS Kernel` workflow manually from the Actions tab.

The workflow uploads package artifacts from `out/` as GitHub Actions artifacts.

On your Arch system, install the resulting packages with:

```bash
sudo pacman -U ./linux-cachyos-bore-lto-*.pkg.tar.zst ./linux-cachyos-bore-lto-headers-*.pkg.tar.zst
```

Then regenerate boot entries if needed:

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

## Sources

- CachyOS kernel repo: https://github.com/CachyOS/linux-cachyos
- CachyOS README on compiler variants and architecture tiers: https://github.com/CachyOS/linux-cachyos
