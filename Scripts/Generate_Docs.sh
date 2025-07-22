#!/bin/bash

# ==========================================================
# Documentation Generation Script
# ==========================================================
#
# How to use this script:
# 1. Set executable permissions (one-time setup):
#    chmod +x Scripts/Generate_Docs.sh
#
# 2. Run the script from the project root:
#    ./Scripts/Generate_Docs.sh
# ==========================================================

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$SCRIPT_DIR/pdfs"
TEMP_DIR="$PROJECT_DIR/temp"

# Create output and temp directories
mkdir -p "$OUTPUT_DIR"
if [ -d "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
fi
mkdir -p "$TEMP_DIR"

# Set temporary directory for mermaid-filter
export TMPDIR="$TEMP_DIR"

# This script generates PDF documentation from markdown files using Pandoc
#
# Command Structure Explanation:
# find . -type f -path './DIR/*.md' -print0:
#   - Searches for all markdown files in specified directories
#   - -type f: Only find files (not directories)
#   - -print0: Uses null byte as filename delimiter (handles spaces in filenames)
#
# xargs -0 pandoc:
#   - Takes null-terminated input from find
#   - Passes filenames safely to pandoc command
#
# Pandoc Options:
#   --lua-filter=./mermaid-filter.lua: Processes Mermaid diagrams in markdown
#   --css=./pandoc.css: Applies custom CSS styling
#   --toc: Generates table of contents
#   --toc-depth=3: Includes headings up to level 3 in TOC
#   --number-sections: Automatically numbers document sections
#   --lot: Includes List of Tables
#   --lof: Includes List of Figures
#   --metadata: Sets document properties (title, author, date)
#   --pdf-engine=prince: Uses PrinceXML for PDF generation
#   -o: Specifies output filename
#
# Required Homebrew installations:
#   brew install pandoc            # Document converter
#   brew install lua              # Required for Mermaid diagrams
#   brew install princepdf        # PDF generation engine
#   brew install findutils        # For GNU find (needed for -print0)
#
# Note: After installing, you may need to:
#   1. Install the mermaid-filter.lua from Pandoc's Wiki
#   2. Ensure your pandoc.css file exists in the script directory

# Change to project directory to ensure correct relative paths
cd "$PROJECT_DIR"

# ---------------------------------------------------------
# Market Analysis
# ---------------------------------------------------------

find Documentation/Research -type f -name "*.md" -print0 | \
  xargs -0 pandoc \
    --lua-filter="$SCRIPT_DIR/mermaid-filter.lua" \
    --css="$SCRIPT_DIR/pandoc.css" \
    --toc \
    --toc-depth=2 \
    --lot \
    --lof \
    --metadata title="Market Research" \
    --metadata author="AJ McClary" \
    --metadata date="$(date '+%B %Y')" \
    --pdf-engine=prince \
    -o "$OUTPUT_DIR/Research.pdf"

# # ---------------------------------------------------------
# # API Documentation
# # ---------------------------------------------------------

# find Documentation/API -type f -name "*.md" -print0 | \
#   xargs -0 pandoc \
#     --lua-filter="$SCRIPT_DIR/mermaid-filter.lua" \
#     --css="$SCRIPT_DIR/pandoc.css" \
#     --toc \
#     --toc-depth=3 \
#     --number-sections \
#     --lot \
#     --lof \
#     --metadata title="InkWave API" \
#     --metadata author="AJ McClary" \
#     --metadata date="$(date '+%B %Y')" \
#     --pdf-engine=prince \
#     -o "$OUTPUT_DIR/API.pdf"

# ---------------------------------------------------------
# Architecture Documentation
# ---------------------------------------------------------

find Documentation/Architecture -type f -name "*.md" -print0 | \
  xargs -0 pandoc \
    --lua-filter="$SCRIPT_DIR/mermaid-filter.lua" \
    --css="$SCRIPT_DIR/pandoc.css" \
    --toc \
    --toc-depth=3 \
    --number-sections \
    --lot \
    --lof \
    --metadata title="InkWave Architecture" \
    --metadata author="AJ McClary" \
    --metadata date="$(date '+%B %Y')" \
    --pdf-engine=prince \
    -o "$OUTPUT_DIR/Architecture.pdf"

# ---------------------------------------------------------
# Development Documentation
# ---------------------------------------------------------

find Documentation/Development -type f -name "*.md" -print0 | \
  xargs -0 pandoc \
    --lua-filter="$SCRIPT_DIR/mermaid-filter.lua" \
    --css="$SCRIPT_DIR/pandoc.css" \
    --toc \
    --toc-depth=3 \
    --number-sections \
    --lot \
    --lof \
    --metadata title="InkWave Development" \
    --metadata author="AJ McClary" \
    --metadata date="$(date '+%B %Y')" \
    --pdf-engine=prince \
    -o "$OUTPUT_DIR/Development.pdf"

# ---------------------------------------------------------
# Getting Started Guide
# ---------------------------------------------------------

find "Documentation/Getting Started" -type f -name "*.md" -print0 | \
  xargs -0 pandoc \
    --lua-filter="$SCRIPT_DIR/mermaid-filter.lua" \
    --css="$SCRIPT_DIR/pandoc.css" \
    --toc \
    --toc-depth=3 \
    --number-sections \
    --lot \
    --lof \
    --metadata title="InkWave Getting Started" \
    --metadata author="AJ McClary" \
    --metadata date="$(date '+%B %Y')" \
    --pdf-engine=prince \
    -o "$OUTPUT_DIR/GettingStarted.pdf"

# ---------------------------------------------------------
# Performance Documentation
# ---------------------------------------------------------

find Documentation/Performance -type f -name "*.md" -print0 | \
  xargs -0 pandoc \
    --lua-filter="$SCRIPT_DIR/mermaid-filter.lua" \
    --css="$SCRIPT_DIR/pandoc.css" \
    --toc \
    --toc-depth=3 \
    --number-sections \
    --lot \
    --lof \
    --metadata title="InkWave Performance" \
    --metadata author="AJ McClary" \
    --metadata date="$(date '+%B %Y')" \
    --pdf-engine=prince \
    -o "$OUTPUT_DIR/Performance.pdf"

# ---------------------------------------------------------
# Release Notes
# ---------------------------------------------------------

find Documentation/Releases -type f -name "*.md" -print0 | \
  xargs -0 pandoc \
    --lua-filter="$SCRIPT_DIR/mermaid-filter.lua" \
    --css="$SCRIPT_DIR/pandoc.css" \
    --toc \
    --toc-depth=3 \
    --number-sections \
    --lot \
    --lof \
    --metadata title="InkWave Releases" \
    --metadata author="AJ McClary" \
    --metadata date="$(date '+%B %Y')" \
    --pdf-engine=prince \
    -o "$OUTPUT_DIR/Releases.pdf"

# ---------------------------------------------------------
# Security Documentation
# ---------------------------------------------------------

find Documentation/Security -type f -name "*.md" -print0 | \
  xargs -0 pandoc \
    --lua-filter="$SCRIPT_DIR/mermaid-filter.lua" \
    --css="$SCRIPT_DIR/pandoc.css" \
    --toc \
    --toc-depth=3 \
    --number-sections \
    --lot \
    --lof \
    --metadata title="InkWave Security" \
    --metadata author="AJ McClary" \
    --metadata date="$(date '+%B %Y')" \
    --pdf-engine=prince \
    -o "$OUTPUT_DIR/Security.pdf"

# ---------------------------------------------------------
# Testing Documentation
# ---------------------------------------------------------

find Documentation/Testing -type f -name "*.md" -print0 | \
  xargs -0 pandoc \
    --lua-filter="$SCRIPT_DIR/mermaid-filter.lua" \
    --css="$SCRIPT_DIR/pandoc.css" \
    --toc \
    --toc-depth=3 \
    --number-sections \
    --lot \
    --lof \
    --metadata title="InkWave Testing" \
    --metadata author="AJ McClary" \
    --metadata date="$(date '+%B %Y')" \
    --pdf-engine=prince \
    -o "$OUTPUT_DIR/Testing.pdf"

# ---------------------------------------------------------
# User Guides
# ---------------------------------------------------------

find "Documentation/User Guides" -type f -name "*.md" -print0 | \
  xargs -0 pandoc \
    --lua-filter="$SCRIPT_DIR/mermaid-filter.lua" \
    --css="$SCRIPT_DIR/pandoc.css" \
    --toc \
    --toc-depth=3 \
    --number-sections \
    --lot \
    --lof \
    --metadata title="InkWave User Guide" \
    --metadata author="AJ McClary" \
    --metadata date="$(date '+%B %Y')" \
    --pdf-engine=prince \
    -o "$OUTPUT_DIR/UserGuide.pdf"

# ---------------------------------------------------------
# Project Overview (README)
# ---------------------------------------------------------

pandoc Documentation/README.md \
  --lua-filter="$SCRIPT_DIR/mermaid-filter.lua" \
  --css="$SCRIPT_DIR/pandoc.css" \
  --toc \
  --toc-depth=3 \
  --number-sections \
  --lot \
  --lof \
  --metadata title="InkWave Overview" \
  --metadata author="AJ McClary" \
  --metadata date="$(date '+%B %Y')" \
  --pdf-engine=prince \
  -o "$OUTPUT_DIR/README.pdf"

# ---------------------------------------------------------
# Cleanup
# ---------------------------------------------------------

# Clean up the temporary directory
if [ -d "$TEMP_DIR" ]; then
    echo "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
fi

echo "Documentation generated successfully in $OUTPUT_DIR"