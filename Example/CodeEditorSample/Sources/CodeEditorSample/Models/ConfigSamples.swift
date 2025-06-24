import Foundation

// MARK: - Configuration Format Samples

enum ConfigSamples {
    static let jsonSample = """
    {
      "name": "CodeEditorPlugin",
      "version": "1.0.0",
      "description": "A comprehensive code editor plugin with syntax highlighting",
      "main": "index.js",
      "author": {
        "name": "Developer",
        "email": "developer@example.com",
        "url": "https://example.com"
      },
      "license": "MIT",
      "keywords": [
        "editor",
        "syntax-highlighting",
        "code",
        "ide",
        "plugin"
      ],
      "repository": {
        "type": "git",
        "url": "https://github.com/example/code-editor-plugin.git"
      },
      "bugs": {
        "url": "https://github.com/example/code-editor-plugin/issues"
      },
      "engines": {
        "node": ">=14.0.0",
        "npm": ">=6.0.0"
      },
      "scripts": {
        "start": "node server.js",
        "dev": "nodemon server.js",
        "build": "webpack --mode production",
        "test": "jest",
        "lint": "eslint .",
        "format": "prettier --write ."
      },
      "dependencies": {
        "express": "^4.18.2",
        "lodash": "^4.17.21",
        "axios": "^1.4.0",
        "react": "^18.2.0",
        "react-dom": "^18.2.0"
      },
      "devDependencies": {
        "@types/node": "^20.0.0",
        "@types/react": "^18.0.0",
        "eslint": "^8.42.0",
        "jest": "^29.5.0",
        "nodemon": "^2.0.22",
        "prettier": "^2.8.8",
        "typescript": "^5.1.3",
        "webpack": "^5.88.0"
      },
      "config": {
        "port": 3000,
        "host": "localhost",
        "database": {
          "host": "localhost",
          "port": 5432,
          "name": "editor_db",
          "user": "admin",
          "ssl": true
        }
      },
      "features": {
        "syntaxHighlighting": true,
        "autoComplete": true,
        "linting": true,
        "themes": [
          "dark",
          "light",
          "monokai",
          "solarized"
        ],
        "languages": [
          "javascript",
          "typescript",
          "python",
          "go",
          "rust",
          "swift"
        ]
      }
    }
    """
}
