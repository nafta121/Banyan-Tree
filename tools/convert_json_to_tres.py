#!/usr/bin/env python3
"""Deterministic one-time converter from legacy web JSON data to Godot 4 .tres Resources.

Generates:
  - godot/resources/locales/id.tres (LocalePackData)
  - godot/resources/locales/en.tres (LocalePackData)
  - godot/resources/catalog.tres    (GameCatalogData with embedded typed SubResources)
"""

from __future__ import annotations

import html
import json
import os
import re
import sys
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent.parent
DATA_LANG_DIR = REPO_ROOT / "data" / "language"
EN_DIR = DATA_LANG_DIR / "english"
ID_DIR = DATA_LANG_DIR / "indonesian"
MUSIC_JSON = REPO_ROOT / "audio" / "music.json"
OUT_RES_DIR = REPO_ROOT / "godot" / "resources"
OUT_LOCALE_DIR = OUT_RES_DIR / "locales"

ALERT_MSG_RE = re.compile(r"^([A-Z0-9\s.&'/\-]{2,45}):\s*['\"](.+?)['\"]\s*<br><br>([\s\S]+)$")
LEGACY_SPEECH_NOTE_RE = re.compile(
    r'<br><br><font color="#0000FF"><b>Your speech tonight grants[\s\S]*?</b></font>',
    re.IGNORECASE,
)

# Exact 21 § color codes from js/localization.js:14-37
SECTION_CODE_TO_TOKEN: dict[str, str] = {
    "D": "__STAT_POP__",
    "M": "__STAT_REF__",
    "E": "__STAT_ECON__",
    "T": "__STAT_INTL__",
    "A": "__STAT_STAB__",
    "L": "__STAT_MIL__",
    "C": "__STAT_CENDANA__",
    "B": "__STAT_PC__",
    "R": "__CLR_DARK_RED__",
    "G": "__CLR_DARK_GREEN__",
    "g": "__CLR_GREEN__",
    "N": "__CLR_NAVY__",
    "Y": "__CLR_GOLD__",
    "O": "__CLR_ORANGE_RED__",
    "W": "__CLR_WARM_ORANGE__",
    "F": "__CLR_FIREBRICK__",
    "I": "__CLR_INFO_BLUE__",
    "P": "__CLR_CRIMSON__",
    "X": "__CLR_BRIGHT_RED__",
    "K": "__CLR_INK__",
    "S": "__CLR_MUTED__",
}

FONT_HEX_TO_TOKEN: dict[str, str] = {
    "#d81b60": "__STAT_POP__",
    "#8e24aa": "__STAT_REF__",
    "#1b7837": "__STAT_ECON__",
    "#00838f": "__STAT_INTL__",
    "#37474f": "__STAT_STAB__",
    "#556b2f": "__STAT_MIL__",
    "#704d00": "__STAT_CENDANA__",
    "#0000ff": "__STAT_PC__",
    "#8b0000": "__CLR_DARK_RED__",
    "#006400": "__CLR_DARK_GREEN__",
    "#009000": "__CLR_GREEN__",
    "#000080": "__CLR_NAVY__",
    "#b8860b": "__CLR_GOLD__",
    "#ff4500": "__CLR_ORANGE_RED__",
    "#ff5f15": "__CLR_WARM_ORANGE__",
    "#b22222": "__CLR_FIREBRICK__",
    "#004c97": "__CLR_INFO_BLUE__",
    "#c0392b": "__CLR_CRIMSON__",
    "#ff0000": "__CLR_BRIGHT_RED__",
    "#000000": "__CLR_INK__",
    "#555555": "__CLR_MUTED__",
    "#9e1f14": "__FAC_PDIP__",
    "#7d6000": "__FAC_GOLKAR_A__",
    "#8a5a00": "__FAC_GOLKAR_H__",
    "#004488": "__FAC_AXIS__",
    "#005500": "__FAC_PKB__",
    "#1e6840": "__FAC_PPP__",
    "#006068": "__FAC_OTHER__",
    "#3e5022": "__FAC_ABRI__",
    "#4682b4": "__TIER_STEEL__",
    "#2f4f4f": "__TIER_SLATE__",
    "#ff8c00": "__TIER_ORANGE__",
}

INITIAL_PORTRAIT_FACTIONS: list[str] = [
    "pdip",
    "golkar_akbar",
    "golkar_habibie",
    "poros_tengah",
    "abri",
    "ppp",
    "pkb",
    "utusan_daerah",
    "utusan_golongan",
    "other_parties",
]

FACTION_LEVERAGE_METRICS: dict[str, list[str]] = {
    "pdip": ["pop", "ref"],
    "golkar_akbar": ["econ", "stab", "cendana"],
    "golkar_habibie": ["ref", "econ", "intl"],
    "poros_tengah": ["ref", "pop"],
    "ppp": ["stab", "pop"],
    "pkb": ["pop", "ref"],
    "abri": ["mil", "stab"],
    "utusan_daerah": ["econ", "stab"],
    "utusan_golongan": ["ref", "intl"],
    "other_parties": ["pop", "stab"],
}

GOLKAR_PILLAR_BY_DECREE: dict[str, str] = {
    "abolish_kodam_territorial": "a",
    "civil_service_neutrality": "b",
    "anti_corruption": "g",
}

LIBRARY_CATEGORY_MAP: dict[str, str] = {
    "all": "all",
    "persons": "persons",
    "presidents": "presidents",
    "institutions": "institutions",
    "laws & decrees": "laws_decrees",
    "laws_decrees": "laws_decrees",
    "parties & factions": "parties_factions",
    "parties_factions": "parties_factions",
    "military & security": "military_security",
    "military_security": "military_security",
    "economy & kkn": "economy_kkn",
    "economy_kkn": "economy_kkn",
    "society & movements": "society_movements",
    "society_movements": "society_movements",
    "political terms": "political_terms",
    "political_terms": "political_terms",
}

PORTRAIT_RENAME_MAP: dict[str, str] = {
    "photo/library/persons/amien_rais.png": "photo/library/persons/rais.jpg",
    "photo/library/persons/akbar_tandjung.png": "photo/library/persons/tandjung.jpg",
    "photo/library/persons/hamzah_haz.png": "photo/library/persons/haz.jpg",
    "photo/library/persons/adi_sasono.png": "photo/library/persons/sasono.jpg",
    "photo/library/persons/gus_dur.png": "photo/library/persons/gusdur.jpg",
    "photo/library/persons/ghalib_baramuli.png": "photo/library/persons/ghalib.jpg",
}

