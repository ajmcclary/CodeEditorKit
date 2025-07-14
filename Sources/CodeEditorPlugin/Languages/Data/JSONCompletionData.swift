import Foundation

// MARK: - JSON Completion Data

/// Static data constants for JSON completion provider
public enum JSONCompletionData {
    // MARK: - JSON Keywords
    
    static let keywords = ["true", "false", "null"]
    
    // MARK: - JSON Schema Properties
    
    static let schemaProperties = [
        "$schema", "$id", "$ref", "$defs", "definitions", "title", "description",
        "type", "properties", "items", "required", "additionalProperties",
        "patternProperties", "dependencies", "enum", "const", "allOf", "anyOf",
        "oneOf", "not", "format", "default", "examples", "minimum", "maximum",
        "exclusiveMinimum", "exclusiveMaximum", "multipleOf", "minLength",
        "maxLength", "pattern", "minItems", "maxItems", "uniqueItems",
        "minProperties", "maxProperties", "if", "then", "else"
    ]
    
    // MARK: - JSON Types
    
    static let types = ["object", "array", "string", "number", "integer", "boolean", "null"]
    
    // MARK: - JSON Formats
    
    static let formats = [
        "date-time", "date", "time", "duration", "email", "hostname",
        "ipv4", "ipv6", "uri", "uri-reference", "uuid", "regex",
        "json-pointer", "relative-json-pointer"
    ]
    
    // MARK: - Package.json Properties
    
    static let packageJsonProperties = [
        "name", "version", "description", "main", "scripts", "keywords",
        "author", "license", "dependencies", "devDependencies",
        "peerDependencies", "optionalDependencies", "engines", "repository",
        "bugs", "homepage", "private", "type", "module", "browser",
        "bin", "files", "directories", "publishConfig", "workspaces",
        "exports", "imports", "funding"
    ]
    
    // MARK: - TSConfig Properties
    
    static let tsconfigProperties = [
        "compilerOptions", "include", "exclude", "files", "extends",
        "references", "typeAcquisition", "watchOptions", "buildOptions"
    ]
    
    // MARK: - TypeScript Compiler Options
    
    static let compilerOptions = [
        "target", "module", "lib", "jsx", "outDir", "rootDir", "strict",
        "esModuleInterop", "skipLibCheck", "forceConsistentCasingInFileNames",
        "resolveJsonModule", "allowJs", "checkJs", "declaration", "sourceMap",
        "removeComments", "noEmit", "importHelpers", "downlevelIteration",
        "isolatedModules", "allowSyntheticDefaultImports", "experimentalDecorators",
        "emitDecoratorMetadata", "moduleResolution", "baseUrl", "paths",
        "typeRoots", "types", "allowUmdGlobalAccess", "noImplicitAny",
        "strictNullChecks", "strictFunctionTypes", "strictBindCallApply",
        "strictPropertyInitialization", "noImplicitThis", "alwaysStrict"
    ]
    
    // MARK: - ESLint Properties
    
    static let eslintProperties = [
        "env", "extends", "parser", "parserOptions", "plugins", "rules",
        "settings", "overrides", "globals", "ignorePatterns", "root"
    ]
    
    // MARK: - Common JSON Snippet Templates
    
