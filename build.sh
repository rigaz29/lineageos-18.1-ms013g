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
WITH_MICROG="${WITH_MICROG:-0}"
# LOS 18.1 SUDAH punya signature spoofing 'restricted' bawaan (khusus microG asli),
# jadi microG jalan TANPA patch. Set MICROG_UNRESTRICTED=1 hanya jika mau spoofing
# generik (app non-microG boleh spoof) — patch frameworks/base.
MICROG_UNRESTRICTED="${MICROG_UNRESTRICTED:-0}"
CLEAN="${CLEAN:-0}"
# patch signature spoofing generik untuk Android 11 (dipakai hanya bila MICROG_UNRESTRICTED=1)
MICROG_PATCH_URL="${MICROG_PATCH_URL:-https://raw.githubusercontent.com/lineageos4microg/docker-lineage-cicd/master/src/signature_spoofing_patches/android_frameworks_base-R.patch}"

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

# ---- 2b. (opsional) integrasi microG (lineageos4microg) --------------------
# LOS 18.1 sudah punya signature spoofing 'restricted' bawaan (khusus microG asli
# yg PRESIGNED), jadi microG jalan TANPA patch frameworks/base.
# Langkah default: (1) unduh APK, (2) inherit paket ke product makefile.
# Patch generik hanya dijalankan bila MICROG_UNRESTRICTED=1. Semua idempotent.
enable_microg() {
  local gms="$SRC_DIR/vendor/partner_gms"
  [ -d "$gms" ] || die "vendor/partner_gms belum ada. Jalankan './build.sh sync' dulu (manifest sudah memuatnya)."

  # (1) unduh APK (microG, FakeStore, GsfProxy, F-Droid) — vendorsetup.sh idempotent
  log "microG: mengunduh APK dari GitHub/F-Droid ..."
  ( cd "$SRC_DIR" && bash vendor/partner_gms/vendorsetup.sh ) \
    || die "Gagal mengunduh APK microG (cek koneksi internet)."

  # (2) sertakan paket microG ke product (gms.mk = GmsCore, GsfProxy, FakeStore, F-Droid, repo microG)
  local mk="$SRC_DIR/device/samsung/ms013g/lineage_ms013g.mk"
  if grep -q 'partner_gms/products/gms' "$mk" 2>/dev/null; then
    log "microG: paket sudah di-inherit di lineage_ms013g.mk"
  else
    log "microG: menambah inherit gms.mk ke lineage_ms013g.mk"
    cat >> "$mk" <<'EOF'

# --- microG via vendor/partner_gms (ditambahkan oleh build.sh) ---
$(call inherit-product-if-exists, vendor/partner_gms/products/gms.mk)
EOF
  fi
  export WITH_GMS=true

  # (3) signature spoofing:
  if [ "$MICROG_UNRESTRICTED" != "1" ]; then
    log "microG: signature spoofing pakai mekanisme RESTRICTED bawaan LOS 18.1 (tanpa patch)."
    log "microG: microG asli PRESIGNED -> isMicrogSigned() lolos otomatis. Self-check akan ✓."
    warn "microG aktif (restricted). Tree device 'dirty' (inherit gms.mk). Sebelum 'repo sync' berikutnya:"
    warn "  (cd $SRC_DIR/device/samsung/ms013g && git checkout -- lineage_ms013g.mk)"
    return
  fi

  log "microG: MICROG_UNRESTRICTED=1 -> patch frameworks/base (spoofing GENERIK untuk semua app)."
  local patchfile; patchfile="$(mktemp)"
  curl -fsSL "$MICROG_PATCH_URL" -o "$patchfile" || die "Gagal mengunduh patch signature spoofing."
  (
    cd "$SRC_DIR/frameworks/base"
    if git apply --reverse --check "$patchfile" >/dev/null 2>&1; then
      log "microG: patch generik sudah terpasang, lewati."
    elif git apply --check "$patchfile" >/dev/null 2>&1; then
      git apply "$patchfile" && log "microG: patch generik DIPASANG."
    else
      warn "microG: 'git apply' bersih gagal — coba 'patch -p1 --forward' ..."
      patch -p1 --forward < "$patchfile" >/dev/null 2>&1 \
        && log "microG: patch terpasang via patch(1)." \
        || warn "microG: patch GAGAL — cek konflik di frameworks/base (mungkin api/current.txt)."
    fi
  )
  rm -f "$patchfile"
  warn "microG aktif (unrestricted). Tree frameworks/base & device 'dirty'. Sebelum 'repo sync' berikutnya:"
  warn "  (cd $SRC_DIR/frameworks/base && git checkout .)"
  warn "  (cd $SRC_DIR/device/samsung/ms013g && git checkout -- lineage_ms013g.mk)"
}

# ---- 3. build --------------------------------------------------------------
do_build() {
  [ -d "$SRC_DIR/.repo" ] || die "Source belum di-init di $SRC_DIR. Jalankan: ./build.sh sync"
  cd "$SRC_DIR"

  export USE_CCACHE=1
  export CCACHE_EXEC="$(command -v ccache || true)"
  [ -n "${CCACHE_EXEC:-}" ] && ccache -M "${CCACHE_SIZE:-30G}" >/dev/null 2>&1 || warn "ccache tidak terpasang (build lebih lambat)."

  [ "$ENABLE_GO" = "1" ] && enable_go
  [ "$WITH_MICROG" = "1" ] && enable_microg

  # Android build env (envsetup/lunch/mka) TIDAK kompatibel dengan 'set -eu':
  # envsetup.sh mereferensikan $ZSH_VERSION dkk yang unbound di bash.
  # Matikan sementara, nyalakan lagi setelah build.
  log "source build/envsetup.sh"
  set +eu
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
  local rc=$?
  set -eu
  [ "$rc" -eq 0 ] || die "Build gagal (mka keluar dengan kode $rc) — cek log di atas."

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
