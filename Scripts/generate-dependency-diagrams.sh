#!/bin/bash

# Generate dependency diagrams using depermaid
# This script generates Mermaid diagrams for both CodeEditorPlugin and CodeEditorSample

set -e

echo "🔍 Generating dependency diagrams for CodeEditorPlugin..."

# Navigate to the root directory
cd "$(dirname "$0")/.."

echo "📊 Generating main package dependencies..."

# Generate main package diagram
echo "# Package Dependencies - CodeEditorPlugin" > Diagrams/25-package-dependencies.md
echo "" >> Diagrams/25-package-dependencies.md
echo "This diagram shows the package dependencies for the main CodeEditorPlugin framework." >> Diagrams/25-package-dependencies.md
echo "" >> Diagrams/25-package-dependencies.md
echo "## Default View (Products Only)" >> Diagrams/25-package-dependencies.md
echo "" >> Diagrams/25-package-dependencies.md
swift package plugin depermaid --product >> Diagrams/25-package-dependencies.md
echo "" >> Diagrams/25-package-dependencies.md
echo "## Complete View (Including Test Targets)" >> Diagrams/25-package-dependencies.md
echo "" >> Diagrams/25-package-dependencies.md
echo '```mermaid' >> Diagrams/25-package-dependencies.md
swift package plugin depermaid --test >> Diagrams/25-package-dependencies.md
echo '```' >> Diagrams/25-package-dependencies.md
echo "" >> Diagrams/25-package-dependencies.md
echo "## Horizontal Layout" >> Diagrams/25-package-dependencies.md
echo "" >> Diagrams/25-package-dependencies.md
echo '```mermaid' >> Diagrams/25-package-dependencies.md
swift package plugin depermaid --product --direction LR >> Diagrams/25-package-dependencies.md
echo '```' >> Diagrams/25-package-dependencies.md

echo "📊 Generating sample app dependencies..."

# Generate sample app diagram
cd CodeEditorSample
echo "# Package Dependencies - CodeEditorSample" > ../Diagrams/26-sample-dependencies.md
echo "" >> ../Diagrams/26-sample-dependencies.md
echo "This diagram shows the package dependencies for the CodeEditorSample demonstration app." >> ../Diagrams/26-sample-dependencies.md
echo "" >> ../Diagrams/26-sample-dependencies.md
echo "## Default View (Executable and Dependencies)" >> ../Diagrams/26-sample-dependencies.md
echo "" >> ../Diagrams/26-sample-dependencies.md
swift package plugin depermaid --executable >> ../Diagrams/26-sample-dependencies.md
echo "" >> ../Diagrams/26-sample-dependencies.md
echo "## Complete View (Including Test Targets)" >> ../Diagrams/26-sample-dependencies.md
echo "" >> ../Diagrams/26-sample-dependencies.md
echo '```mermaid' >> ../Diagrams/26-sample-dependencies.md
swift package plugin depermaid --test --executable >> ../Diagrams/26-sample-dependencies.md
echo '```' >> ../Diagrams/26-sample-dependencies.md
echo "" >> ../Diagrams/26-sample-dependencies.md
echo "## Horizontal Layout with All Components" >> ../Diagrams/26-sample-dependencies.md
echo "" >> ../Diagrams/26-sample-dependencies.md
echo '```mermaid' >> ../Diagrams/26-sample-dependencies.md
swift package plugin depermaid --test --executable --product --direction LR >> ../Diagrams/26-sample-dependencies.md
echo '```' >> ../Diagrams/26-sample-dependencies.md

cd ..

echo "✅ Dependency diagrams generated successfully!"
echo "   - Diagrams/25-package-dependencies.md"
echo "   - Diagrams/26-sample-dependencies.md"