    static let snippets: [SnippetTemplate] = [
        SnippetTemplate(
            label: "object",
            insertText: "{\n    \"${1:key}\": ${2:\"value\"}\n}",
            description: "JSON object"
        ),
        SnippetTemplate(
            label: "array",
            insertText: "[\n    ${1:\"item\"}\n]",
            description: "JSON array"
        ),
        SnippetTemplate(
            label: "property",
            insertText: "\"${1:key}\": ${2:\"value\"}",
            description: "Object property"
        ),
        SnippetTemplate(
            label: "package.json",
            insertText: """
{
    "name": "${1:package-name}",
    "version": "${2:1.0.0}",
    "description": "${3:Package description}",
    "main": "${4:index.js}",
    "scripts": {
        "test": "${5:echo \\"Error: no test specified\\" && exit 1}"
    },
    "keywords": [],
    "author": "${6:}",
    "license": "${7:ISC}",
    "dependencies": {},
    "devDependencies": {}
}
""",
            description: "package.json template"
        ),
        SnippetTemplate(
            label: "tsconfig.json",
            insertText: """
{
    "compilerOptions": {
        "target": "${1:ES2020}",
        "module": "${2:commonjs}",
        "lib": ["${3:ES2020}"],
        "outDir": "${4:./dist}",
        "rootDir": "${5:./src}",
        "strict": true,
        "esModuleInterop": true,
        "skipLibCheck": true,
        "forceConsistentCasingInFileNames": true,
        "resolveJsonModule": true
    },
    "include": ["${6:src/**/*}"],
    "exclude": ["node_modules", "dist"]
}
""",
            description: "tsconfig.json template"
        ),
        SnippetTemplate(
            label: ".eslintrc.json",
            insertText: """
{
    "env": {
        "browser": ${1:true},
        "es2021": ${2:true},
        "node": ${3:true}
    },
    "extends": [
        "${4:eslint:recommended}"
    ],
    "parserOptions": {
        "ecmaVersion": "${5:latest}",
        "sourceType": "${6:module}"
    },
    "rules": {
        ${7:}
    }
}
""",
            description: "ESLint configuration"
        ),
        SnippetTemplate(
            label: "launch.json",
            insertText: """
{
    "version": "0.2.0",
    "configurations": [
        {
            "type": "${1:node}",
            "request": "${2:launch}",
            "name": "${3:Launch Program}",
            "program": "\\${workspaceFolder}/${4:index.js}",
            "skipFiles": [
                "<node_internals>/**"
            ]
        }
    ]
}
""",
            description: "VS Code launch configuration"
        ),
        SnippetTemplate(
            label: "settings.json",
            insertText: """
{
    "${1:editor.formatOnSave}": ${2:true},
    "${3:editor.tabSize}": ${4:2}
}
""",
            description: "VS Code settings"
        ),
        SnippetTemplate(
            label: "schema",
            insertText: """
{
    "\\$schema": "${1:http://json-schema.org/draft-07/schema#}",
    "\\$id": "${2:https://example.com/schema.json}",
    "title": "${3:Schema Title}",
    "description": "${4:Schema description}",
    "type": "${5:object}",
    "properties": {
        ${6:}
    }
}
""",
            description: "JSON Schema"
        ),
        SnippetTemplate(
            label: "property-string",
            insertText: """
"${1:propertyName}": {
    "type": "string",
    "description": "${2:Property description}"
}
""",
            description: "String property schema"
        ),
        SnippetTemplate(
            label: "property-number",
            insertText: """
"${1:propertyName}": {
    "type": "number",
    "description": "${2:Property description}",
    "minimum": ${3:0}
}
""",
            description: "Number property schema"
        ),
        SnippetTemplate(
            label: "property-object",
            insertText: """
"${1:propertyName}": {
    "type": "object",
    "description": "${2:Property description}",
    "properties": {
        ${3:}
    }
}
""",
            description: "Object property schema"
        ),
        SnippetTemplate(
            label: "property-array",
            insertText: """
"${1:propertyName}": {
    "type": "array",
    "description": "${2:Property description}",
    "items": {
        "type": "${3:string}"
    }
}
""",
            description: "Array property schema"
        )
    ]
    
    // MARK: - Common JSON File Types
    
    static let jsonFileTypes = [
        "package.json", "tsconfig.json", "jsconfig.json", ".eslintrc.json",
        "launch.json", "settings.json", "tasks.json", "composer.json",
        "bower.json", ".prettierrc.json", ".babelrc.json", "manifest.json",
        "appsettings.json", "schema.json"
    ]
    
    // MARK: - Common Script Names
    
    static let commonScripts = [
        "start", "test", "build", "dev", "lint", "format", "clean",
        "watch", "serve", "deploy", "publish", "prepare", "preinstall",
        "postinstall", "prebuild", "postbuild", "pretest", "posttest"
    ]
}
