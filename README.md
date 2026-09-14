# pyodide tools

Browser-based utilities that run entirely client-side — no server, no upload, no install. Built on [Pyodide](https://pyodide.org/) so the Python logic runs directly in your browser via WebAssembly.

---

## Tools

### [pdf-strip](pdf-strip.html)

PDFs carry hidden metadata you didn't put there — your name, when you created it, which software you used, sometimes your organisation. This tool quietly removes all of it before you share the file: the `/Info` dictionary, the XMP metadata stream, everything. Drop a PDF, click strip, download the clean copy. Nothing is uploaded; everything happens in your browser via `pypdf`.

**Shortcuts**

| Key | Action |
|---|---|
| `Ctrl+Shift+S` | Toggle plain / technical view |
| `Esc` | Reset |

---

### [sanitise-ascii](sanitise-ascii.html)

Paste text from Word, Google Docs, Notion, or ChatGPT and it silently brings along curly quotes, em-dashes, non-breaking spaces, and other Unicode characters that break scripts, linters, and pipelines — and can quietly fingerprint which app or device you used to write something. This tool replaces the 40+ common offenders with their ASCII equivalents. Runs entirely in your browser via Pyodide (Python stdlib only, no packages).

**Shortcuts**

| Key | Action |
|---|---|
| `Ctrl+Shift+S` | Toggle plain / technical view |
| `Esc` | Reset |

---

## Development

```bash
make serve        # start local server and open in browser (port 8008)
make stop         # stop the background server
make release      # copy HTML files to dist/
make deploy       # deploy to S3  (add S3_OPT_PREFIX=staging/ for non-prod)
```

### Adding a new app

Add one entry to `APPS` in the [Makefile](Makefile):

```make
APPS := \
  sanitise-ascii.html|sanitise|y \
  pdf-strip.html|pdfstrip|y \
  my-new-tool.html|mytool|y      # ← html file | s3 subpath | index alias (y/n)
```

That's it — `release` and `deploy` pick it up automatically.

## Stack

- [Pyodide](https://pyodide.org/) — CPython compiled to WebAssembly
- [pypdf](https://pypdf.readthedocs.io/) — pure-Python PDF reader/writer (pdf-strip)
- Python stdlib — no packages for sanitise-ascii
- Zero runtime dependencies beyond the Pyodide CDN bundle