# Exact 24 SSS cards from js/sss.js:68-115
SSS_CARDS_SPEC: list[dict[str, Any]] = [
    {"id": "pc", "group": "run", "col": 0, "row": 0, "prereqs": [], "n": 50.0, "h": 20.0, "m": 8.0, "target_field": "pc"},
    {"id": "passive", "group": "run", "col": 1, "row": 0, "prereqs": ["pc"], "n": 1.0, "h": 0.0, "m": -1.2, "target_field": "passive_pc_mod"},
    {"id": "cost", "group": "run", "col": 2, "row": 0, "prereqs": ["passive", "s_intl"], "n": 0.0, "h": 1.0, "m": 2.33, "target_field": "custom", "is_custom": True},
    {"id": "cooldown", "group": "run", "col": 3, "row": 0, "prereqs": ["cost", "s_pop"], "n": 0.0, "h": 1.0, "m": 2.2, "target_field": "cooldown_bonus"},
    {"id": "malus", "group": "run", "col": 4, "row": 0, "prereqs": ["cooldown"], "n": 0.35, "h": 3.25, "m": 4.85, "target_field": "malus_cap"},
    {"id": "bad", "group": "politics", "col": 5, "row": 0, "prereqs": ["malus", "good"], "n": 1.0, "h": 1.1, "m": 1.33, "target_field": "event_neg_mult"},
    {"id": "s_econ", "group": "start", "col": 0, "row": 1, "prereqs": [], "n": 5.0, "h": -1.0, "m": -7.0, "start_stat_key": "econ", "start_stat_base": 20, "target_field": "start_mod"},
    {"id": "s_intl", "group": "start", "col": 1, "row": 1, "prereqs": ["pc", "s_econ"], "n": 5.0, "h": -1.0, "m": -7.0, "start_stat_key": "intl", "start_stat_base": 30, "target_field": "start_mod"},
    {"id": "s_pop", "group": "start", "col": 2, "row": 1, "prereqs": ["passive", "s_intl"], "n": 5.0, "h": -1.0, "m": -7.0, "start_stat_key": "pop", "start_stat_base": 30, "target_field": "start_mod"},
    {"id": "s_ref", "group": "start", "col": 3, "row": 1, "prereqs": ["s_pop", "regen"], "n": 5.0, "h": -1.0, "m": -7.0, "start_stat_key": "ref", "start_stat_base": 40, "target_field": "start_mod"},
    {"id": "good", "group": "politics", "col": 4, "row": 1, "prereqs": ["cooldown", "s_ref"], "n": 1.0, "h": 0.95, "m": 0.78, "target_field": "event_pos_mult"},
    {"id": "erosion", "group": "politics", "col": 5, "row": 1, "prereqs": ["good", "favor"], "n": 0.0, "h": 0.4, "m": 1.04, "target_field": "faction_drift"},
    {"id": "s_cendana", "group": "start", "col": 0, "row": 2, "prereqs": [], "n": 60.0, "h": 95.0, "m": 98.0, "target_field": "cendana"},
    {"id": "s_goodwill", "group": "start", "col": 1, "row": 2, "prereqs": ["s_econ", "s_cendana"], "n": 5.0, "h": -1.0, "m": -7.0, "target_field": "affinity_mod"},
    {"id": "regen", "group": "politics", "col": 2, "row": 2, "prereqs": ["s_goodwill", "s_mil"], "n": 0.0, "h": 1.0, "m": 2.16, "target_field": "cendana_regen"},
    {"id": "yield", "group": "politics", "col": 3, "row": 2, "prereqs": ["s_pop", "regen"], "n": 1.0, "h": 0.95, "m": 0.75, "target_field": "gain_mult"},
    {"id": "favor", "group": "politics", "col": 4, "row": 2, "prereqs": ["yield", "pdip"], "n": 3.0, "h": 2.0, "m": 0.8, "target_field": "max_favor"},
    {"id": "defect", "group": "opposition", "col": 5, "row": 2, "prereqs": ["favor", "chaos"], "n": 1.0, "h": 1.3, "m": 1.82, "target_field": "defection_mult"},
    {"id": "s_stab", "group": "start", "col": 0, "row": 3, "prereqs": [], "n": 5.0, "h": -1.0, "m": -7.0, "start_stat_key": "stab", "start_stat_base": 25, "target_field": "start_mod"},
    {"id": "s_mil", "group": "start", "col": 1, "row": 3, "prereqs": ["s_cendana", "s_stab"], "n": 5.0, "h": -1.0, "m": -7.0, "start_stat_key": "mil", "start_stat_base": 50, "target_field": "start_mod"},
    {"id": "army", "group": "opposition", "col": 2, "row": 3, "prereqs": ["s_goodwill", "s_mil"], "n": 0.6, "h": 1.0, "m": 1.29, "target_field": "scale"},
    {"id": "pdip", "group": "opposition", "col": 3, "row": 3, "prereqs": ["army"], "n": 10.0, "h": 20.0, "m": 50.0, "target_field": "custom", "is_custom": True},
    {"id": "chaos", "group": "opposition", "col": 4, "row": 3, "prereqs": ["yield", "pdip"], "n": 0.0, "h": 1.0, "m": 2.0, "target_field": "custom", "is_custom": True},
    {"id": "military", "group": "opposition", "col": 5, "row": 3, "prereqs": ["chaos"], "n": 0.10, "h": 0.50, "m": 0.75, "target_field": "custom", "is_custom": True},
]


def load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def resolve_asset_path(raw: str | None) -> str:
    if not raw:
        return ""
    rel = raw.strip().lstrip("/")
    if not rel:
        return ""
    if rel in PORTRAIT_RENAME_MAP:
        rel = PORTRAIT_RENAME_MAP[rel]
    full = REPO_ROOT / rel
    if full.is_file():
        return f"res://{rel}"
    parent = full.parent
    if parent.is_dir():
        target_lower = full.name.lower()
        stem_lower = full.stem.lower()
        entries = sorted(os.listdir(parent))
        for entry in entries:
            if entry.endswith(".import"):
                continue
            if entry.lower() == target_lower:
                return f"res://{(parent / entry).relative_to(REPO_ROOT).as_posix()}"
        for ext in (".jpg", ".jpeg", ".png", ".webp"):
            for entry in entries:
                if entry.endswith(".import"):
                    continue
                if entry.lower() == stem_lower + ext:
                    return f"res://{(parent / entry).relative_to(REPO_ROOT).as_posix()}"
    return ""


def classify_press_outlet(outlet: str) -> str:
    s = outlet.upper().strip()
    if "DETIK" in s:
        return "browser"
    if "RAKYAT MERDEKA" in s or "POS KOTA" in s:
        return "tabloid"
    if "TEMPO" in s or "FORUM" in s or "GAMMA" in s or "PANJI" in s:
        return "magazine"
    if (
        "BISNIS INDONESIA" in s
        or "KONTAN" in s
        or "FINANCIAL TIMES" in s
        or "WALL STREET" in s
        or "BLOOMBERG" in s
    ):
        return "financial"
    if (
        "FAR EASTERN" in s
        or "SYDNEY MORNING" in s
        or "REUTERS" in s
        or "NEW YORK TIMES" in s
        or "STRAITS TIMES" in s
    ):
        return "international"
    return "broadsheet"


def _unescape_text_segment(seg: str) -> str:
    if "&" not in seg:
        return seg
    return html.unescape(seg).replace("\u00a0", " ")


def _close_top_color(stack: list[str]) -> str:
    for idx in range(len(stack) - 1, -1, -1):
        if stack[idx].startswith("color="):
            closed: list[str] = []
            reopen: list[str] = []
            while len(stack) > idx:
                popped = stack.pop()
                closed.append("[/color]" if popped.startswith("color=") else f"[/{popped}]")
                if len(stack) > idx:
                    reopen.insert(0, popped)
            for tag in reopen:
                stack.append(tag)
                closed.append(f"[{tag}]")
            return "".join(closed)
    return ""


def _close_until_tag(stack: list[str], target: str) -> str:
    for idx in range(len(stack) - 1, -1, -1):
        if stack[idx] == target:
            closed: list[str] = []
            reopen: list[str] = []
            while len(stack) > idx:
                popped = stack.pop()
                closed.append("[/color]" if popped.startswith("color=") else f"[/{popped}]")
                if len(stack) > idx:
                    reopen.insert(0, popped)
            for tag in reopen:
                stack.append(tag)
                closed.append(f"[{tag}]")
            return "".join(closed)
    return ""


