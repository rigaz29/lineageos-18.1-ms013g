#!/usr/bin/env bash
# =============================================================================
#  build.sh — Build LineageOS 18.1 (Go opsional) untuk Samsung Grand 2 Duos
#             SM-G7102 / codename: ms013g
#             Source: https://github.com/Grand-2-Rebirth
# -----------------------------------------------------------------------------
#  Pemakaian:
#     ./build.sh                 # sync + build lengkap
#     ./build.sh sync            # cuma repo init + sync
#     ./build.sh build           # cuma build (asумsi source sudah ada)
#     ENABLE_GO=1 ./build.sh     # aktifkan optimasi Android Go (low-RAM)
#     CLEAN=1 ./build.sh build   # 'mka clean' dulu sebelum build
#     JOBS=4 ./build.sh          # batasi paralel job (default: semua core)
# =============================================================================
set -euo pipefail

# ---- Konfigurasi -----------------------------------------------------------
SRC_DIR="${SRC_DIR:-$HOME/android/lineage}"     # root source tree
DEVICE="ms013g"
LUNCH="lineage_${DEVICE}-userdebug"
MANIFEST_BRANCH="lineage-18.1"
LOCAL_MANIFEST_SRC="${LOCAL_MANIFEST_SRC:-$(cd "$(dirname "$0")" && pwd)/ms013g.xml}"
JOBS="${JOBS:-$(nproc --all)}"
ENABLE_GO="${ENABLE_GO:-0}"
CLEAN="${CLEAN:-0}"

log()  { printf '\033[1;36m[build]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn ]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

# ---- 1. repo init + local_manifest + sync ----------------------------------
do_sync() {
  command -v repo >/dev/null || die "'repo' tidak ditemukan. Pasang dulu (lihat tutorial langkah 1)."
  [ -f "$LOCAL_MANIFEST_SRC" ] || die "local_manifest tidak ada: $LOCAL_MANIFEST_SRC"

  mkdir -p "$SRC_DIR"
  cd "$SRC_DIR"

  if [ ! -d .repo ]; then
    log "repo init LineageOS $MANIFEST_BRANCH ..."
    repo init -u https://github.com/LineageOS/android.git -b "$MANIFEST_BRANCH" --git-lfs
  fi

  log "Memasang local_manifest -> .repo/local_manifests/ms013g.xml"
  mkdir -p .repo/local_manifests
  cp "$LOCAL_MANIFEST_SRC" .repo/local_manifests/ms013g.xml

  log "repo sync (jobs=$JOBS) — ini bisa lama & besar (~40-60 GB) ..."
  repo sync -c -j"$JOBS" --force-sync --no-clone-bundle --no-tags

  # verifikasi path kunci
  for p in device/samsung/ms013g device/samsung/ms01-common kernel/samsung/msm8226 \
           vendor/samsung/ms013g hardware/samsung hardware/sony/timekeep; do
    [ -d "$SRC_DIR/$p" ] || die "Path hilang setelah sync: $p (cek local_manifest)"
  done
  log "Sync selesai, semua dependensi ada."
}

# ---- 2. (opsional) aktifkan Android Go / low-RAM ---------------------------
# Idempotent: menambah properti low-RAM ke system.prop device.
# Ini adalah cara 'runtime' yang aman. Untuk Go build-time penuh, lihat catatan
# di bawah tentang inherit go_defaults.mk.
enable_go() {
  local propfile="$SRC_DIR/device/samsung/ms013g/system.prop"
  [ -f "$propfile" ] || propfile="$SRC_DIR/device/samsung/ms01-common/system.prop"
  [ -f "$propfile" ] || { warn "system.prop device tidak ditemukan, lewati Go."; return; }

  if grep -q '^ro.config.low_ram=true' "$propfile"; then
    log "Optimasi Go sudah aktif di $(basename "$(dirname "$propfile")")/system.prop"
    return
  fi

  log "Mengaktifkan optimasi Android Go (low-RAM) di $propfile"
  cat >> "$propfile" <<'EOF'

# --- Android Go / low-RAM (ditambahkan oleh build.sh) ---
ro.config.low_ram=true
ro.lmk.use_minfree_levels=true
dalvik.vm.heapgrowthlimit=96m
dalvik.vm.heapsize=256m
pm.dexopt.first-boot=quicken
pm.dexopt.boot=verify
EOF
  warn "Tree device kini 'dirty'. Sebelum 'repo sync' berikutnya, jalankan:"
  warn "  (cd $(dirname "$propfile") && git checkout -- system.prop)"
  warn "Untuk Go build-time PENUH (lebih menyeluruh, sedikit lebih berisiko), tambahkan"
  warn "  \$(call inherit-product, build/make/target/product/go_defaults.mk)"
  warn "ke device/samsung/ms013g/lineage_ms013g.mk"
}

# ---- 3. build --------------------------------------------------------------
do_build() {
  [ -d "$SRC_DIR/.repo" ] || die "Source belum di-init di $SRC_DIR. Jalankan: ./build.sh sync"
  cd "$SRC_DIR"

  export USE_CCACHE=1
  export CCACHE_EXEC="$(command -v ccache || true)"
  [ -n "${CCACHE_EXEC:-}" ] && ccache -M "${CCACHE_SIZE:-30G}" >/dev/null 2>&1 || warn "ccache tidak terpasang (build lebih lambat)."

  [ "$ENABLE_GO" = "1" ] && enable_go

  log "source build/envsetup.sh"
  # shellcheck disable=SC1091
  source build/envsetup.sh

  log "lunch $LUNCH"
  lunch "$LUNCH"

  if [ "$CLEAN" = "1" ]; then
    log "mka clean ..."
    mka clean
  fi

  log "Mulai kompilasi (mka bacon, jobs=$JOBS) — santai, ini lama ..."
  mka bacon -j"$JOBS"

  local out="$SRC_DIR/out/target/product/$DEVICE"
  log "Selesai! Cari hasil di: $out"
  ls -lh "$out"/lineage-18.1-*-"$DEVICE".zip 2>/dev/null || warn "Zip tidak ditemukan — cek log build di atas."
}

# ---- dispatch --------------------------------------------------------------
case "${1:-all}" in
  sync)  do_sync ;;
  build) do_build ;;
  all)   do_sync; do_build ;;
  *)     die "Argumen tidak dikenal: $1 (pakai: sync | build | all)" ;;
esac
