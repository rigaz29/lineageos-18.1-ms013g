# TWRP untuk Samsung Galaxy Grand 2 Duos (SM-G7102 / `ms013g`)

Build TWRP recovery memakai **[minimal-manifest-twrp](https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp)** (branch `twrp-11`, base Android 11), dengan menarik ulang device/kernel/vendor tree dari [Grand-2-Rebirth](https://github.com/Grand-2-Rebirth).

> Device tree-nya **sudah TWRP-ready**: `twrp.mk` (semua flag `TW_*`), folder `twrp/`, fstab recovery, keymapping — dan `BoardConfigCommon.mk` sudah mewiring `ifeq ($(WITH_TWRP),true)`. Yang ditambahkan repo ini hanya product makefile TWRP yang belum ada.

## ⚡ Cara pakai

```bash
cd twrp
TWRP_DIR=~/twrp ./build_twrp.sh          # sync + build
# atau bertahap:
./build_twrp.sh sync
./build_twrp.sh build
```

Hasil: `~/twrp/out/target/product/ms013g/recovery.img` (~11–16 MB — **muat** di partisi recovery, tidak seperti OrangeFox).

## Isi folder

| File | Fungsi |
|---|---|
| `ms013g_twrp.xml` | local_manifest — device/common/kernel/vendor tree |
| `twrp_ms013g.mk` | product makefile TWRP (bagian yang belum ada di device tree) |
| `AndroidProducts.mk` | mendaftarkan `twrp_ms013g` ke lunch (menimpa yang lineage) |
| `build_twrp.sh` | sync minimal manifest + pasang file + build `recoveryimage` |

## Apa yang dilakukan skrip

1. `repo init` minimal-manifest-twrp `twrp-11` (+ `--depth=1`, ramping).
2. Pasang `ms013g_twrp.xml` sebagai local_manifest, lalu `repo sync`.
3. Salin `twrp_ms013g.mk` + `AndroidProducts.mk` ke `device/samsung/ms013g/` (**setelah** sync, agar tak ketimpa `--force-sync`).
4. `export ALLOW_MISSING_DEPENDENCIES=true WITH_TWRP=true` → `lunch twrp_ms013g-eng` → `mka recoveryimage`.

## Kalau build gagal

- **`device/qcom/sepolicy` / `hardware/qcom/*` not found** → minimal manifest AOSP tak memuat repo qcom. Buka komentar blok **QCOM** di `ms013g_twrp.xml`, lalu `./build_twrp.sh sync` ulang.
- **Image kegedean** (jarang untuk TWRP) → matikan fitur via flag `TW_EXCLUDE_*` di `twrp.mk`.
- **Modul hilang lain** → `ALLOW_MISSING_DEPENDENCIES=true` sudah aktif; kalau masih berhenti, tempel log error-nya.

## Flash

Via **Odin** (Download mode: `Vol Down + Home + Power`) — bungkus `recovery.img` ke `.tar` (`tar -H ustar -c recovery.img > recovery.tar`), flash di slot **AP/PDA**. Atau via **Heimdall**: `heimdall flash --RECOVERY recovery.img`.

## Catatan

`ms013g` = **32-bit** (Cortex-A7), jadi product makefile **tidak** memakai `core_64_bit.mk`. Base `twrp-11` dipilih karena sejajar dengan device tree LineageOS 18.1 (Android 11).
