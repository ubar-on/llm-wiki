# Toolchain by OS

Canonical tools across platforms: Poppler (`pdftotext`/`pdfimages`/`pdftoppm`) for PDFs, `pandoc` for Office formats, npm-based `qmd` and `marp-cli`. Tools are identical across OSes — only install routes and known quirks differ.

---

## Windows

### Canonical install
```
winget install -e --id oschwartz10612.Poppler
winget install -e --id JohnMacFarlane.Pandoc
```
`npm`/`qmd`/`marp` are installed automatically by the SessionStart hook (`scripts/install-deps.sh`).

### Known partial installs
- **Git for Windows ships only `pdftotext`** — no `pdfimages`, no `pdftoppm`. Tier 1+ work requires the full Poppler install above. Pre-flight detects this and emits `POPPLER_PARTIAL=true(GfW)`.
- **Microsoft Store Python stub** silently fails (exit code 49) even when Python is installed via the Store. Pre-flight detects this and routes to the `py` launcher instead.

### Tier-4 optional
```
winget install -e --id ArtifexSoftware.mupdf
```
`mutool` often produces cleaner text than `pdftotext` for dense layouts. Not used by default.

---

## macOS

### Canonical install
```bash
brew install poppler pandoc
```
`npm`/`qmd`/`marp` installed by SessionStart hook.

### Path quirks
- Apple Silicon Homebrew prefix: `/opt/homebrew/bin`. Intel prefix: `/usr/local/bin`. `command -v` handles both.
- Gatekeeper may block first run of brew binaries — user may need to confirm in System Settings → Privacy & Security.

### Tier-4 optional
```bash
brew install mupdf
```

---

## Linux

### Canonical install (Debian/Ubuntu)
```bash
sudo apt install poppler-utils pandoc
```

### Other distros
```bash
# Fedora
sudo dnf install poppler-utils pandoc

# Arch
sudo pacman -S poppler pandoc

# openSUSE
sudo zypper install poppler-tools pandoc
```

### Known issues
- **Snap-installed pandoc** has sandbox restrictions that block reading from arbitrary paths. Use the apt/dnf package, not the snap. Pre-flight detects snap pandoc and warns.

### Tier-4 optional
```bash
sudo apt install mupdf-tools     # alternative PDF text extractor
sudo apt install libreoffice     # higher-fidelity .docx/.pptx layout
```

---

## Capability Tiers

| Tier | Requires | Enables |
|------|----------|---------|
| 0 | `pdftotext` only | Text extraction, TOC parsing, chapter splitting |
| 1 | Tier 0 + `pdfimages` | Image inventory per page |
| 2 | Tier 1 + `pdftoppm` | Page rendering as PNG for diagram description |
| 3 | Tier 2 + `pandoc` | `.docx`, `.epub`, `.pptx` processing |

Pre-flight reports the active tier as `TIER=<N>` in the READY line.
