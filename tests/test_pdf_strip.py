import io

import pytest
from pdf_strip import (
    EMBEDDED_FILES_WARNING,
    check_metadata,
    has_embedded_files,
    inspect_pdf,
    make_xmp_stream,
    strip_metadata,
)
from pypdf import PdfReader, PdfWriter
from pypdf.errors import PyPdfError
from pypdf.generic import ArrayObject, DictionaryObject, FloatObject, NameObject, TextStringObject

AUTHOR = "Jane Doe"
REVIEWER = "Reviewer Bob"
PRIVATE = "secret-app-data"
XMP_PACKET = (
    '<?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?>'
    '<x:xmpmeta xmlns:x="adobe:ns:meta/">'
    '<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">'
    '<rdf:Description rdf:about="" xmlns:dc="http://purl.org/dc/elements/1.1/" '
    'xmlns:xmp="http://ns.adobe.com/xap/1.0/">'
    f"<dc:creator><rdf:Seq><rdf:li>{AUTHOR}</rdf:li></rdf:Seq></dc:creator>"
    "<xmp:CreatorTool>Word</xmp:CreatorTool>"
    "</rdf:Description></rdf:RDF></x:xmpmeta>"
    '<?xpacket end="w"?>'
)


def to_bytes(writer: PdfWriter) -> bytes:
    out = io.BytesIO()
    writer.write(out)
    return out.getvalue()


def blank() -> tuple[PdfWriter, DictionaryObject]:
    writer = PdfWriter()
    return writer, writer.add_blank_page(200, 200)


@pytest.fixture
def dirty_pdf() -> bytes:
    writer, page = blank()
    writer.add_metadata({"/Author": AUTHOR, "/Producer": "Word"})
    writer.root_object[NameObject("/Metadata")] = writer._add_object(make_xmp_stream(XMP_PACKET))
    page[NameObject("/PieceInfo")] = DictionaryObject({NameObject("/App"): TextStringObject(PRIVATE)})
    note = DictionaryObject(
        {
            NameObject("/Type"): NameObject("/Annot"),
            NameObject("/Subtype"): NameObject("/Text"),
            NameObject("/Rect"): ArrayObject([FloatObject(0), FloatObject(0), FloatObject(10), FloatObject(10)]),
            NameObject("/T"): TextStringObject(REVIEWER),
        }
    )
    page[NameObject("/Annots")] = ArrayObject([writer._add_object(note)])
    return to_bytes(writer)


def test_blank_pdf_reports_only_the_writer_producer() -> None:
    writer, _ = blank()
    assert check_metadata(to_bytes(writer)) == {"/Producer": "pypdf"}


def test_check_finds_info_xmp_pieceinfo_and_annotation_author(dirty_pdf: bytes) -> None:
    found = check_metadata(dirty_pdf)
    assert found["/Author"] == AUTHOR
    assert found["/Producer"] == "Word"
    assert "XMP:xmp_creator_tool" in found
    assert any(AUTHOR in value for key, value in found.items() if key.startswith("XMP:"))
    assert found["Annotation p1"] == REVIEWER
    assert "PieceInfo p1" in found


def test_strip_leaves_nothing_to_report(dirty_pdf: bytes) -> None:
    assert check_metadata(strip_metadata(dirty_pdf)) == {}


@pytest.mark.parametrize("needle", [AUTHOR, REVIEWER, PRIVATE, "Word", "/Info", "/Metadata"])
def test_strip_removes_data_from_raw_bytes(dirty_pdf: bytes, needle: str) -> None:
    # Regression: deleting keys alone left the old XMP stream behind as an orphaned object.
    assert needle.encode() not in strip_metadata(dirty_pdf)


def test_strip_keeps_pages_and_stays_readable(dirty_pdf: bytes) -> None:
    reader = PdfReader(io.BytesIO(strip_metadata(dirty_pdf)))
    assert len(reader.pages) == 1
    assert [float(v) for v in reader.pages[0].mediabox] == [0.0, 0.0, 200.0, 200.0]


def test_strip_is_idempotent(dirty_pdf: bytes) -> None:
    once = strip_metadata(dirty_pdf)
    assert check_metadata(strip_metadata(once)) == {}


def test_widget_field_names_survive() -> None:
    writer, page = blank()
    widget = DictionaryObject(
        {
            NameObject("/Type"): NameObject("/Annot"),
            NameObject("/Subtype"): NameObject("/Widget"),
            NameObject("/Rect"): ArrayObject([FloatObject(0), FloatObject(0), FloatObject(10), FloatObject(10)]),
            NameObject("/T"): TextStringObject("emailfield"),
        }
    )
    ref = writer._add_object(widget)
    page[NameObject("/Annots")] = ArrayObject([ref])
    writer.root_object[NameObject("/AcroForm")] = DictionaryObject({NameObject("/Fields"): ArrayObject([ref])})
    assert b"emailfield" in strip_metadata(to_bytes(writer))


def test_embedded_files_detected() -> None:
    writer, _ = blank()
    assert not has_embedded_files(PdfReader(io.BytesIO(to_bytes(writer))))
    writer.add_attachment("a.txt", b"hello")
    assert has_embedded_files(PdfReader(io.BytesIO(to_bytes(writer))))


def test_invalid_input_raises() -> None:
    with pytest.raises(PyPdfError):
        check_metadata(b"not a pdf")


def test_inspect_pdf_combines_metadata_and_notes(dirty_pdf: bytes) -> None:
    report = inspect_pdf(dirty_pdf)
    assert report["metadata"] == check_metadata(dirty_pdf)
    assert report["notes"] == []


def test_inspect_pdf_warns_about_embedded_files() -> None:
    writer, _ = blank()
    writer.add_attachment("a.txt", b"hello")
    assert inspect_pdf(to_bytes(writer))["notes"] == [EMBEDDED_FILES_WARNING]
