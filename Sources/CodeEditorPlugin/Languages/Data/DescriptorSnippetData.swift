import Foundation

enum DescriptorSnippetData {
    static let javascript: [SnippetTemplate] = [
        .init(label: "function", insertText: "function ${1:name}(${2:params}) {\n    ${3:// body}\n}", description: "Function declaration"),
        .init(label: "arrow", insertText: "const ${1:name} = (${2:params}) => {\n    ${3:// body}\n}", description: "Arrow function"),
        .init(label: "class", insertText: "class ${1:ClassName} {\n    constructor(${2:params}) {\n        ${3:// body}\n    }\n}", description: "Class declaration"),
        .init(label: "async", insertText: "async function ${1:name}(${2:params}) {\n    ${3:// body}\n}", description: "Async function"),
        .init(label: "try", insertText: "try {\n    ${1:// code}\n} catch (${2:error}) {\n    ${3:// handle error}\n}", description: "Try/catch block"),
        .init(label: "import", insertText: "import ${1:name} from '${2:module}';", description: "ES module import")
    ]

    static let python: [SnippetTemplate] = [
        .init(label: "def", insertText: "def ${1:function_name}(${2:parameters}):\n    ${3:pass}", description: "Function definition"),
        .init(label: "class", insertText: "class ${1:ClassName}:\n    def __init__(self${2:, parameters}):\n        ${3:pass}", description: "Class definition"),
        .init(label: "if", insertText: "if ${1:condition}:\n    ${2:pass}", description: "If statement"),
        .init(label: "for", insertText: "for ${1:item} in ${2:iterable}:\n    ${3:pass}", description: "For loop"),
        .init(label: "try", insertText: "try:\n    ${1:pass}\nexcept ${2:Exception} as ${3:error}:\n    ${4:pass}", description: "Try/except block"),
        .init(label: "main", insertText: "if __name__ == \"__main__\":\n    ${1:main()}", description: "Main guard")
    ]

    static let java: [SnippetTemplate] = [
        .init(label: "class", insertText: "public class ${1:ClassName} {\n    ${2:// fields and methods}\n}", description: "Class declaration"),
        .init(label: "main", insertText: "public static void main(String[] args) {\n    ${1:// main code}\n}", description: "Main method"),
        .init(label: "method", insertText: "${1:public} ${2:void} ${3:methodName}(${4:parameters}) {\n    ${5:// body}\n}", description: "Method declaration"),
        .init(label: "try", insertText: "try {\n    ${1:// code}\n} catch (${2:Exception} ${3:e}) {\n    ${4:// handle exception}\n}", description: "Try/catch block"),
        .init(label: "sout", insertText: "System.out.println(${1:message});", description: "Print to console")
    ]

    static let html: [SnippetTemplate] = [
        .init(label: "html5", insertText: "<!DOCTYPE html>\n<html lang=\"${1:en}\">\n<head>\n    <meta charset=\"UTF-8\">\n    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n    <title>${2:Document}</title>\n</head>\n<body>\n    ${3:<!-- content -->}\n</body>\n</html>", description: "HTML5 boilerplate"),
        .init(label: "link-css", insertText: "<link rel=\"stylesheet\" href=\"${1:style.css}\">", description: "Stylesheet link"),
        .init(label: "script", insertText: "<script src=\"${1:script.js}\"></script>", description: "Script tag"),
        .init(label: "img", insertText: "<img src=\"${1:image.jpg}\" alt=\"${2:description}\">", description: "Image tag"),
        .init(label: "form", insertText: "<form action=\"${1:/submit}\" method=\"${2:post}\">\n    ${3:<!-- fields -->}\n</form>", description: "Form element")
    ]

    static let css: [SnippetTemplate] = [
        .init(label: "rule", insertText: "${1:selector} {\n    ${2:property}: ${3:value};\n}", description: "CSS rule"),
        .init(label: "media", insertText: "@media (${1:min-width: 768px}) {\n    ${2:selector} {\n        ${3:property}: ${4:value};\n    }\n}", description: "Media query"),
        .init(label: "keyframes", insertText: "@keyframes ${1:name} {\n    from { ${2:property}: ${3:value}; }\n    to { ${4:property}: ${5:value}; }\n}", description: "Keyframes animation"),
        .init(label: "flex", insertText: "display: flex;\nalign-items: ${1:center};\njustify-content: ${2:center};", description: "Flex layout")
    ]

