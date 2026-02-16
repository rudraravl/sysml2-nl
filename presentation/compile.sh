#!/bin/bash

set -e  # Exit on any error

# Check if lecture name is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <deck_name>"
    echo "Example: $0 icml"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DECK_NAME="$1"
SOURCE_DIR="${SCRIPT_DIR}/${DECK_NAME}"
SOURCE_TEX="${SOURCE_DIR}/main.tex"
OUTPUT_DIR="${SOURCE_DIR}"
LOG_FILE="${OUTPUT_DIR}/main.log"

echo "Compiling deck: ${DECK_NAME}..."

# Check if source file exists
if [ ! -f "$SOURCE_TEX" ]; then
    echo "Error: Source file $SOURCE_TEX not found!"
    exit 1
fi

# Function to run pdflatex with error checking
run_pdflatex() {
    local pass_name="$1"
    echo "Running $pass_name..."
    if ! (cd "$SOURCE_DIR" && pdflatex -interaction=nonstopmode -output-directory="$OUTPUT_DIR" "main.tex"); then
        echo "Error: pdflatex failed during $pass_name"
        exit 1
    fi
}

# Function to run bibtex with error checking
run_bibtex() {
    echo "Running bibtex..."
    if ! (cd "$OUTPUT_DIR" && bibtex "main"); then
        echo "Error: bibtex failed"
        exit 1
    fi
}

# First pass: pdflatex (creates .aux file)
echo "=== First pass: pdflatex (creating auxiliary files) ==="
run_pdflatex "first pass"

# BibTeX pass: generate bibliography
echo "=== BibTeX pass: generating bibliography ==="
run_bibtex

# Second pass: pdflatex to resolve cross-references
echo "=== Second pass: pdflatex (resolving cross-references) ==="
run_pdflatex "second pass"

# Third pass: pdflatex to ensure all references are resolved
echo "=== Third pass: pdflatex (final resolution check) ==="
run_pdflatex "third pass"

# Check if there are still undefined references
echo "=== Checking for unresolved references ==="
if [ -f "$LOG_FILE" ] && grep -q "LaTeX Warning: Reference.*undefined" "$LOG_FILE"; then
    echo "Warning: Some references may still be undefined. Running additional pass..."
    run_pdflatex "additional pass"
fi

echo "=== Compilation complete! ==="
echo "Generated: ${OUTPUT_DIR}/main.pdf"

# Check final PDF size
if [ -f "${OUTPUT_DIR}/main.pdf" ]; then
    pdf_size=$(stat -f%z "${OUTPUT_DIR}/main.pdf" 2>/dev/null || stat -c%s "${OUTPUT_DIR}/main.pdf" 2>/dev/null || echo "unknown")
    echo "Final PDF size: $pdf_size bytes"
    
    # Count pages if possible
    if command -v pdfinfo >/dev/null 2>&1; then
        page_count=$(pdfinfo "${OUTPUT_DIR}/main.pdf" 2>/dev/null | grep "Pages:" | awk '{print $2}' || echo "unknown")
        echo "Page count: $page_count"
    fi
else
    echo "Error: PDF was not generated!"
    exit 1
fi

# Clean up auxiliary files AFTER successful compilation
echo "=== Cleaning up auxiliary files ==="
cd "$OUTPUT_DIR"
rm -f *.aux *.log *.out *.toc *.lof *.lot *.fls *.fdb_latexmk *.synctex.gz *.nav *.snm *.vrb
rm -f *.bbl *.blg
echo "Cleanup complete!"

echo "=== Summary ==="
echo "Build files: cleaned from ${OUTPUT_DIR}"
echo "Final PDF: ${OUTPUT_DIR}/main.pdf"
echo "Compilation completed successfully!"