def sanitize_to_bbcode(raw: str) -> str:
    if not raw:
        return ""
    s = raw.replace("\r\n", "\n").replace("\r", "\n")
    # Pre-fix known upstream markup typos before tokenizing
    s = re.sub(r"<br\s*<br>", "<br><br>", s, flags=re.IGNORECASE)
    s = re.sub(r"([a-z0-9])\.(<b>|<i>|<font)", r"\1. \2", s, flags=re.IGNORECASE)
    s = re.sub(r"<b>§([A-Za-z])([^§]*?)§</b>", r"<b>§\1\2§!</b>", s)

    # Structural HTML -> BBCode / newlines
    s = re.sub(
        r"<a\s+href=['\"]([^'\"]+)['\"][^>]*>([\s\S]*?)</a>",
        r"[url=\1]\2[/url]",
        s,
        flags=re.IGNORECASE,
    )
    s = re.sub(r"<img[^>]*>", "", s, flags=re.IGNORECASE)
    s = re.sub(r"<p\s*>\s*</p\s*>", "\n\n", s, flags=re.IGNORECASE)
    s = re.sub(r"<p[^>]*>", "", s, flags=re.IGNORECASE)
    s = re.sub(r"</p\s*>", "\n\n", s, flags=re.IGNORECASE)
    s = re.sub(r"<br\s*/?>", "\n", s, flags=re.IGNORECASE)
    s = re.sub(r"<hr\s*/?>", "\n────────────────────\n", s, flags=re.IGNORECASE)
    s = re.sub(r"</?ul[^>]*>", "\n", s, flags=re.IGNORECASE)
    s = re.sub(r"<li[^>]*>", "\n• ", s, flags=re.IGNORECASE)
    s = re.sub(r"</li\s*>", "", s, flags=re.IGNORECASE)
    s = re.sub(r"</?(center|div|span)[^>]*>", "", s, flags=re.IGNORECASE)

    out_parts: list[str] = []
    text_buf: list[str] = []
    stack: list[str] = []

    def flush_text() -> None:
        if text_buf:
            out_parts.append(_unescape_text_segment("".join(text_buf)))
            text_buf.clear()

    i = 0
    n = len(s)
    while i < n:
        ch = s[i]
        if ch == "§":
            flush_text()
            if i + 1 < n:
                code = s[i + 1]
                if code == "!":
                    out_parts.append(_close_top_color(stack))
                    i += 2
                    continue
                if code in SECTION_CODE_TO_TOKEN:
                    tok = SECTION_CODE_TO_TOKEN[code]
                    stack.append(f"color={tok}")
                    out_parts.append(f"[color={tok}]")
                    i += 2
                    continue
            out_parts.append(_close_top_color(stack))
            i += 1
            continue
        if ch == "<":
            close_idx = s.find(">", i)
            if close_idx != -1:
                tag_body = s[i + 1 : close_idx].strip()
                lower_body = tag_body.lower()
                if lower_body in ("b", "strong"):
                    flush_text()
                    if "b" not in stack:
                        stack.append("b")
                        out_parts.append("[b]")
                    i = close_idx + 1
                    continue
                if lower_body in ("/b", "/strong"):
                    flush_text()
                    out_parts.append(_close_until_tag(stack, "b"))
                    i = close_idx + 1
                    continue
                if lower_body in ("i", "em"):
                    flush_text()
                    if "i" not in stack:
                        stack.append("i")
                        out_parts.append("[i]")
                    i = close_idx + 1
                    continue
                if lower_body in ("/i", "/em"):
                    flush_text()
                    out_parts.append(_close_until_tag(stack, "i"))
                    i = close_idx + 1
                    continue
                if lower_body == "u":
                    flush_text()
                    if "u" not in stack:
                        stack.append("u")
                        out_parts.append("[u]")
                    i = close_idx + 1
                    continue
                if lower_body == "/u":
                    flush_text()
                    out_parts.append(_close_until_tag(stack, "u"))
                    i = close_idx + 1
                    continue
                if lower_body.startswith("font"):
                    flush_text()
                    m_col = re.search(r"color\s*=\s*['\"]?(#[0-9a-fA-F]{6})['\"]?", tag_body)
                    hex_code = m_col.group(1).lower() if m_col else "#000000"
                    tok = FONT_HEX_TO_TOKEN.get(hex_code, "__CLR_INK__")
                    stack.append(f"color={tok}")
                    out_parts.append(f"[color={tok}]")
                    i = close_idx + 1
                    continue
                if lower_body == "/font":
                    flush_text()
                    out_parts.append(_close_top_color(stack))
                    i = close_idx + 1
                    continue
        text_buf.append(ch)
        i += 1

    flush_text()
    while stack:
        top = stack.pop()
        out_parts.append("[/color]" if top.startswith("color=") else f"[/{top}]")

    res = "".join(out_parts)
    res = re.sub(r"\n[ \t]+\n", "\n\n", res)
    res = re.sub(r"\n{3,}", "\n\n", res)
    res = res.strip("\n")
    return res


def flatten_dict(obj: dict[str, Any], prefix: str, out: dict[str, str]) -> None:
    for k, v in (obj or {}).items():
        if k.startswith("_"):
            continue
        key = f"{prefix}.{k}" if prefix else k
        if isinstance(v, dict):
            flatten_dict(v, key, out)
        elif isinstance(v, list):
            out[key] = sanitize_to_bbcode("".join(str(x) for x in v))
        else:
            out[key] = sanitize_to_bbcode(str(v))


def adapt_tutorial_page(lang: str, idx: int, raw_text: str) -> str:
    txt = raw_text
    if lang == "en":
        if idx == 0:
            txt = txt.replace(
                'Metrics and factions are shown as descriptive tiers and stances, not numbers. Only <font color="#0000FF"><b>Political Capital</b></font> is a number.',
                'By default, metrics and factions are shown as qualitative tiers and stances (only <font color="#0000FF"><b>Political Capital</b></font> and MPR seat counts are numbers). Anytime in Settings, you can toggle <font color="#000080"><b>Show Exact Numbers (0–100)</b></font> for precise bars, floors, and post-choice deltas.',
            )
        elif idx == 1:
            txt = txt.replace(
                "Press <font color=\"#000080\"><b>CONCLUDE AGENDA</b></font> to end the turn.",
                "All option cards and action filters sit in the lower thumb zone for effortless one-handed portrait play. Tap <font color=\"#000080\"><b>CONCLUDE AGENDA</b></font> to end the turn.",
            )
        elif idx == 2:
            txt = txt.replace(
                "Seven metrics are on the left panel.",
                "Seven metrics are on the <font color=\"#000080\"><b>Stat</b></font> tab at the bottom navigation bar for comfortable one-handed portrait access.",
            )
        elif idx == 5:
            txt = txt.replace(
                'Your campaign is saved automatically. Use <font color="#000080"><b>Continue Game</b></font> to resume.',
                'Your campaign autosaves after every decision, and <font color="#000080"><b>5 manual save slots</b></font> (with backup export/import) are available in the <font color="#000080"><b>More (≡)</b></font> tab without disabling achievements.',
            )
    else:
        if idx == 0:
            txt = txt.replace(
                'Statistik dan fraksi ditampilkan sebagai tingkatan dan sikap deskriptif, bukan angka. Hanya <font color="#0000FF"><b>Modal Politik</b></font> yang ditampilkan dalam bentuk angka.',
                'Secara bawaan, statistik dan fraksi ditampilkan sebagai tingkatan kualitatif (hanya <font color="#0000FF"><b>Modal Politik</b></font> dan kursi MPR berupa angka). Kapan saja di Pengaturan, Anda dapat mengaktifkan sakelar <font color="#000080"><b>Tampilkan Angka Eksak (0–100)</b></font> untuk melihat angka presisi, batas lantai dekrit, dan delta perubahan.',
            )
        elif idx == 1:
            txt = txt.replace(
                "Tekan <font color=\"#000080\"><b>AKHIRI AGENDA</b></font> untuk mengakhiri giliran.",
                "Seluruh kartu pilihan dan filter tindakan ditempatkan di paruh bawah layar portrait agar nyaman dimainkan satu tangan. Ketuk <font color=\"#000080\"><b>AKHIRI AGENDA</b></font> untuk mengakhiri giliran.",
            )
        elif idx == 2:
            txt = txt.replace(
                "Tujuh indikator statistik terdapat di panel sebelah kiri.",
                "Tujuh indikator statistik tersedia pada tab <font color=\"#000080\"><b>Stat</b></font> di bilah navigasi bawah yang mudah dijangkau satu tangan.",
            )
        elif idx == 5:
            txt = txt.replace(
                'Kampanye Anda disimpan secara otomatis. Gunakan <font color="#000080"><b>Lanjutkan Permainan</b></font> untuk melanjutkan.',
                'Kampanye Anda disimpan otomatis setiap tindakan, serta tersedia <font color="#000080"><b>5 slot simpan/muat manual</b></font> (beserta ekspor/impor cadangan) pada tab <font color="#000080"><b>Lainnya (≡)</b></font> tanpa memblokir pencapaian.',
            )
    return sanitize_to_bbcode(txt)


def compute_music_weighted_tags(title: str, genre: str, raw_wt: str) -> list[str]:
    if raw_wt == "loworder":
        return ["loworder_highreform", "loworder_lowreform"]
    if raw_wt == "highorder":
        return ["highorder_highreform", "highorder_lowreform"]
    if raw_wt in (
        "highorder_highreform",
        "highorder_lowreform",
        "loworder_highreform",
        "loworder_lowreform",
    ):
        return [raw_wt]
    # Upstream bugfix: assign appropriate quadrants for the 6 previously untagged tracks
    t_low = title.lower()
    if "serdadu" in t_low:
        return ["loworder_lowreform", "loworder_highreform"]
    if "beyond" in t_low or "海闊天空" in title:
        return ["loworder_highreform", "highorder_highreform"]
    if "rule the world" in t_low:
        return ["loworder_lowreform", "highorder_lowreform"]
    if "teresa teng" in t_low or "漫步人生路" in title:
        return ["highorder_lowreform", "highorder_highreform"]
    return ["highorder_highreform", "highorder_lowreform"]


