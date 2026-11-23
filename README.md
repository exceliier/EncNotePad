# EncNotePad

<p align="center">
  <img src="https://raw.githubusercontent.com/user/repository/main/assets/icon.png" alt="EncNotePad Logo" width="100" height="100" onerror="this.style.display='none'"/>
</p>

<p align="center">
  <strong>A secure, lightweight, 100% offline structured notes editor with client-side authenticated encryption and on-device shadow copies.</strong>
</p>

<p align="center">
  <a href="#features"><img src="https://img.shields.io/badge/Security-AES--256--GCM-blue.svg" alt="AES-256-GCM"></a>
  <a href="#features"><img src="https://img.shields.io/badge/KDF-Argon2id-green.svg" alt="Argon2id"></a>
  <a href="#privacy--threat-model"><img src="https://img.shields.io/badge/Network-100%25%20Offline-success.svg" alt="Offline"></a>
  <a href="#platforms"><img src="https://img.shields.io/badge/Platform-Windows%20%7C%20Android%20%7C%20iOS-informational.svg" alt="Platforms"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT"></a>
</p>

---

## 📌 Overview

**EncNotePad** is built for developers, security professionals, and privacy-conscious individuals who need to store sensitive records, credentials, and financial notes without trusting remote cloud servers or unencrypted text files.

Unlike standard text editors, EncNotePad:
1. **Enforces Encryption at Rest:** Every document is saved as an authenticated binary blob (`.enp`) using **AES-256-GCM** with **Argon2id** key derivation.
2. **Organizes via Sections & Parts:** Employs a structured card hierarchy instead of a single unstructured flat text file.
3. **Features On-Device Shadow Copies:** Automatically keeps local, encrypted point-in-time snapshots, preventing accidental data loss or file corruption.
4. **Operates 100% Offline:** Zero analytics, zero telemetry, zero network permissions. Air-gap ready.

---

## ✨ Features

* 🔒 **Zero-Knowledge & Air-Gapped:** The application requests no network permissions (`android.permission.INTERNET` is completely omitted). Plaintext data never leaves your device's volatile memory.
* 🛡️ **Military-Grade Cryptography:**
  * **AEAD Cipher:** AES-256-GCM with a fresh, cryptographically secure 96-bit nonce generated on **every save**.
  * **Memory-Hard KDF:** Argon2id (RFC 9106) with 64 MB memory cost and 3 iterations to thwart GPU/ASIC brute-force attacks.
* 🕒 **On-Device Shadow Copies (Version History):**
  * Rolling local snapshots captured on session start, after 15 minutes of editing, or manually (`Ctrl+Shift+B`).
  * In-memory encrypted preview and one-click rollback of the last 15 revisions.
* ⚡ **Crash-Resilient Atomic Auto-Save:**
  * Automatically saves 500ms after you stop typing.
  * Writes to a temporary file (`.enp.tmp`), flushes to disk, and performs an atomic rename, eliminating corruption risk during sudden power loss.
* 📑 **Card-Based Document Hierarchy:**
  * Notes are structured into **Sections** (collapsible categories) containing **Parts** (individual records with title and multi-line body).
* 🔍 **Instant In-Document Search (`Ctrl+F`):** Filter and highlight sections and records in real-time.
* 🌐 **Full Indian Language & Unicode Support:** Native rendering and Input Method Editor (IME) support for Hindi (Devanagari), Tamil, Bengali, Telugu, Gujarati, and emojis.
* ⏳ **Inactivity Auto-Lock & RAM Hygiene:**
  * Locks after 5 minutes of inactivity, clearing session keys and decrypted notes from memory.
  * Direct zeroization (`Uint8List.fillRange`) of cryptographic key material.

---

## 🔐 Cryptographic File Format (`.enp`)

Files saved to disk adhere to a strict, tamper-proof binary specification:

```
+------------------------------------------------------------------------------------+
| Magic Bytes | Version | Salt      | Nonce / IV | Ciphertext           | Auth Tag   |
| 4 bytes     | 1 byte  | 16 bytes  | 12 bytes   | Variable length      | 16 bytes   |
| 'E','N','P','1' | 0x01 | Crypt-Salt| Random IV  | AES-256-GCM Payload  | GCM Tag    |
+------------------------------------------------------------------------------------+
```

