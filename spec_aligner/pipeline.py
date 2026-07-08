from __future__ import annotations

from . import ingest
from .aligner import align
from .diff_engine import diff
from .nl_extractor import extract as extract_nl
from .report import report_data
from .sysml_extractor import extract as extract_sysml


def compare_pair(nl_text: str, sysml_text: str) -> dict:
    nl_doc = extract_nl(ingest.from_text(nl_text))
    sysml_doc = extract_sysml(ingest.from_text(sysml_text))
    alignment = align(nl_doc, sysml_doc)
    mismatches = diff(nl_doc, sysml_doc, alignment)
    return report_data(nl_doc, sysml_doc, alignment, mismatches)


def compare_files(nl_path: str, sysml_path: str) -> tuple:
    nl_doc = extract_nl(ingest.from_file(nl_path))
    sysml_doc = extract_sysml(ingest.from_file(sysml_path))
    alignment = align(nl_doc, sysml_doc)
    mismatches = diff(nl_doc, sysml_doc, alignment)
    return nl_doc, sysml_doc, alignment, mismatches