def format_faction_names(raw_name: str) -> tuple[str, str]:
    clean = re.sub(r"<br\s*/?>", " ", raw_name, flags=re.IGNORECASE)
    clean = re.sub(r"\s+", " ", clean).strip()
    if re.search(r"<br\s*/?>", raw_name, flags=re.IGNORECASE):
        portrait = sanitize_to_bbcode(raw_name)
    else:
        portrait = re.sub(r"\s+\(", "\n(", clean, count=1)
    return sanitize_to_bbcode(clean), portrait


# ---- Godot 4 format=3 .tres Serializer ----

class SubResRef:
    def __init__(self, sub_id: str) -> None:
        self.sub_id = sub_id


class TypedResArray:
    def __init__(self, ext_id: str, items: list[SubResRef]) -> None:
        self.ext_id = ext_id
        self.items = items


class TypedDictArray:
    def __init__(self, items: list[dict[str, Any]]) -> None:
        self.items = items


class PackedStrArray:
    def __init__(self, items: list[str]) -> None:
        self.items = items


def tres_str(s: str) -> str:
    escaped = (
        s.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\t", "\\t")
    )
    return f'"{escaped}"'


def tres_val(v: Any) -> str:
    if v is None:
        return "null"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        s = repr(round(v, 6))
        if "." not in s and "e" not in s.lower():
            s += ".0"
        return s
    if isinstance(v, str):
        return tres_str(v)
    if isinstance(v, SubResRef):
        return f'SubResource("{v.sub_id}")'
    if isinstance(v, PackedStrArray):
        inner = ", ".join(tres_str(x) for x in v.items)
        return f"PackedStringArray({inner})"
    if isinstance(v, TypedResArray):
        inner = ", ".join(tres_val(x) for x in v.items)
        return f'Array[ExtResource("{v.ext_id}")]([{inner}])'
    if isinstance(v, TypedDictArray):
        inner = ", ".join(tres_val(x) for x in v.items)
        return f"Array[Dictionary]([{inner}])"
    if isinstance(v, list):
        inner = ", ".join(tres_val(x) for x in v)
        return f"[{inner}]"
    if isinstance(v, dict):
        if not v:
            return "{}"
        pairs = [f"{tres_str(str(k))}: {tres_val(val)}" for k, val in v.items()]
        return "{\n" + ",\n".join(f"\t{p}" for p in pairs) + "\n}"
    raise TypeError(f"Unsupported .tres value type: {type(v)}")


def write_tres_file(
    out_path: Path,
    script_class: str,
    root_ext_id: str,
    ext_resources: list[tuple[str, str]],
    sub_resources: list[tuple[str, str, list[tuple[str, Any]]]],
    root_props: list[tuple[str, Any]],
) -> None:
    load_steps = 1 + len(ext_resources) + len(sub_resources)
    lines: list[str] = [
        f'[gd_resource type="Resource" script_class="{script_class}" load_steps={load_steps} format=3]',
        "",
    ]
    for ext_id, res_path in ext_resources:
        lines.append(f'[ext_resource type="Script" path="{res_path}" id="{ext_id}"]')
    lines.append("")

    for sub_id, sub_ext_id, props in sub_resources:
        lines.append(f'[sub_resource type="Resource" id="{sub_id}"]')
        lines.append(f'script = ExtResource("{sub_ext_id}")')
        for pk, pv in props:
            lines.append(f"{pk} = {tres_val(pv)}")
        lines.append("")

    lines.append("[resource]")
    lines.append(f'script = ExtResource("{root_ext_id}")')
    for pk, pv in root_props:
        lines.append(f"{pk} = {tres_val(pv)}")
    lines.append("")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("\n".join(lines), encoding="utf-8")


def validate_bbcode_dict(locale_code: str, strings: dict[str, str]) -> None:
    forbidden_substrings = ("§", "<br", "<font", "<b>", "</b>", "<i>", "</i>", "<div", "<p>", "</p>", "<ul", "<li")
    for k, v in strings.items():
        for bad in forbidden_substrings:
            if bad in v:
                raise ValueError(f"[{locale_code}] Uncleaned markup {bad!r} in key {k}: {v[:120]!r}")
        for tag in ("b", "i", "u"):
            if v.count(f"[{tag}]") != v.count(f"[/{tag}]"):
                raise ValueError(f"[{locale_code}] Unbalanced [{tag}] tag in key {k}: {v[:120]!r}")
        if v.count("[color=") != v.count("[/color]"):
            raise ValueError(f"[{locale_code}] Unbalanced [color=] tag in key {k}: {v[:120]!r}")