    static let xml: [SnippetTemplate] = [
        .init(label: "xml", insertText: "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<${1:root}>\n    ${2:content}\n</${1:root}>", description: "XML document"),
        .init(label: "element", insertText: "<${1:element}>${2:content}</${1:element}>", description: "XML element"),
        .init(label: "comment", insertText: "<!-- ${1:comment} -->", description: "XML comment"),
        .init(label: "cdata", insertText: "<![CDATA[\n${1:content}\n]]>", description: "CDATA block")
    ]

    static let sql: [SnippetTemplate] = [
        .init(label: "select", insertText: "SELECT ${1:columns}\nFROM ${2:table}\nWHERE ${3:condition};", description: "SELECT query"),
        .init(label: "insert", insertText: "INSERT INTO ${1:table} (${2:columns})\nVALUES (${3:values});", description: "INSERT statement"),
        .init(label: "update", insertText: "UPDATE ${1:table}\nSET ${2:column = value}\nWHERE ${3:condition};", description: "UPDATE statement"),
        .init(label: "create-table", insertText: "CREATE TABLE ${1:table} (\n    ${2:id} INTEGER PRIMARY KEY,\n    ${3:name} TEXT NOT NULL\n);", description: "CREATE TABLE statement")
    ]

    static let ruby: [SnippetTemplate] = [
        .init(label: "def", insertText: "def ${1:method_name}(${2:args})\n  ${3:# body}\nend", description: "Method definition"),
        .init(label: "class", insertText: "class ${1:ClassName}\n  ${2:# body}\nend", description: "Class definition"),
        .init(label: "module", insertText: "module ${1:ModuleName}\n  ${2:# body}\nend", description: "Module definition"),
        .init(label: "each", insertText: "${1:collection}.each do |${2:item}|\n  ${3:# body}\nend", description: "Each block")
    ]

    static let php: [SnippetTemplate] = [
        .init(label: "php", insertText: "<?php\n${1:// code}\n?>", description: "PHP block"),
        .init(label: "function", insertText: "function ${1:name}(${2:parameters}) {\n    ${3:// body}\n}", description: "Function definition"),
        .init(label: "class", insertText: "class ${1:ClassName} {\n    ${2:// body}\n}", description: "Class definition"),
        .init(label: "foreach", insertText: "foreach (${1:items} as ${2:item}) {\n    ${3:// body}\n}", description: "Foreach loop")
    ]

    static let shell: [SnippetTemplate] = [
        .init(label: "if", insertText: "if [[ ${1:condition} ]]; then\n    ${2:# body}\nfi", description: "If statement"),
        .init(label: "for", insertText: "for ${1:item} in ${2:items}; do\n    ${3:# body}\ndone", description: "For loop"),
        .init(label: "function", insertText: "${1:function_name}() {\n    ${2:# body}\n}", description: "Shell function"),
        .init(label: "case", insertText: "case ${1:value} in\n    ${2:pattern})\n        ${3:# body}\n        ;;\nesac", description: "Case statement")
    ]

    static let rust: [SnippetTemplate] = [
        .init(label: "fn", insertText: "fn ${1:name}(${2:params}) -> ${3:ReturnType} {\n    ${4:// body}\n}", description: "Function definition"),
        .init(label: "struct", insertText: "struct ${1:Name} {\n    ${2:field}: ${3:Type},\n}", description: "Struct definition"),
        .init(label: "impl", insertText: "impl ${1:Type} {\n    ${2:// methods}\n}", description: "Impl block"),
        .init(label: "match", insertText: "match ${1:value} {\n    ${2:pattern} => ${3:result},\n    _ => ${4:default},\n}", description: "Match expression")
    ]

    static let cLanguage: [SnippetTemplate] = [
        .init(label: "main", insertText: "int main(int argc, char **argv) {\n    ${1:return 0;}\n}", description: "Main function"),
        .init(label: "function", insertText: "${1:void} ${2:name}(${3:params}) {\n    ${4:// body}\n}", description: "Function definition"),
        .init(label: "include", insertText: "#include <${1:stdio.h}>", description: "Include directive"),
        .init(label: "struct", insertText: "struct ${1:Name} {\n    ${2:int field;}\n};", description: "Struct definition")
    ]

    static let dockerfile: [SnippetTemplate] = [
        .init(label: "from", insertText: "FROM ${1:image}:${2:tag}", description: "Base image"),
        .init(label: "run", insertText: "RUN ${1:command}", description: "Run command"),
        .init(label: "copy", insertText: "COPY ${1:source} ${2:destination}", description: "Copy files")
    ]
}
