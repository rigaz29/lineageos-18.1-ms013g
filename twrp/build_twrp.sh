#!/usr/bin/env bash
# =============================================================================
#  build_twrp.sh — Build TWRP recovery untuk Samsung Grand 2 Duos
#                  SM-G7102 / ms013g  (minimal-manifest-twrp, twrp-11)
# -----------------------------------------------------------------------------
#  Pemakaian:
#     ./build_twrp.sh              # sync + build recoveryimage
#     ./build_twrp.sh sync         # cuma repo init + sync + pasang file TWRP
#     ./build_twrp.sh build        # cuma build (asumsi sudah di-sync)
#     TWRP_DIR=~/twrp ./build_twrp.sh
#     JOBS=4 ./build_twrp.sh
# =============================================================================
set -euo pipefail

# ---- Konfigurasi -----------------------------------------------------------
TWRP_DIR="${TWRP_DIR:-$HOME/twrp}"
DEVICE="ms013g"
LUNCH="twrp_${DEVICE}-eng"
MANIFEST_URL="https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git"
MANIFEST_BRANCH="twrp-11"
JOBS="${JOBS:-$(nproc --all)}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOCAL_MANIFEST_SRC="$SCRIPT_DIR/ms013g_twrp.xml"
TWRP_MK_SRC="$SCRIPT_DIR/twrp_ms013g.mk"
ANDROID_PRODUCTS_SRC="$SCRIPT_DIR/AndroidProducts.mk"
DEVICE_DIR_REL="device/samsung/ms013g"

log()  { printf '\033[1;36m[twrp]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[err ]\033[0m %s\n' "$*" >&2; exit 1; }

# ---- pasang file khusus TWRP ke device tree (idempotent) -------------------
install_twrp_files() {
  local dev="$TWRP_DIR/$DEVICE_DIR_REL"
  [ -d "$dev" ] || die "Device tree belum ada: $dev — jalankan './build_twrp.sh sync' dulu."
  log "Memasang twrp_ms013g.mk + AndroidProducts.mk ke $DEVICE_DIR_REL"
  cp "$TWRP_MK_SRC"          "$dev/twrp_ms013g.mk"
  cp "$ANDROID_PRODUCTS_SRC" "$dev/AndroidProducts.mk"
}

# ---- buang modul yg tak kompatibel dgn tree TWRP/AOSP (idempotent) ---------
# power-libperfmgr (power HAL ROM) meng-import namespace Pixel (hardware/google/
# pixel & interfaces) yang tak ada di minimal manifest. Soong mem-parse SEMUA
# Android.bp -> error 'namespace ... does not exist'. Modul ini tak dipakai
# recovery, jadi dibuang. (--force-sync akan mengembalikannya, makanya dipanggil
# ulang tiap sync & sebelum build.)
strip_incompatible() {
  # 1) power HAL yg butuh namespace Pixel
  local hs="$TWRP_DIR/hardware/samsung"
  for d in aidl/power-libperfmgr hidl/power-libperfmgr; do
    if [ -d "$hs/$d" ]; then
      log "Membuang hardware/samsung/$d (butuh namespace Pixel, tak perlu recovery)"
      rm -rf "$hs/$d"
    fi
  done
  # 2) RIL custom device -> bentrok dgn 'libril' bawaan AOSP hardware/ril.
  #    Recovery tak butuh RIL; AOSP libril tetap ada untuk referensi parse.
  local ril="$TWRP_DIR/device/samsung/msm8226-common/ril"
  if [ -d "$ril" ]; then
    log "Membuang device/samsung/msm8226-common/ril (libril bentrok dgn AOSP, tak perlu recovery)"
    rm -rf "$ril"
  fi
}

# ---- 1. sync ---------------------------------------------------------------
do_sync() {
  command -v repo >/dev/null || die "'repo' tidak ditemukan (lihat tutorial LOS langkah 1)."
  [ -f "$LOCAL_MANIFEST_SRC" ] || die "local_manifest tidak ada: $LOCAL_MANIFEST_SRC"

  mkdir -p "$TWRP_DIR"; cd "$TWRP_DIR"

  if [ ! -d .repo ]; then
    log "repo init minimal-manifest-twrp ($MANIFEST_BRANCH) ..."
    repo init -u "$MANIFEST_URL" -b "$MANIFEST_BRANCH" --depth=1
  fi

  log "Memasang local_manifest -> .repo/local_manifests/ms013g_twrp.xml"
  mkdir -p .repo/local_manifests
  cp "$LOCAL_MANIFEST_SRC" .repo/local_manifests/ms013g_twrp.xml

  log "repo sync (jobs=$JOBS) ..."
  repo sync -c -j"$JOBS" --force-sync --no-clone-bundle --no-tags

  for p in "$DEVICE_DIR_REL" device/samsung/ms01-common kernel/samsung/msm8226; do
    [ -d "$TWRP_DIR/$p" ] || die "Path hilang setelah sync: $p (cek local_manifest)"
  done

  install_twrp_files      # dipasang SETELAH sync (agar tak ketimpa --force-sync)
  strip_incompatible
  log "Sync selesai."
}

# ---- 2. build --------------------------------------------------------------
do_build() {
  [ -d "$TWRP_DIR/.repo" ] || die "Tree belum di-init di $TWRP_DIR. Jalankan: ./build_twrp.sh sync"
  cd "$TWRP_DIR"

  install_twrp_files      # pastikan ada (kalau build dijalankan terpisah)
  strip_incompatible

  # Android build env tidak kompatibel dengan 'set -eu'
  set +eu
  export ALLOW_MISSING_DEPENDENCIES=true   # aman untuk recovery build
  export WITH_TWRP=true                     # -> -include twrp.mk (flag TW_*)
  export LC_ALL=C

  log "source build/envsetup.sh"
  # shellcheck disable=SC1091
  source build/envsetup.sh

  log "lunch $LUNCH"
  lunch "$LUNCH"

  log "mka recoveryimage (jobs=$JOBS) ..."
  mka recoveryimage -j"$JOBS"
  local rc=$?
  set -eu
  [ "$rc" -eq 0 ] || die "Build gagal (mka keluar $rc). Kalau soal 'device/qcom/sepolicy' atau 'hardware/qcom/*', buka komentar blok QCOM di ms013g_twrp.xml lalu sync ulang."

  local out="$TWRP_DIR/out/target/product/$DEVICE"
  log "Selesai! Recovery ada di: $out"
  ls -lh "$out"/recovery.img 2>/dev/null || warn "recovery.img tidak ditemukan — cek log di atas."
}

# ---- dispatch --------------------------------------------------------------
case "${1:-all}" in
  sync)  do_sync ;;
  build) do_build ;;
  all)   do_sync; do_build ;;
  *)     die "Argumen tidak dikenal: $1 (pakai: sync | build | all)" ;;
esac
