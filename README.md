# pyodide tools

Browser-based utilities that run entirely client-side: no server, no upload, no analytics. The Python logic runs in
your browser via [Pyodide](https://pyodide.org/) (CPython compiled to WebAssembly), and the same Python modules are
unit tested under normal CPython.

## Tools

### [pdf-strip](pdf-strip.html)

PDFs carry hidden metadata you did not put there: your name, when you created it, which software you used, sometimes
your organisation. Drop a PDF, click strip, download the clean copy.

Removed: the `/Info` dictionary, document and object level XMP streams, `/PieceInfo`, `/LastModified`, annotation
authors and dates (form field names are kept), and the original trailer `/ID`. Orphaned objects are dropped as well,
because simply deleting a key leaves the old data sitting unreferenced in the file.

Not removed: embedded file attachments (the tool reports them) and EXIF inside embedded images. Check the result with
the "check metadata" button before sharing anything sensitive.

### [sanitise-ascii](sanitise-ascii.html)

Text pasted from Word, Google Docs, Notion or ChatGPT brings curly quotes, em dashes, non-breaking spaces and other
Unicode characters that break scripts and linters, and can reveal which app or device you used. This tool replaces
the 40+ common offenders with ASCII equivalents and reports anything it does not know how to fix. The euro sign is
deliberately passed through untouched.

Both tools share these shortcuts:

| Key | Action |
|---|---|
| `Ctrl+Shift+S` | Toggle plain / technical view |
| `Esc` | Reset (inside a text box it only leaves the box) |

## Layout

```
pdf-strip.html, sanitise-ascii.html   the pages
pyodide-index.html                    domain splash page (not part of the deployed apps)
py/                                   Python modules loaded into Pyodide and imported by the tests
js/                                   shared page behaviour (theme, shortcuts, Pyodide loading)
css/                                  shared theme
tests/                                pytest suite
```

## Development

```bash
make install      # uv sync and enable the Conventional Commits hook
make check        # ruff, mypy and pytest
make serve        # local server on http://127.0.0.1:8008 (port via PORT=...)
make stop         # stop the background server
make release      # run checks, then copy pages and assets to dist/
make deploy       # release, then upload to S3 (S3_OPT_PREFIX=staging/ for non-prod)
```

The pages use ES modules, so open them through `make serve` rather than from `file://`.

### Adding a new app

Add one entry to `APPS` in the [Makefile](Makefile) (`html file:s3 subpath:index alias y/n`):

```make
APPS := \
  sanitise-ascii.html:sanitise:y \
  pdf-strip.html:pdfstrip:y \
  my-new-tool.html:mytool:y
```

`release` and `deploy` pick it up. Put its Python in `py/` and its tests in `tests/`.

## Privacy and supply chain

- No analytics, cookies or web fonts.
- Pyodide is loaded from jsDelivr with a Subresource Integrity hash, so a tampered file is refused.
- pdf-strip installs `pypdf` from PyPI at load time, pinned to one version (`PYPDF_VERSION` in the page; keep it in
  step with `uv.lock`). After loading, nothing else touches the network.

## Stack

- [Pyodide](https://pyodide.org/) 0.26.2
- [pypdf](https://pypdf.readthedocs.io/) (pdf-strip); sanitise-ascii uses only the standard library
- `uv`, `pytest`, `ruff` and `mypy` for development