* **Header (`ENP1`):** Validates the file signature and protects against opening malformed files.
* **Salt (16 bytes):** Unique cryptographically secure random salt generated on document creation.
* **Nonce (12 bytes):** Unique 96-bit initialization vector generated fresh on every auto-save.
* **Auth Tag (16 bytes):** Verifies document integrity and authenticates the master password. Tampered bytes trigger immediate decryption rejection.

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| `Ctrl + N` / `Cmd + N` | Create a New Encrypted Document |
| `Ctrl + O` / `Cmd + O` | Open Existing `.enp` Document |
| `Ctrl + W` / `Cmd + W` | Close Active Document (Force Save & Lock) |
| `Ctrl + F` / `Cmd + F` | Search within Active Document |
| `Ctrl + Shift + S` | Add New Section |
| `Ctrl + Shift + B` | Create Immediate Local Shadow Copy Snapshot |
| `Ctrl + H` | Open Version History (Shadow Copies Dialog) |
| `Ctrl + L` | Lock Workspace Now |

---

## 🛠️ Architecture & Tech Stack

* **Client Framework:** [Flutter](https://flutter.dev/) (Dart 3.x)
* **Concurrency:** Dedicated **Dart Background Isolates** (`Isolate.run`) for Argon2id key derivation and AES-256-GCM serialization, ensuring the UI remains locked at 60/120 FPS.
* **State Management:** `flutter_bloc`
* **File System:** Native desktop integration via `file_picker` and `window_manager`.

---

## 🚀 Getting Started

### Prerequisites

* [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.19 or later)
* For Windows desktop:
  * Visual Studio 2022 (with **"Desktop development with C++"** workload installed)
* Git

### Building & Running from Source

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/EncNotePad.git
   cd EncNotePad
   ```

2. **Fetch dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run on Windows Desktop:**
   ```bash
   flutter run -d windows
   ```

4. **Execute the automated test suite:**
   ```bash
   flutter test
   ```

5. **Build a Standalone Windows Release:**
   ```bash
   flutter build windows --release
   ```
   The compiled executable will be located in:
   `build/windows/x64/runner/Release/`

6. **Build the Windows MSI Installer Package:**
   Run the automated build script (runs tests, compiles Flutter release, and packages via WiX v4):
   ```cmd
   build_msi.bat
   ```
   Or via PowerShell:
   ```powershell
   .\build_msi.ps1
   ```
   The generated installer will be saved at:
   `EncNotePad-v1.0.0.msi`

---

## 🛡️ Privacy & Threat Model

* **No Backdoors:** There are no master keys, reset links, or cloud recovery options. If you lose your master password, your data is mathematically impossible to recover.
* **No Telemetry:** The application makes zero HTTP/WebSocket connections. It can run on completely air-gapped workstations.
* **Anti-Forensics:** Plaintext notes are never written to disk, OS swap files, or temporary directories. Atomic writes utilize encrypted temporary buffers (`.enp.tmp`).
* **Screen Privacy:** Prevents OS task-switcher thumbnail previews (`FLAG_SECURE` on Android; blur overlay on iOS/Desktop).

---

## 🗺️ Project Roadmap

- [x] **Phase 1: Windows Desktop MVP**
  - [x] Argon2id + AES-256-GCM background isolate engine
  - [x] Card-based hierarchical Section/Part UI
  - [x] Debounced 500ms atomic persistence
  - [x] On-device shadow copies (15-snapshot FIFO rotation and rollback)
  - [x] Inactivity auto-lock and memory hygiene
- [ ] **Phase 2: Mobile Adaptation**
  - [ ] Android & iOS touch-first responsive layouts
  - [ ] Biometric Quick Unlock (Fingerprint / Face ID via OS Keystore/Keychain)
  - [ ] Native file association for `.enp` files
- [ ] **Phase 3: Future Roadmap (On Hold)**
  - [ ] Optional Zero-Knowledge End-to-End Encrypted (E2EE) Cloud Sync
  - [ ] Encrypted image/file attachments within notes
  - [ ] Markdown preview in Part body text

---

## 📄 License

This project is open-source and licensed under the [MIT License](LICENSE).

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request or open an Issue for bug reports, feature requests, or security discussions.
