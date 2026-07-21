# LineageOS 18.1 — Samsung Galaxy Grand 2 Duos (SM-G7102 / `ms013g`)

Manifest, skrip build, dan tutorial untuk mengompilasi **LineageOS 18.1** dari sumber untuk **Samsung Galaxy Grand 2 Duos** — codename **`ms013g`**.

> Sumber device/kernel/vendor tree: [github.com/Grand-2-Rebirth](https://github.com/Grand-2-Rebirth)

| | |
|---|---|
| **Device** | Samsung Galaxy Grand 2 Duos |
| **Model** | SM-G7102 |
| **Codename** | `ms013g` |
| **Chipset** | Qualcomm Snapdragon 400 (MSM8226) |
| **CPU / RAM** | Quad Cortex-A7 1.4 GHz · 1.5 GB |
| **lunch** | `lineage_ms013g-userdebug` |

---

## ⚡ Cara cepat

```bash
# 1. clone repo ini
git clone https://github.com/rigaz29/lineageos-18.1-ms013g.git
cd lineageos-18.1-ms013g

# 2. jalankan build (sync + compile)
SRC_DIR=~/android/lineage ./build.sh                    # sync + build
ENABLE_GO=1 ./build.sh                                   # + optimasi Android Go
WITH_MICROG=1 ENABLE_GO=1 ./build.sh                     # + microG + Go (rekomendasi)
```

Skrip `build.sh` akan: `repo init` LineageOS 18.1 → memasang `ms013g.xml` sebagai `local_manifest` → `repo sync` → `lunch` → `mka bacon`.

---

## 📂 Isi repo

| File | Fungsi |
|---|---|
| `ms013g.xml` | `local_manifest` — 11 repo device/kernel/vendor/microG + branch terverifikasi |
| `build.sh` | Otomatisasi sync + build (`sync` \| `build` \| `all`, env `ENABLE_GO`, `WITH_MICROG`, `JOBS`, `CLEAN`) |
| `tutorial.html` | Tutorial visual lengkap (langkah 1–6, troubleshooting) |

---

## 🧩 Matriks dependensi (terverifikasi)

| Repository | Path | Branch |
|---|---|---|
| `android_device_samsung_ms013g` | `device/samsung/ms013g` | `lineage-18.1` |
| `android_device_samsung_ms01-common_los18.1` | `device/samsung/ms01-common` | `lineage-18.1` |
| `android_device_samsung_msm8226-common` | `device/samsung/msm8226-common` | `lineage-18.1` |
| `android_device_samsung_qcom-common` | `device/samsung/qcom-common` | `lineage-18.1` |
| `android_kernel_samsung_msm8226` | `kernel/samsung/msm8226` | **`Rebirth`** |
| `android_hardware_samsung` | `hardware/samsung` | `lineage-18.1` |
| `android_hardware_sony_timekeep` *(LineageOS)* | `hardware/sony/timekeep` | `lineage-18.1` |
| `android_vendor_samsung_ms013g` | `vendor/samsung/ms013g` | `lineage-18.1` |
| `android_vendor_samsung_ms01-common` | `vendor/samsung/ms01-common` | `lineage-18.1` |
| `android_vendor_samsung_msm8226-common` | `vendor/samsung/msm8226-common` | **`lineage-18.0`** |
| `lineageos4microg/android_vendor_partner_gms` | `vendor/partner_gms` | `master` |

### Catatan penting

- **Kernel harus branch `Rebirth`.** Tidak ada branch `lineage-18.1` di repo kernel; hanya `Rebirth` yang memuat `lineage_ms013g_defconfig` (dipakai `TARGET_KERNEL_CONFIG`).
- **Common tree** ada di repo bernama `..._los18.1` tetapi **dipetakan ke path `device/samsung/ms01-common`**.
- Vendor `msm8226-common` tertinggi hanya sampai `lineage-18.0` — blob forward-compatible, normal.

### Soal branch "Go"

Branch `lineage-18.1-Go` pada common tree ternyata **snapshot lama** (ahead 0, behind 15 vs `lineage-18.1`) dan **tidak** memuat konfigurasi Android Go asli (`ro.config.low_ram` / `go_defaults`). Karena itu manifest ini memakai `lineage-18.1`. Perilaku Go/low-RAM diaktifkan terpisah lewat `ENABLE_GO=1 ./build.sh`.

---

## 🔐 microG (opsional — `WITH_MICROG=1`)

Integrasi microG memakai repo modern **[`android_vendor_partner_gms`](https://github.com/lineageos4microg/android_vendor_partner_gms)** (pengganti `prebuiltapks` yang sudah deprecated). Aktivasi via `WITH_MICROG=1` menjalankan 3 langkah otomatis di `build.sh`:

1. **Unduh APK** microG (`GmsCore`, `GsfProxy`, `FakeStore`), `F-Droid` + Privileged Extension, dan repo microG F-Droid. APK **tidak** disimpan di git — di-download saat build oleh `vendorsetup.sh`, jadi **butuh koneksi internet** saat aktivasi.
2. **Sertakan paket** — inherit `vendor/partner_gms/products/gms.mk` ke `lineage_ms013g.mk` (mekanisme `WITH_GMS` LOS 18.1 lewat file opsional yang tak ada di base, jadi inherit langsung lebih andal).

```bash
WITH_MICROG=1 ./build.sh build
```

### Signature spoofing — sudah bawaan LOS 18.1 (tanpa patch)

LineageOS 18.1 **sudah** memuat signature spoofing versi **restricted** di `frameworks/base` (di-merge LineageOS sendiri). `PackageManagerService.java` punya `MICROG_REAL_SIGNATURE` + `isMicrogSigned()` + `generateFakeSignature()` yang hanya mengizinkan **microG asli** (yang `PRESIGNED`) memalsukan diri jadi **signature Google saja**. Karena `GmsCore/Android.mk` memakai `LOCAL_CERTIFICATE := PRESIGNED`, signature microG dipertahankan → **spoofing jalan otomatis, tanpa patch**.

Patch `frameworks/base` [`android_frameworks_base-R.patch`](https://github.com/lineageos4microg/docker-lineage-cicd/tree/master/src/signature_spoofing_patches) hanya menambah mekanisme **unrestricted** (app apa pun boleh spoof signature apa pun) — sebuah pelemahan keamanan yang **tidak diperlukan** untuk microG. Aktifkan hanya jika perlu:

```bash
WITH_MICROG=1 MICROG_UNRESTRICTED=1 ./build.sh build   # spoofing generik (jarang perlu)
```

| | Restricted (default, bawaan) | Unrestricted (`MICROG_UNRESTRICTED=1`) |
|---|---|---|
| Yang boleh spoof | hanya microG asli | app apa pun (dgn permission) |
| Target spoof | hanya signature Google | signature apa pun |
| Patch `frameworks/base` | tidak | ya |

> **Verifikasi setelah flash:** buka app **microG Settings → Self-Check**. Baris *"System grants signature spoofing"* harus ✓. Lalu login akun Google & aktifkan *Cloud Messaging* untuk push notification.

> ⚠️ Patch membuat `frameworks/base` menjadi *dirty*. Sebelum `repo sync` berikutnya: `(cd frameworks/base && git checkout .)`. Skrip mendeteksi patch yang sudah terpasang (idempotent).

---

## 🛠️ Prasyarat build host

Ubuntu 20.04/22.04 64-bit, RAM ≥ 8 GB (16 GB ideal), disk kosong ± 200 GB, tool `repo`. Detail dependensi `apt` ada di `tutorial.html` / langkah 1.

---

## 📥 Flash

1. Unlock bootloader + pasang recovery (TWRP / Lineage Recovery) via **Odin** (mode Download: `Vol Down + Home + Power`).
2. Boot recovery → Wipe (system, data, cache, dalvik).
3. `adb sideload lineage-18.1-*-UNOFFICIAL-ms013g.zip`

---

## Lisensi

Skrip & manifest di repo ini bebas dipakai/diadaptasi. Device/kernel/vendor tree mengikuti lisensi masing-masing di [Grand-2-Rebirth](https://github.com/Grand-2-Rebirth) dan [LineageOS](https://github.com/LineageOS).