def main() -> int:
    manifest = load_json(DATA_LANG_DIR / "languages.json")
    loading_raw = load_json(EN_DIR / "interface" / "loading_messages.json")
    en_loading = [sanitize_to_bbcode(s) for s in loading_raw["messages"]["en"]]
    id_loading = [sanitize_to_bbcode(s) for s in loading_raw["messages"]["id"]]
    assert len(en_loading) == 11 and len(id_loading) == 11, "Expected 11+11 loading messages"

    en_strings: dict[str, str] = {}
    id_strings: dict[str, str] = {}

    for rel_file in manifest["files"]:
        if rel_file == "interface/loading_messages.json":
            continue
        en_file = EN_DIR / rel_file
        id_file = ID_DIR / rel_file
        if en_file.exists():
            flatten_dict(load_json(en_file), "", en_strings)
        if id_file.exists():
            flatten_dict(load_json(id_file), "", id_strings)

    # Enrich English Golkar pillar effects with semantic color highlights matching Indonesian
    en_strings["faction.golkar_pillars.abri.effect"] = sanitize_to_bbcode(
        "While it stands, §YGolkar§! resists your influence permanently. Every gain with a Golkar bloc is cut by <b>§R$RESIST$%§!</b>."
    )
    en_strings["faction.golkar_pillars.birokrasi.effect"] = sanitize_to_bbcode(
        "While it stands, the bureaucracy slow-walks your orders. You earn <b>§R$PCMALUS$%§!</b> less <b>§BPolitical Capital§!</b> from every source."
    )
    en_strings["faction.golkar_pillars.golkar.effect"] = sanitize_to_bbcode(
        "While it stands, the party machine keeps propping up the Cendana network. <b>§CCendana Influence§!</b> creeps back up by <b>§R$DRIFT$§!</b> at the end of every turn."
    )

    # Alias Golkar pillars a/b/g <-> abri/birokrasi/golkar in both locales
    for short_id, full_id in (("a", "abri"), ("b", "birokrasi"), ("g", "golkar")):
        for field in ("name", "desc", "effect"):
            en_strings[f"faction.golkar_pillars.{short_id}.{field}"] = en_strings[
                f"faction.golkar_pillars.{full_id}.{field}"
            ]
            id_strings[f"faction.golkar_pillars.{short_id}.{field}"] = id_strings[
                f"faction.golkar_pillars.{full_id}.{field}"
            ]

    def put_both(key: str, en_raw: str, id_raw: str, clean: bool = True) -> None:
        en_strings[key] = sanitize_to_bbcode(en_raw) if clean else en_raw
        id_strings[key] = sanitize_to_bbcode(id_raw) if clean else id_raw

    def resolve_or_store(key: str, en_val: str, id_val: str) -> str:
        # If the JSON field is already an existing dictionary key (e.g. "tier.pop.tolerated"), keep it!
        if en_val in en_strings and id_val in id_strings and en_val == id_val:
            return en_val
        put_both(key, en_val, id_val)
        return key

    sub_resources: list[tuple[str, str, list[tuple[str, Any]]]] = []

    EXT_IDS = {
        "GameCatalogData": "1_catalog",
        "CrisisEventData": "2_event",
        "EventOptionData": "3_evopt",
        "RoutineActionData": "4_routine",
        "DecreeData": "5_decree",
        "FactionData": "6_faction",
        "FactionDealData": "7_deal",
        "FactionMergedData": "8_merged",
        "DifficultyData": "9_diff",
        "SSSCardData": "10_sss",
        "LibraryEntryData": "11_lib",
        "AchievementData": "12_ach",
        "MusicTrackData": "13_music",
        "StatTierData": "14_tier",
    }

    EXT_PATHS = [
        ("1_catalog", "res://godot/scripts/resources/game_catalog_data.gd"),
        ("2_event", "res://godot/scripts/resources/crisis_event_data.gd"),
        ("3_evopt", "res://godot/scripts/resources/event_option_data.gd"),
        ("4_routine", "res://godot/scripts/resources/routine_action_data.gd"),
        ("5_decree", "res://godot/scripts/resources/decree_data.gd"),
        ("6_faction", "res://godot/scripts/resources/faction_data.gd"),
        ("7_deal", "res://godot/scripts/resources/faction_deal_data.gd"),
        ("8_merged", "res://godot/scripts/resources/faction_merged_data.gd"),
        ("9_diff", "res://godot/scripts/resources/difficulty_data.gd"),
        ("10_sss", "res://godot/scripts/resources/sss_card_data.gd"),
        ("11_lib", "res://godot/scripts/resources/library_entry_data.gd"),
        ("12_ach", "res://godot/scripts/resources/achievement_data.gd"),
        ("13_music", "res://godot/scripts/resources/music_track_data.gd"),
        ("14_tier", "res://godot/scripts/resources/stat_tier_data.gd"),
    ]

    # 1. Events (23) & Options (111)
    ev_en_list = load_json(EN_DIR / "events.json")
    ev_id_list = load_json(ID_DIR / "events.json")
    event_refs: list[SubResRef] = []
    speech_turn = 21
    axis_turn = 18
    total_event_turns = len(ev_en_list)
    last_action_turn = max(1, total_event_turns - 1)

    for idx, (ee, ei) in enumerate(zip(ev_en_list, ev_id_list)):
        turn_num = idx + 1
        ev_id = ee["id"]
        if ev_id == "ev_the_speech":
            speech_turn = turn_num
        elif ev_id == "ev_central_axis":
            axis_turn = turn_num

        date_key = f"event.{ev_id}.date"
        title_key = f"event.{ev_id}.title"
        desc_key = f"event.{ev_id}.desc"
        en_desc_clean = LEGACY_SPEECH_NOTE_RE.sub("", ee.get("desc", ""))
        id_desc_clean = LEGACY_SPEECH_NOTE_RE.sub("", ei.get("desc", ""))
        put_both(date_key, ee["date"], ei["date"])
        put_both(title_key, ee["title"], ei["title"])
        put_both(desc_key, en_desc_clean, id_desc_clean)

        opt_refs: list[SubResRef] = []
        for o_idx, (oe, oi) in enumerate(zip(ee["options"], ei["options"])):
            opt_text_key = f"event.{ev_id}.opt.{o_idx}.text"
            put_both(opt_text_key, oe["text"], oi["text"])

            me = ALERT_MSG_RE.match(oe["reaction"].strip())
            mi = ALERT_MSG_RE.match(oi["reaction"].strip())
            if not me or not mi:
                raise ValueError(f"Failed to split alertMsg on {ev_id} option {o_idx}")

            outlet = me.group(1).strip()
            press_cat = classify_press_outlet(outlet)
            hl_key = f"event.{ev_id}.opt.{o_idx}.headline"
            body_key = f"event.{ev_id}.opt.{o_idx}.body"
            put_both(hl_key, me.group(2).strip(), mi.group(2).strip())
            put_both(body_key, me.group(3).strip(), mi.group(3).strip())

            opt_sub_id = f"EventOption_{ev_id}_{o_idx}"
            sub_resources.append(
                (
                    opt_sub_id,
                    EXT_IDS["EventOptionData"],
                    [
                        ("option_index", o_idx),
                        ("text_key", opt_text_key),
                        ("effects", oe.get("effects", {})),
                        ("press_outlet", outlet),
                        ("press_category", press_cat),
                        ("press_headline_key", hl_key),
                        ("press_body_key", body_key),
                    ],
                )
            )
            opt_refs.append(SubResRef(opt_sub_id))

        ev_sub_id = f"CrisisEvent_{ev_id}"
        sub_resources.append(
            (
                ev_sub_id,
                EXT_IDS["CrisisEventData"],
                [
                    ("id", ev_id),
                    ("turn_number", turn_num),
                    ("date_key", date_key),
                    ("title_key", title_key),
                    ("desc_key", desc_key),
                    ("image_path", resolve_asset_path(ee.get("image", ""))),
                    ("options", TypedResArray(EXT_IDS["EventOptionData"], opt_refs)),
                ],
            )
        )
        event_refs.append(SubResRef(ev_sub_id))

    # 2. Routines (36)
    rout_en_list = load_json(EN_DIR / "actionphase" / "routine.json")
    rout_id_list = load_json(ID_DIR / "actionphase" / "routine.json")
    routine_refs: list[SubResRef] = []

    for re_item, ri_item in zip(rout_en_list, rout_id_list):
        rid = re_item["id"]
        t_key = f"routine.{rid}.text"
        sn_key = f"routine.{rid}.short_name"
        d_key = f"routine.{rid}.desc"
        put_both(t_key, re_item["text"], ri_item["text"])
        put_both(sn_key, re_item.get("short_name", re_item["text"]), ri_item.get("short_name", ri_item["text"]))
        put_both(d_key, re_item["description"], ri_item["description"])

        alert_key = ""
        if re_item.get("alertMsg"):
            alert_key = f"routine.{rid}.alert"
            put_both(alert_key, re_item["alertMsg"], ri_item.get("alertMsg", re_item["alertMsg"]))

        succ_key = ""
        fail_key = ""
        if isinstance(re_item.get("alertMsgs"), dict):
            succ_key = f"routine.{rid}.alert_success"
            fail_key = f"routine.{rid}.alert_failure"
            put_both(succ_key, re_item["alertMsgs"]["success"], ri_item["alertMsgs"]["success"])
            put_both(fail_key, re_item["alertMsgs"]["failure"], ri_item["alertMsgs"]["failure"])

        cond_branches: list[dict[str, Any]] = []
        en_conds = re_item.get("conditionalEffects", [])
        id_conds = ri_item.get("conditionalEffects", [])
        for c_idx, (ce, ci) in enumerate(zip(en_conds, id_conds)):
            c_alert_key = ""
            if ce.get("alertMsg"):
                c_alert_key = f"routine.{rid}.cond.{c_idx}.alert"
                put_both(c_alert_key, ce["alertMsg"], ci.get("alertMsg", ce["alertMsg"]))
            cond_branches.append(
                {
                    "stat": ce["condition"]["stat"],
                    "operator": ce["condition"]["operator"],
                    "value": int(ce["condition"]["value"]),
                    "effects": ce.get("effects", {}),
                    "alert_key": c_alert_key,
                }
            )

        r_sub_id = f"Routine_{rid}"
        sub_resources.append(
            (
                r_sub_id,
                EXT_IDS["RoutineActionData"],
                [
                    ("id", rid),
                    ("category", re_item.get("category", "")),
                    ("text_key", t_key),
                    ("short_name_key", sn_key),
                    ("desc_key", d_key),
                    ("alert_msg_key", alert_key),
                    ("success_alert_key", succ_key),
                    ("failure_alert_key", fail_key),
                    ("base_cost", int(re_item.get("baseCost", 0))),
                    ("cooldown", int(re_item.get("cooldown", 2))),
                    ("effects", re_item.get("effects", {})),
                    ("conditional_branches", TypedDictArray(cond_branches)),
                    ("dynamic_pc", re_item.get("dynamicPC", {})),
                    ("dynamic_scaling", re_item.get("dynamicScaling", {})),
                    ("is_military_interaction", rid in ("military", "kostrad_rotation")),
                ],
            )
        )
        routine_refs.append(SubResRef(r_sub_id))

    # 3. Decrees (35)
    dec_en_list = load_json(EN_DIR / "actionphase" / "decrees.json")
    dec_id_list = load_json(ID_DIR / "actionphase" / "decrees.json")
    decree_refs: list[SubResRef] = []

    for de_item, di_item in zip(dec_en_list, dec_id_list):
        did = de_item["id"]
        t_key = f"decree.{did}.text"
        d_key = f"decree.{did}.desc"
        a_key = f"decree.{did}.alert"
        put_both(t_key, de_item["text"], di_item["text"])
        put_both(d_key, de_item["description"], di_item["description"])
        put_both(a_key, de_item.get("alertMsg", ""), di_item.get("alertMsg", ""))

        locks = de_item.get("locks", {})
        max_cend = int(locks["maxCendana"]) if "maxCendana" in locks else -1

        d_sub_id = f"Decree_{did}"
        sub_resources.append(
            (
                d_sub_id,
                EXT_IDS["DecreeData"],
                [
                    ("id", did),
                    ("category", de_item.get("category", "")),
                    ("text_key", t_key),
                    ("desc_key", d_key),
                    ("alert_msg_key", a_key),
                    ("base_cost", int(de_item.get("baseCost", 0))),
                    ("mutex_decrees", PackedStrArray(list(de_item.get("mutexDecrees", [])))),
                    ("req_decree", str(de_item.get("reqDecree", ""))),
                    ("unlock_event", str(de_item.get("unlockEvent", ""))),
                    ("req_golkar_pillars", bool(de_item.get("reqGolkarPillars", False))),
                    ("breaks_golkar_pillar", GOLKAR_PILLAR_BY_DECREE.get(did, "")),
                    ("req_stats", TypedDictArray(list(de_item.get("reqStats", [])))),
                    ("req_factions", TypedDictArray(list(de_item.get("reqFactions", [])))),
                    ("military_shock", int(de_item.get("militaryShock", 0))),
                    ("locks", locks),
                    ("min_stats", locks.get("minStats", {})),
                    ("max_cendana", max_cend),
                    ("min_factions", locks.get("minFactions", {})),
                    ("stat_effects", locks.get("statPenalties", {})),
                    ("faction_effects", locks.get("factionPenalties", {})),
                    ("ban_factions", PackedStrArray(list(de_item.get("banFactions", [])))),
                    ("seat_recipients", de_item.get("seatRecipients", {})),
                    ("seats_vacated", int(de_item.get("seatsVacated", 0))),
                ],
            )
        )
        decree_refs.append(SubResRef(d_sub_id))

    # Helper for Faction moods & deals (matching game.js:676-698 fitInteractions)
    def build_mood_refs(
        prefix_id: str, stat_k: str, en_moods: list[dict[str, Any]], id_moods: list[dict[str, Any]]
    ) -> list[SubResRef]:
        refs: list[SubResRef] = []
        for m_idx, (me_m, mi_m) in enumerate(zip(en_moods, id_moods)):
            mk = resolve_or_store(f"{prefix_id}.mood.{m_idx}", me_m["text"], mi_m["text"])
            hex_c = str(me_m.get("color", "#555555"))
            tok = FONT_HEX_TO_TOKEN.get(hex_c.lower(), "__CLR_MUTED__")
            m_sub = f"Mood_{prefix_id.replace('.', '_')}_{m_idx}"
            sub_resources.append(
                (
                    m_sub,
                    EXT_IDS["StatTierData"],
                    [
                        ("stat_key", stat_k),
                        ("min_value", int(me_m["min"])),
                        ("text_key", mk),
                        ("color_hex", hex_c),
                        ("color_token", tok),
                        ("overlay_rgba", str(me_m.get("overlay", ""))),
                    ],
                )
            )
            refs.append(SubResRef(m_sub))
        return refs

    def build_deal_refs(
        fac_prefix: str, en_deals: list[dict[str, Any]], id_deals: list[dict[str, Any]], merged_bloc: bool
    ) -> list[SubResRef]:
        refs: list[SubResRef] = []
        for de_d, di_d in zip(en_deals, id_deals):
            deal_id = de_d["id"]
            is_final = "final" in deal_id
            min_t = int(de_d.get("minTurn", 0))
            max_t = int(de_d.get("maxTurn", last_action_turn))
            if is_final:
                min_t = speech_turn
                max_t = last_action_turn
            elif merged_bloc:
                min_t = axis_turn
                max_t = last_action_turn
            elif max_t >= 17:
                max_t = last_action_turn
            if min_t > last_action_turn:
                min_t = max(1, last_action_turn - 2)

            dt_key = f"{fac_prefix}.deal.{deal_id}.text"
            dd_key = f"{fac_prefix}.deal.{deal_id}.desc"
            da_key = f"{fac_prefix}.deal.{deal_id}.alert"
            put_both(dt_key, de_d["text"], di_d["text"])
            put_both(dd_key, de_d["description"], di_d["description"])
            put_both(da_key, de_d.get("alertMsg", ""), di_d.get("alertMsg", ""))

            min_stat = de_d.get("minStat") or {}
            deal_sub = f"Deal_{fac_prefix.replace('.', '_')}_{deal_id}"
            sub_resources.append(
                (
                    deal_sub,
                    EXT_IDS["FactionDealData"],
                    [
                        ("id", deal_id),
                        ("text_key", dt_key),
                        ("desc_key", dd_key),
                        ("alert_msg_key", da_key),
                        ("cost", int(de_d.get("cost", 0))),
                        ("repeatable", bool(de_d.get("repeatable", False))),
                        ("is_final_appeal", is_final),
                        ("min_turn", min_t),
                        ("max_turn", max_t),
                        ("min_affinity", int(de_d["minAffinity"]) if "minAffinity" in de_d else -1),
                        ("min_stat_key", str(min_stat.get("key", ""))),
                        ("min_stat_val", int(min_stat["val"]) if "val" in min_stat else -1),
                        ("req_decree", str(de_d.get("reqDecree", ""))),
                        ("mutex_group", str(de_d.get("mutexGroup", ""))),
                        ("locks_group", bool(de_d.get("locksGroup", False))),
                        ("effects", de_d.get("effects", {})),
                    ],
                )
            )
            refs.append(SubResRef(deal_sub))
        return refs

    # 4. Factions (10)
    faction_refs: list[SubResRef] = []
    for fk in INITIAL_PORTRAIT_FACTIONS:
        fe = load_json(EN_DIR / "factions" / f"{fk}.json")
        fi = load_json(ID_DIR / "factions" / f"{fk}.json")

        en_clean_name, en_port_name = format_faction_names(fe["name"])
        id_clean_name, id_port_name = format_faction_names(fi["name"])
        name_key = f"faction.{fk}.name"
        port_name_key = f"faction.{fk}.portrait_name"
        short_key = f"faction.{fk}.short"
        sum_key = f"faction.{fk}.summary"
        bio_key = f"faction.{fk}.biography"

        put_both(name_key, en_clean_name, id_clean_name, clean=False)
        put_both(port_name_key, en_port_name, id_port_name, clean=False)
        put_both(short_key, fe.get("short", en_clean_name), fi.get("short", id_clean_name))
        put_both(sum_key, fe["summary"], fi["summary"])
        put_both(bio_key, fe["biography"], fi["biography"])

        mood_refs = build_mood_refs(f"faction.{fk}", fk, fe["moods"], fi["moods"])
        deal_refs = build_deal_refs(f"faction.{fk}", fe["interactions"], fi["interactions"], merged_bloc=False)

        merged_ref: SubResRef | None = None
        if "transformed" in fe and "transformed" in fi:
            te = fe["transformed"]
            ti = fi["transformed"]
            m_en_clean, m_en_port = format_faction_names(te["name"])
            m_id_clean, m_id_port = format_faction_names(ti["name"])
            m_name_key = f"faction.{fk}.merged.name"
            m_port_key = f"faction.{fk}.merged.portrait_name"
            m_sum_key = f"faction.{fk}.merged.summary"
            m_bio_key = f"faction.{fk}.merged.biography"
            put_both(m_name_key, m_en_clean, m_id_clean, clean=False)
            put_both(m_port_key, m_en_port, m_id_port, clean=False)
            put_both(m_sum_key, te["summary"], ti["summary"])
            put_both(m_bio_key, te["biography"], ti["biography"])

            m_moods = build_mood_refs(f"faction.{fk}.merged", fk, te["moods"], ti["moods"])
            m_deals = build_deal_refs(
                f"faction.{fk}.merged", te["interactions"], ti["interactions"], merged_bloc=True
            )
            merged_sub_id = f"FactionMerged_{fk}"
            sub_resources.append(
                (
                    merged_sub_id,
                    EXT_IDS["FactionMergedData"],
                    [
                        ("name_key", m_name_key),
                        ("portrait_name_key", m_port_key),
                        ("summary_key", m_sum_key),
                        ("biography_key", m_bio_key),
                        ("cover_image_path", resolve_asset_path(te.get("coverImage", ""))),
                        ("seats", int(te["seats"])),
                        ("moods", TypedResArray(EXT_IDS["StatTierData"], m_moods)),
                        ("deals", TypedResArray(EXT_IDS["FactionDealData"], m_deals)),
                    ],
                )
            )
            merged_ref = SubResRef(merged_sub_id)

        f_sub_id = f"Faction_{fk}"
        sub_resources.append(
            (
                f_sub_id,
                EXT_IDS["FactionData"],
                [
                    ("id", fk),
                    ("name_key", name_key),
                    ("portrait_name_key", port_name_key),
                    ("short_key", short_key),
                    ("summary_key", sum_key),
                    ("biography_key", bio_key),
                    ("initial_seats", int(fe["seats"])),
                    ("initial_affinity", int(fe["affinity"])),
                    ("image_path", resolve_asset_path(fe.get("image", ""))),
                    ("cover_image_path", resolve_asset_path(fe.get("coverImage", ""))),
                    ("leverage_metrics", PackedStrArray(FACTION_LEVERAGE_METRICS.get(fk, []))),
                    ("moods", TypedResArray(EXT_IDS["StatTierData"], mood_refs)),
                    ("deals", TypedResArray(EXT_IDS["FactionDealData"], deal_refs)),
                    ("merged_state", merged_ref),
                ],
            )
        )
        faction_refs.append(SubResRef(f_sub_id))

    # 5. Config & Difficulties (5: easy, medium, high, historical, ucn)
    cfg_en = load_json(EN_DIR / "config.json")
    cfg_id = load_json(ID_DIR / "config.json")
    diff_refs: list[SubResRef] = []
    for dk in ("easy", "medium", "high", "historical", "ucn"):
        de_cfg = cfg_en["difficultySettings"][dk]
        di_cfg = cfg_id["difficultySettings"][dk]
        dn_key = f"config.difficulty.{dk}.name"
        dd_key = f"config.difficulty.{dk}.desc"
        if dk == "ucn":
            en_name = en_strings.get("difficulty.ucn.name", "Severe State Situations")
            id_name = id_strings.get("difficulty.ucn.name", "Situasi Darurat Negara")
        else:
            en_name = de_cfg["name"]
            id_name = di_cfg["name"]
        put_both(dn_key, en_name, id_name)
        put_both(dd_key, de_cfg.get("description", ""), di_cfg.get("description", ""))

        stat_mod = int(de_cfg.get("statMod", 0))
        diff_sub = f"Difficulty_{dk}"
        sub_resources.append(
            (
                diff_sub,
                EXT_IDS["DifficultyData"],
                [
                    ("id", dk),
                    ("name_key", dn_key),
                    ("desc_key", dd_key),
                    ("image_path", resolve_asset_path(de_cfg.get("image", ""))),
                    ("pc", int(de_cfg.get("pc", 20))),
                    ("stat_mod", stat_mod),
                    ("affinity_mod", stat_mod),
                    ("start_mods", {}),
                    ("cendana", int(de_cfg.get("cendana", 95))),
                    ("malus_cap", float(de_cfg.get("malusCap", 3.25))),
                    ("passive_pc_mod", int(de_cfg.get("passivePCMod", 0))),
                    ("action_cost_mod", int(de_cfg.get("actionCostMod", 0))),
                    ("cost_pct", int(de_cfg.get("costPct", 0))),
                    ("decree_cost_pct", int(de_cfg.get("decreeCostPct", 0))),
                    ("event_neg_mult", float(de_cfg.get("eventNegMult", 1.0))),
                    ("event_pos_mult", float(de_cfg.get("eventPosMult", 1.0))),
                    ("gain_mult", float(de_cfg.get("gainMult", 1.0))),
                    ("max_favor", int(de_cfg.get("maxFavor", 2))),
                    ("faction_drift", float(de_cfg.get("factionDrift", 0.0))),
                    ("cendana_regen", float(de_cfg.get("cendanaRegen", 0.0))),
                    ("cooldown_bonus", int(de_cfg.get("cooldownBonus", 0))),
                    ("opposition", de_cfg.get("opposition", {})),
                ],
            )
        )
        diff_refs.append(SubResRef(diff_sub))

    # 6. SSS Cards (24)
    sss_refs: list[SubResRef] = []
    for card in SSS_CARDS_SPEC:
        cid = card["id"]
        c_sub = f"SSSCard_{cid}"
        sub_resources.append(
            (
                c_sub,
                EXT_IDS["SSSCardData"],
                [
                    ("id", cid),
                    ("group", card["group"]),
                    ("col", int(card["col"])),
                    ("row", int(card["row"])),
                    ("prereqs", PackedStrArray(list(card["prereqs"]))),
                    ("n", float(card["n"])),
                    ("h", float(card["h"])),
                    ("m", float(card["m"])),
                    ("start_stat_key", str(card.get("start_stat_key", ""))),
                    ("start_stat_base", int(card.get("start_stat_base", 0))),
                    ("target_field", str(card.get("target_field", ""))),
                    ("is_custom", bool(card.get("is_custom", False))),
                    ("name_key", f"ucn.slider.{cid}.name"),
                    ("desc_key", f"ucn.slider.{cid}.desc"),
                    ("value_key", f"ucn.slider.{cid}.value"),
                ],
            )
        )
        sss_refs.append(SubResRef(c_sub))

    # 7. Library Entries (90 library + 14 persons + 8 presidents = 112)
    lib_refs: list[SubResRef] = []
    lib_sources = [
        ("lib", "texts/library.json"),
        ("pers", "texts/persons.json"),
        ("pres", "texts/presidents.json"),
    ]
    for prefix, rel_p in lib_sources:
        le_list = load_json(EN_DIR / rel_p)
        li_list = load_json(ID_DIR / rel_p)
        for l_idx, (le_item, li_item) in enumerate(zip(le_list, li_list)):
            entry_id = f"{prefix}_{l_idx:03d}"
            raw_cat = str(le_item.get("category", "all")).strip().lower()
            norm_cat = LIBRARY_CATEGORY_MAP.get(raw_cat, "all")
            term_k = f"lib.{entry_id}.term"
            sub_k = f"lib.{entry_id}.subtitle"
            desc_k = f"lib.{entry_id}.desc"
            put_both(term_k, le_item.get("term", ""), li_item.get("term", ""))
            put_both(sub_k, le_item.get("subtitle", ""), li_item.get("subtitle", ""))
            put_both(desc_k, le_item.get("desc", ""), li_item.get("desc", ""))

            alt_k = ""
            alt_title_k = ""
            if le_item.get("alt") or li_item.get("alt"):
                alt_k = f"lib.{entry_id}.alt"
                put_both(alt_k, le_item.get("alt", ""), li_item.get("alt", ""))
                alt_title_k = "library.alt_label"

            l_sub = f"Library_{entry_id}"
            sub_resources.append(
                (
                    l_sub,
                    EXT_IDS["LibraryEntryData"],
                    [
                        ("id", entry_id),
                        ("category", norm_cat),
                        ("term_key", term_k),
                        ("subtitle_key", sub_k),
                        ("desc_key", desc_k),
                        ("alt_key", alt_k),
                        ("alt_title_key", alt_title_k),
                        ("image_path", resolve_asset_path(le_item.get("image", ""))),
                    ],
                )
            )
            lib_refs.append(SubResRef(l_sub))

    # 8. Achievements (59)
    ach_en_list = load_json(EN_DIR / "achievements.json")
    ach_id_list = load_json(ID_DIR / "achievements.json")
    ach_refs: list[SubResRef] = []
    for ae, ai in zip(ach_en_list, ach_id_list):
        aid = ae["id"]
        at_k = f"ach.{aid}.title"
        ad_k = f"ach.{aid}.desc"
        put_both(at_k, ae["title"], ai["title"])
        put_both(ad_k, ae["desc"], ai["desc"])
        a_sub = f"Ach_{aid}"
        sub_resources.append(
            (
                a_sub,
                EXT_IDS["AchievementData"],
                [
                    ("id", aid),
                    ("title_key", at_k),
                    ("desc_key", ad_k),
                    ("icon_path", ""),
                ],
            )
        )
        ach_refs.append(SubResRef(a_sub))

    # 9. Music Tracks (36)
    music_raw = load_json(MUSIC_JSON)
    music_refs: list[SubResRef] = []
    for m_idx, mt in enumerate(music_raw):
        raw_wt = str(mt.get("weightedtrack", "")).strip()
        genre = str(mt.get("genre", "pop")).strip() or "pop"
        w_tags = compute_music_weighted_tags(mt["title"], genre, raw_wt)
        m_sub = f"Music_{m_idx:02d}"
        sub_resources.append(
            (
                m_sub,
                EXT_IDS["MusicTrackData"],
                [
                    ("index", m_idx),
                    ("title", sanitize_to_bbcode(mt["title"])),
                    ("file_path", resolve_asset_path(mt["file"])),
                    ("cover_path", resolve_asset_path(mt.get("cover", ""))),
                    ("genre", genre),
                    ("weighted_track", raw_wt),
                    ("weighted_tags", PackedStrArray(w_tags)),
                ],
            )
        )
        music_refs.append(SubResRef(m_sub))

    # 10. Stat Tiers (46 across 7 stats)
    stats_json = load_json(EN_DIR / "stats.json")
    stat_tier_refs: list[SubResRef] = []
    for stat_k, tiers in stats_json.items():
        for t_idx, t_obj in enumerate(tiers):
            tk = resolve_or_store(f"stat_tier.{stat_k}.{t_idx}", t_obj["text"], t_obj["text"])
            hex_c = str(t_obj.get("color", "#555555"))
            tok = FONT_HEX_TO_TOKEN.get(hex_c.lower(), "__CLR_MUTED__")
            st_sub = f"StatTier_{stat_k}_{t_idx}"
            sub_resources.append(
                (
                    st_sub,
                    EXT_IDS["StatTierData"],
                    [
                        ("stat_key", stat_k),
                        ("min_value", int(t_obj["min"])),
                        ("text_key", tk),
                        ("color_hex", hex_c),
                        ("color_token", tok),
                        ("overlay_rgba", ""),
                    ],
                )
            )
            stat_tier_refs.append(SubResRef(st_sub))

    # 11. Tutorial Pages (adapted for portrait one-handed UI & Show Exact Numbers toggle)
    tut_en = load_json(EN_DIR / "texts" / "tutorial.json")
    tut_id = load_json(ID_DIR / "texts" / "tutorial.json")
    for t_idx, (te_p, ti_p) in enumerate(zip(tut_en, tut_id)):
        put_both(f"tutorial.{t_idx}.title", te_p["title"], ti_p["title"])
        en_strings[f"tutorial.{t_idx}.text"] = adapt_tutorial_page("en", t_idx, te_p["text"])
        id_strings[f"tutorial.{t_idx}.text"] = adapt_tutorial_page("id", t_idx, ti_p["text"])

    # 12. Changelog (updates.json) & Credits (texts/credits.json)
    upd_en = load_json(EN_DIR / "updates.json")
    upd_id = load_json(ID_DIR / "updates.json")
    changelog_entries: list[dict[str, Any]] = []
    for u_idx, (ue, ui) in enumerate(zip(upd_en, upd_id)):
        ver = str(ue.get("version", ""))
        dk = f"changelog.{u_idx}.date"
        tk = f"changelog.{u_idx}.title"
        put_both(dk, ue.get("date", ""), ui.get("date", ""))
        put_both(tk, ue.get("title", ""), ui.get("title", ""))
        note_keys: list[str] = []
        en_notes = ue.get("notes", [])
        id_notes = ui.get("notes", [])
        max_notes = max(len(en_notes), len(id_notes))
        for n_idx in range(max_notes):
            nk = f"changelog.{u_idx}.note.{n_idx}"
            en_n = en_notes[n_idx] if n_idx < len(en_notes) else id_notes[n_idx]
            id_n = id_notes[n_idx] if n_idx < len(id_notes) else en_notes[n_idx]
            put_both(nk, en_n, id_n)
            note_keys.append(nk)
        changelog_entries.append(
            {
                "version": ver,
                "date_key": dk,
                "title_key": tk,
                "note_keys": note_keys,
            }
        )

    cred_en = load_json(EN_DIR / "texts" / "credits.json")
    cred_id = load_json(ID_DIR / "texts" / "credits.json")
    for sec_k in ("main", "music", "sfx", "images", "sources"):
        en_sec = "\n\n".join(str(x) for x in cred_en.get(sec_k, []))
        id_sec = "\n\n".join(str(x) for x in cred_id.get(sec_k, []))
        put_both(f"credits.body.{sec_k}", en_sec, id_sec)

    # 13. Ensure 0 missing keys between EN and ID
    en_fallbacks_for_id_only = {
        "faction.burned_note": sanitize_to_bbcode("<i>Relations with this bloc have been permanently severed.</i>"),
        "faction.dulled": sanitize_to_bbcode(" (diminished)"),
        "overlay.burned": "BURNED",
    }
    for k, fb in en_fallbacks_for_id_only.items():
        if k not in en_strings:
            en_strings[k] = fb
    for k, v in en_strings.items():
        if k not in id_strings:
            id_strings[k] = v
    for k, v in id_strings.items():
        if k not in en_strings:
            en_strings[k] = v

    assert set(en_strings.keys()) == set(id_strings.keys()), "Key parity mismatch between EN and ID!"
    validate_bbcode_dict("en", en_strings)
    validate_bbcode_dict("id", id_strings)

    # Sort dictionaries deterministically by key
    en_sorted = {k: en_strings[k] for k in sorted(en_strings.keys())}
    id_sorted = {k: id_strings[k] for k in sorted(id_strings.keys())}

    # Write locales/id.tres & locales/en.tres
    locale_ext = [("1_locpack", "res://godot/scripts/resources/locale_pack_data.gd")]
    write_tres_file(
        OUT_LOCALE_DIR / "id.tres",
        "LocalePackData",
        "1_locpack",
        locale_ext,
        [],
        [
            ("locale_code", "id"),
            ("locale_name", "Bahasa Indonesia"),
            ("strings", id_sorted),
            ("loading_messages", PackedStrArray(id_loading)),
        ],
    )
    write_tres_file(
        OUT_LOCALE_DIR / "en.tres",
        "LocalePackData",
        "1_locpack",
        locale_ext,
        [],
        [
            ("locale_code", "en"),
            ("locale_name", "English"),
            ("strings", en_sorted),
            ("loading_messages", PackedStrArray(en_loading)),
        ],
    )

    golkar_pillars = [
        {"id": "a", "legacy_id": "abri", "letter": "A", "decree": "abolish_kodam_territorial"},
        {"id": "b", "legacy_id": "birokrasi", "letter": "B", "decree": "civil_service_neutrality"},
        {"id": "g", "legacy_id": "golkar", "letter": "G", "decree": "anti_corruption"},
    ]
    golkar_pillar_effects = {
        "abriResistance": 0.15,
        "pcMalus": 0.20,
        "cendanaDrift": 1,
    }
    sfx_paths = {
        "click": "res://audio/sfx/click.wav",
        "blocked": "res://audio/sfx/blocked.wav",
        "notification": "res://audio/sfx/notification.mp3",
        "news": "res://audio/sfx/news.mp3",
        "achievement": "res://audio/sfx/notif2.wav",
    }
    image_paths = {
        "situation": resolve_asset_path(cfg_en.get("situationImage", "")),
        "habibie_cover": resolve_asset_path(cfg_en.get("habibieCoverImage", "")),
        "victory": resolve_asset_path(cfg_en.get("victoryImage", "")),
        "defeat": resolve_asset_path(cfg_en.get("defeatImage", "")),
    }

    write_tres_file(
        OUT_RES_DIR / "catalog.tres",
        "GameCatalogData",
        EXT_IDS["GameCatalogData"],
        EXT_PATHS,
        sub_resources,
        [
            ("events", TypedResArray(EXT_IDS["CrisisEventData"], event_refs)),
            ("routines", TypedResArray(EXT_IDS["RoutineActionData"], routine_refs)),
            ("decrees", TypedResArray(EXT_IDS["DecreeData"], decree_refs)),
            ("factions", TypedResArray(EXT_IDS["FactionData"], faction_refs)),
            ("difficulties", TypedResArray(EXT_IDS["DifficultyData"], diff_refs)),
            ("sss_cards", TypedResArray(EXT_IDS["SSSCardData"], sss_refs)),
            ("library_entries", TypedResArray(EXT_IDS["LibraryEntryData"], lib_refs)),
            ("achievements", TypedResArray(EXT_IDS["AchievementData"], ach_refs)),
            ("music_tracks", TypedResArray(EXT_IDS["MusicTrackData"], music_refs)),
            ("all_stat_tiers", TypedResArray(EXT_IDS["StatTierData"], stat_tier_refs)),
            ("system_modifiers", cfg_en["systemModifiers"]),
            ("golkar_pillars", TypedDictArray(golkar_pillars)),
            ("golkar_pillar_effects", golkar_pillar_effects),
            ("sfx_paths", sfx_paths),
            ("image_paths", image_paths),
            ("tutorial_count", len(tut_en)),
            ("changelog_entries", TypedDictArray(changelog_entries)),
        ],
    )

    print(
        f"[OK] Generated id.tres ({len(id_sorted)} keys, {len(id_loading)} loading msgs), "
        f"en.tres ({len(en_sorted)} keys, {len(en_loading)} loading msgs), and "
        f"catalog.tres ({len(sub_resources)} embedded SubResources, 0 missing keys)."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
