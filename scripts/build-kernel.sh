#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config_file="${1:-$repo_root/config/build.env}"

if [[ ! -f "$config_file" ]]; then
  echo "missing config: $config_file" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$config_file"

: "${UPSTREAM_REPO:=https://github.com/CachyOS/linux-cachyos.git}"
: "${UPSTREAM_REF:=master}"
: "${UPSTREAM_SUBDIR:=linux-cachyos-bore}"
: "${CPU_SCHED:=bore}"
: "${PROCESSOR_OPT:=generic_v3}"
: "${USE_LLVM_LTO:=thin}"
: "${USE_LTO_SUFFIX:=yes}"
: "${CC_HARDER:=yes}"
: "${HZ_TICKS:=1000}"
: "${TICKRATE:=full}"
: "${PREEMPT:=full}"
: "${HUGEPAGE:=always}"
: "${PER_GOV:=no}"
: "${TCP_BBR3:=no}"
: "${USE_KCFI:=no}"
: "${MAKEPKG_SYNCDEPS:=no}"
: "${PACKAGE_OUTPUT_DIR:=out}"
: "${PATCH_DIR:=patches}"

work_root="$repo_root/work"
checkout_dir="$work_root/upstream"
pkg_dir="$checkout_dir/$UPSTREAM_SUBDIR"
pkgbuild="$pkg_dir/PKGBUILD"
patch_dir="$repo_root/$PATCH_DIR"
out_dir="$repo_root/$PACKAGE_OUTPUT_DIR"
src_cache="$repo_root/cache/src"
log_dir="$repo_root/cache/log"

mkdir -p "$work_root" "$out_dir" "$src_cache" "$log_dir"
rm -rf "$checkout_dir"

git clone --depth=1 --branch "$UPSTREAM_REF" "$UPSTREAM_REPO" "$checkout_dir"

if [[ ! -f "$pkgbuild" ]]; then
  echo "missing PKGBUILD: $pkgbuild" >&2
  exit 1
fi

if ! command -v updpkgsums >/dev/null 2>&1; then
  echo "missing dependency: updpkgsums (install pacman-contrib)" >&2
  exit 1
fi

set_pkgbuild_var() {
  local key="$1"
  local value="$2"
  if ! grep -q ": \"\\\${${key}:=" "$pkgbuild"; then
    echo "PKGBUILD variable '${key}' not found (upstream may have renamed it)" >&2
    exit 1
  fi
  perl -0pi -e "s/: \"\\\$\\{$key:=.*?\\}\"/: \"\\\$\\{$key:=$value\\}\"/g" "$pkgbuild"
}

set_pkgbuild_var "_cpusched" "$CPU_SCHED"
set_pkgbuild_var "_processor_opt" "$PROCESSOR_OPT"
set_pkgbuild_var "_use_llvm_lto" "$USE_LLVM_LTO"
set_pkgbuild_var "_use_lto_suffix" "$USE_LTO_SUFFIX"
set_pkgbuild_var "_cc_harder" "$CC_HARDER"
set_pkgbuild_var "_HZ_ticks" "$HZ_TICKS"
set_pkgbuild_var "_tickrate" "$TICKRATE"
set_pkgbuild_var "_preempt" "$PREEMPT"
set_pkgbuild_var "_hugepage" "$HUGEPAGE"
set_pkgbuild_var "_per_gov" "$PER_GOV"
set_pkgbuild_var "_tcp_bbr3" "$TCP_BBR3"
set_pkgbuild_var "_use_kcfi" "$USE_KCFI"

# The upstream PKGBUILD ships checksum arrays for its default source set.
# Once we flip build knobs like LLVM LTO, conditional sources change and the
# integrity arrays must be regenerated or makepkg will stop before prepare().
(
  cd "$pkg_dir"
  updpkgsums PKGBUILD
)

export PKGDEST="$out_dir"
export SRCDEST="$src_cache"
export LOGDEST="$log_dir"
export MAKEFLAGS="${MAKEFLAGS:--j$(nproc)}"

makepkg_args=(--noconfirm)
if [[ "$MAKEPKG_SYNCDEPS" == "yes" ]]; then
  makepkg_args+=(--syncdeps)
fi

cd "$pkg_dir"
env -u CI -u GITHUB_RUN_ID makepkg "${makepkg_args[@]}" --nobuild

if [[ -d "$patch_dir" ]]; then
  mapfile -t local_patches < <(find "$patch_dir" -maxdepth 1 -type f -name '*.patch' | sort)
else
  local_patches=()
fi

if (( ${#local_patches[@]} > 0 )); then
  source_tree="$(find src -mindepth 1 -maxdepth 1 -type d -name 'cachyos-*' | head -n 1)"
  if [[ -z "$source_tree" ]]; then
    echo "unable to locate prepared kernel source tree under $pkg_dir/src" >&2
    exit 1
  fi

  for patch_file in "${local_patches[@]}"; do
    echo "Applying local patch: $(basename "$patch_file")"
    patch -d "$source_tree" -Np1 < "$patch_file"
  done
fi

env -u CI -u GITHUB_RUN_ID makepkg "${makepkg_args[@]}" --noextract --noprepare
