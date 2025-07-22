# Pandoc Command-Line Reference

## General Options

### Input/Output Options
- [ ] `-f FORMAT, -r FORMAT, --from=FORMAT, --read=FORMAT`: Specify input format
- [ ] `-t FORMAT, -w FORMAT, --to=FORMAT, --write=FORMAT`: Specify output format
- [ ] `-o FILENAME, --output=FILENAME`: Write output to FILENAME
- [ ] `--data-dir=DIRECTORY`: Specify the user data directory
- [ ] `-d FILE, --defaults=FILE`: Specify a set of default option settings

### Reader Options
- [ ] `--shift-heading-level-by=NUMBER`: Shift heading levels by specified number
- [ ] `--base-header-level=NUMBER`: Specify the base level for headers
- [ ] `--strip-empty-paragraphs`: Remove empty paragraphs
- [ ] `--indented-code-classes=CLASSES`: Specify classes for indented code blocks
- [ ] `--default-image-extension=EXTENSION`: Specify default extension for images
- [ ] `--file-scope`: Parse each file individually

### General Writer Options
- [ ] `--standalone`: Produce output with appropriate header and footer
- [ ] `--template=FILENAME`: Use specified template
- [ ] `--variable=KEY[:VALUE]`: Set template variables
- [ ] `--wrap=auto|none|preserve`: Specify text wrapping mode
- [ ] `--ascii`: Use only ASCII characters in output
- [ ] `--toc, --table-of-contents`: Include table of contents
- [ ] `--toc-depth=NUMBER`: Specify number of heading levels in TOC

### Citation Options
- [ ] `--citeproc`: Process citations
- [ ] `--bibliography=FILE`: Specify bibliography database
- [ ] `--csl=FILE`: Specify citation style
- [ ] `--citation-abbreviations=FILE`: Specify citation abbreviations
- [ ] `--natbib`: Use natbib for citations
- [ ] `--biblatex`: Use biblatex for citations

### Math Rendering Options
- [ ] `--mathjax[=URL]`: Use MathJax to display math
- [ ] `--mathml`: Convert TeX math to MathML
- [ ] `--webtex[=URL]`: Convert TeX math to web images
- [ ] `--katex[=URL]`: Use KaTeX to display math
- [ ] `--gladtex`: Convert TeX math to GladTeX images

### HTML-Specific Options
- [ ] `--css=URL`: Link to CSS style sheet
- [ ] `--html-q-tags`: Use `<q>` tags for quotes in HTML
- [ ] `--self-contained`: Produce HTML with embedded images/CSS/scripts
- [ ] `--html-math-method=METHOD`: Specify math rendering method
- [ ] `--syntax-definition=FILE`: Specify syntax highlighting definitions
- [ ] `--highlight-style=STYLE`: Specify highlighting style
- [ ] `--email-obfuscation=none|javascript|references`: Specify email obfuscation method

### PDF-Specific Options
- [ ] `--pdf-engine=PROGRAM`: Specify PDF processing engine
- [ ] `--pdf-engine-opt=STRING`: Pass additional options to PDF engine
- [ ] `--listings`: Use listings package for code blocks
- [ ] `--number-sections`: Number section headings
- [ ] `--number-offset=NUMBERS`: Offset for section numbering

### MS Word-Specific Options
- [ ] `--reference-doc=FILE`: Use specified file as reference for styles
- [ ] `--track-changes=accept|reject|all`: Specify track changes mode

### Markdown-Specific Options
- [ ] `--markdown-headings=setext|atx`: Specify heading style
- [ ] `--reference-links`: Use reference-style links
- [ ] `--reference-location=block|section|document`: Specify reference location
- [ ] `--atx-headers`: Use ATX-style headers

### Format Conversion Options
- [ ] `--extract-media=DIR`: Extract embedded media files
- [ ] `--abbreviations=FILE`: Specify abbreviations file
- [ ] `--trace`: Show diagnostic output
- [ ] `--dump-args`: Print command-line arguments
- [ ] `--ignore-args`: Ignore command-line arguments
- [ ] `--verbose`: Give verbose debugging output

### Filtering Options
- [ ] `--filter=PROGRAM`: Specify filters to be applied
- [ ] `--lua-filter=SCRIPT`: Apply Lua filters
- [ ] `--metadata=KEY[:VALUE]`: Set metadata fields
- [ ] `--metadata-file=FILE`: Read metadata from file

### Error Handling
- [ ] `--fail-if-warnings`: Exit with error status if there are warnings
- [ ] `--log=FILE`: Write log messages in machine-readable JSON format
- [ ] `--bash-completion`: Generate bash completion script
- [ ] `--list-input-formats`: List supported input formats
- [ ] `--list-output-formats`: List supported output formats
- [ ] `--list-extensions[=FORMAT]`: List supported extensions
- [ ] `--list-highlight-languages`: List supported highlighting languages
- [ ] `--list-highlight-styles`: List supported highlighting styles

## Usage Examples

Basic PDF conversion:
```bash
pandoc input.md -o output.pdf
```

Convert to HTML with table of contents:
```bash
pandoc input.md -s --toc -o output.html
```

Convert Word to Markdown:
```bash
pandoc -f docx -t markdown input.docx -o output.md
```

Create a PDF with custom template:
```bash
pandoc input.md --template=custom.tex -o output.pdf
```

Convert with citations:
```bash
pandoc input.md --citeproc --bibliography=refs.bib -o output.pdf
```

Note: This reference covers the most commonly used options. For the complete and most up-to-date list of options, consult the official Pandoc documentation or run `pandoc --help`.