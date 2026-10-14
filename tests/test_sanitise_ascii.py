import pytest
from sanitise_ascii import EURO_SIGN, fix_comment_box_dashes, is_emoji, process_text, sanitise

LDQUO = chr(0x201C)
RDQUO = chr(0x201D)
LSQUO = chr(0x2018)
RSQUO = chr(0x2019)
EM_DASH = chr(0x2014)
BOX = chr(0x2500)
DOUBLE_BOX = chr(0x2550)
TREE_BRANCH = chr(0x251C)
E_ACUTE = chr(0xE9)
ZWSP = chr(0x200B)
BOM = chr(0xFEFF)
GRIN = chr(0x1F600)
SMART = f"{LDQUO}quoted{RDQUO} {LSQUO}single{RSQUO}"
TREE_LINE = f"# {TREE_BRANCH}{BOX}{BOX} file"


def test_smart_quotes_replaced() -> None:
    text, fixes, remaining = sanitise(SMART)
    assert text == "\"quoted\" 'single'"
    assert len(fixes) == 4
    assert remaining == []


def test_em_dash_becomes_double_hyphen() -> None:
    assert sanitise(f"a {EM_DASH} b")[0] == "a -- b"


def test_ascii_text_is_untouched() -> None:
    text = "plain\r\ntext\n\n"
    assert sanitise(text) == (text, [], [])


def test_line_numbers_refer_to_input_even_after_earlier_fixes() -> None:
    # Regression: line numbers were computed on already-modified text.
    text = f"one\n{EM_DASH}\n{E_ACUTE}\n"
    _, fixes, remaining = sanitise(text)
    assert fixes == [(2, EM_DASH, "--")]
    assert remaining[0][0] == 3


def test_box_dash_fix_reports_real_line_number() -> None:
    # Regression: box-dash fixes used to be reported as line 0.
    _, fixes, _ = sanitise(f"x = 1\n# {BOX * 5}\n")
    assert fixes == [(2, BOX, "-")]


def test_comment_box_dashes_keep_run_length() -> None:
    line, count = fix_comment_box_dashes(f"# {BOX * 4} title")
    assert (line, count) == ("# ---- title", 1)


def test_tree_lines_use_generic_map() -> None:
    line, count = fix_comment_box_dashes(TREE_LINE)
    assert (line, count) == (TREE_LINE, 0)


def test_double_line_box_outside_comments_becomes_equals() -> None:
    assert sanitise(DOUBLE_BOX * 2)[0] == "=="


def test_unknown_character_is_reported_with_context() -> None:
    _, fixes, remaining = sanitise(f"caf{E_ACUTE} au lait")
    assert fixes == []
    assert remaining == [(1, E_ACUTE, 0xE9, f"caf{E_ACUTE} au lait")]


def test_euro_sign_passes_through_silently() -> None:
    text, fixes, remaining = sanitise(f"cost {EURO_SIGN}5")
    assert text == f"cost {EURO_SIGN}5"
    assert fixes == [] and remaining == []


@pytest.mark.parametrize("allow, expected", [(True, 0), (False, 1)])
def test_emoji_reported_unless_allowed(allow: bool, expected: int) -> None:
    _, _, remaining = sanitise(f"ok {GRIN}", allow_emoji=allow)
    assert len(remaining) == expected


def test_is_emoji_boundaries() -> None:
    assert is_emoji(chr(0x2600)) and is_emoji(chr(0x27BF)) and is_emoji(chr(0x1FAFF))
    assert not is_emoji(chr(0x25FF)) and not is_emoji("a")


def test_zero_width_and_bom_removed() -> None:
    assert sanitise(f"a{ZWSP}b{BOM}c")[0] == "abc"


def test_process_text_summary_shape() -> None:
    result = process_text(f"a {EM_DASH} b {EM_DASH} c\n{E_ACUTE}")
    assert result["fixed_text"] == f"a -- b -- c\n{E_ACUTE}"
    assert result["fixes"] == [f":1: U+2014 ({EM_DASH!r}) -> '--' x2"]
    assert result["n_fixes"] == 2
    assert result["n_warnings"] == 1
    assert result["clean"] is False
    assert result["warnings"][0].startswith(":2: U+00E9")


def test_process_text_clean_when_fully_fixed() -> None:
    result = process_text(SMART)
    assert result["clean"] is True
    assert result["warnings"] == []
