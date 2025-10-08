#!/bin/bash

# XCamp 602 Lecture Compilation Script
# This script compiles lecture files with proper image handling
# Based on LaTeX best practices for lecture materials with figures

set -e  # Exit on any error

# Check if lecture name is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <lecture_name>"
    echo "Example: $0 lec2"
    exit 1
fi

LECTURE_NAME="$1"
LECTURE_FILE="${LECTURE_NAME}.tex"

echo "Compiling XCamp 602 lecture: $LECTURE_NAME..."

# Check if lecture file exists
if [ ! -f "$LECTURE_FILE" ]; then
    echo "Error: Lecture file $LECTURE_FILE not found!"
    exit 1
fi

# Create build directory if it doesn't exist
mkdir -p build

# Copy images to build directory early
echo "Copying images to build directory..."
if [ -d "figure" ]; then
    cp -r figure build/
fi

# Function to run pdflatex with error checking
run_pdflatex() {
    local pass_name="$1"
    echo "Running $pass_name..."
    if ! pdflatex -interaction=nonstopmode -output-directory=build "$LECTURE_FILE"; then
        echo "Error: pdflatex failed during $pass_name"
        exit 1
    fi
}

# First pass: pdflatex (creates .aux file)
echo "=== First pass: pdflatex (creating auxiliary files) ==="
run_pdflatex "first pass"

# Second pass: pdflatex to resolve cross-references
echo "=== Second pass: pdflatex (resolving cross-references) ==="
run_pdflatex "second pass"

# Third pass: pdflatex to ensure all references are resolved
echo "=== Third pass: pdflatex (final resolution check) ==="
run_pdflatex "third pass"

# Check if there are still undefined references
echo "=== Checking for unresolved references ==="
cd build
if grep -q "LaTeX Warning: Reference.*undefined" "${LECTURE_NAME}.log"; then
    echo "Warning: Some references may still be undefined. Running additional pass..."
    cd ..
    pdflatex -interaction=nonstopmode -output-directory=build "$LECTURE_FILE"
    cd build
fi
cd ..

echo "=== Compilation complete! ==="
echo "Generated: build/${LECTURE_NAME}.pdf"

# Check final PDF size
if [ -f "build/${LECTURE_NAME}.pdf" ]; then
    pdf_size=$(stat -f%z "build/${LECTURE_NAME}.pdf" 2>/dev/null || stat -c%s "build/${LECTURE_NAME}.pdf" 2>/dev/null || echo "unknown")
    echo "Final PDF size: $pdf_size bytes"
    
    # Count pages if possible
    if command -v pdfinfo >/dev/null 2>&1; then
        page_count=$(pdfinfo "build/${LECTURE_NAME}.pdf" 2>/dev/null | grep "Pages:" | awk '{print $2}' || echo "unknown")
        echo "Page count: $page_count"
    fi
else
    echo "Error: PDF was not generated!"
    exit 1
fi

# Clean up auxiliary files AFTER successful compilation
echo "=== Cleaning up auxiliary files ==="
cd build
rm -f *.aux *.log *.out *.toc *.lof *.lot *.fls *.fdb_latexmk *.synctex.gz *.nav *.snm *.vrb
rm -rf figure/
echo "Cleanup complete!"

echo "=== Summary ==="
echo "All files are now in the build/ directory"
echo "Final PDF: build/${LECTURE_NAME}.pdf"
echo "Compilation completed successfully!"
