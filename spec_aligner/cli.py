from __future__ import annotations

import argparse
import json
import sys

from .pipeline import compare_files
from .report import report_data, write_json, write_markdown


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="specdiff", description="Compare NL requirements with SysML v2 specs.")
    parser.add_argument("--nl", required=True, help="Natural-language requirements file")
    parser.add_argument("--sysml", required=True, help="SysML v2 model file")
    parser.add_argument("--out", help="Markdown report path")
    parser.add_argument("--json", dest="json_out", help="JSON report path")
    args = parser.parse_args(argv)

    nl_doc, sysml_doc, alignment, mismatches = compare_files(args.nl, args.sysml)
    data = report_data(nl_doc, sysml_doc, alignment, mismatches)

    if args.json_out:
        write_json(args.json_out, data)
    if args.out:
        write_markdown(args.out, nl_doc, sysml_doc, mismatches)
    if not args.out and not args.json_out:
        json.dump(data, sys.stdout, indent=2, ensure_ascii=False)
        sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
