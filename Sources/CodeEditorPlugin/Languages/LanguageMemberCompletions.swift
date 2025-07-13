import Foundation

// MARK: - Python Member Completions

public struct PythonMemberCompletions: LanguageMemberCompletions {
    public func createMemberCompletions(for targetType: String?, filter: String) -> [CompletionItemModel] {
        guard let targetType else { return [] }
        
        switch targetType.lowercased() {
        case "str", "string":
            return createStringMemberCompletions(filter: filter)

        case "list":
            return createListMemberCompletions(filter: filter)

        case "dict", "dictionary":
            return createDictMemberCompletions(filter: filter)

        case "set":
            return createSetMemberCompletions(filter: filter)

        default:
            return createCommonMemberCompletions(filter: filter)
        }
    }
    
    private func createStringMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("upper()", "method", "Return uppercase string"),
            ("lower()", "method", "Return lowercase string"),
            ("capitalize()", "method", "Return capitalized string"),
            ("title()", "method", "Return title cased string"),
            ("strip()", "method", "Remove leading and trailing whitespace"),
            ("split()", "method", "Split string into list"),
            ("join()", "method", "Join iterable into string"),
            ("replace()", "method", "Replace substring"),
            ("find()", "method", "Find substring position"),
            ("startswith()", "method", "Check if starts with substring"),
            ("endswith()", "method", "Check if ends with substring"),
            ("format()", "method", "Format string"),
            ("encode()", "method", "Encode string to bytes"),
            ("isdigit()", "method", "Check if all characters are digits"),
            ("isalpha()", "method", "Check if all characters are alphabetic")
        ]
        return SharedCompletionBuilder.createMemberItems(from: members, filter: filter)
    }
    
    private func createListMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("append()", "method", "Add element to end"),
            ("extend()", "method", "Extend list by appending elements"),
            ("insert()", "method", "Insert element at index"),
            ("remove()", "method", "Remove first occurrence of value"),
            ("pop()", "method", "Remove and return element"),
            ("clear()", "method", "Remove all elements"),
            ("index()", "method", "Return index of first occurrence"),
            ("count()", "method", "Count occurrences of value"),
            ("sort()", "method", "Sort list in place"),
            ("reverse()", "method", "Reverse list in place"),
            ("copy()", "method", "Return shallow copy")
        ]
        return SharedCompletionBuilder.createMemberItems(from: members, filter: filter)
    }
    
    private func createDictMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("get()", "method", "Get value for key with default"),
            ("keys()", "method", "Return dict keys"),
            ("values()", "method", "Return dict values"),
            ("items()", "method", "Return dict items"),
            ("update()", "method", "Update dict with key-value pairs"),
            ("pop()", "method", "Remove and return value for key"),
            ("popitem()", "method", "Remove and return last item"),
            ("clear()", "method", "Remove all items"),
            ("copy()", "method", "Return shallow copy"),
            ("setdefault()", "method", "Set default value for key")
        ]
        return SharedCompletionBuilder.createMemberItems(from: members, filter: filter)
    }
    
    private func createSetMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("add()", "method", "Add element to set"),
            ("remove()", "method", "Remove element (raises error if not found)"),
            ("discard()", "method", "Remove element (no error if not found)"),
            ("pop()", "method", "Remove and return arbitrary element"),
            ("clear()", "method", "Remove all elements"),
            ("union()", "method", "Return union of sets"),
            ("intersection()", "method", "Return intersection of sets"),
            ("difference()", "method", "Return difference of sets"),
            ("symmetric_difference()", "method", "Return symmetric difference"),
            ("issubset()", "method", "Check if subset"),
            ("issuperset()", "method", "Check if superset"),
            ("copy()", "method", "Return shallow copy")
        ]
        return SharedCompletionBuilder.createMemberItems(from: members, filter: filter)
    }
    
    private func createCommonMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("__str__()", "method", "String representation"),
            ("__repr__()", "method", "Developer representation"),
            ("__len__()", "method", "Length of object"),
            ("__class__", "property", "Class of instance"),
            ("__dict__", "property", "Instance dictionary"),
            ("__doc__", "property", "Documentation string")
        ]
        return SharedCompletionBuilder.createMemberItems(from: members, filter: filter)
    }
}

// MARK: - JavaScript Member Completions

public struct JavaScriptMemberCompletions: LanguageMemberCompletions {
    public func createMemberCompletions(for targetType: String?, filter: String) -> [CompletionItemModel] {
        guard let targetType else { return [] }
        
        switch targetType.lowercased() {
        case "console":
            return createConsoleMemberCompletions(filter: filter)

        case "array":
            return createArrayMemberCompletions(filter: filter)

        case "string":
            return createStringMemberCompletions(filter: filter)

        case "object":
            return createObjectMemberCompletions(filter: filter)

        case "promise":
            return createPromiseMemberCompletions(filter: filter)

        case "math":
            return createMathMemberCompletions(filter: filter)

        default:
            return createCommonMemberCompletions(filter: filter)
        }
    }
    
    private func createConsoleMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("log()", "method", "Log message to console"),
            ("error()", "method", "Log error message"),
            ("warn()", "method", "Log warning message"),
            ("info()", "method", "Log info message"),
            ("debug()", "method", "Log debug message"),
            ("table()", "method", "Display data as table"),
            ("time()", "method", "Start timer"),
            ("timeEnd()", "method", "End timer and log time"),
            ("clear()", "method", "Clear console"),
            ("group()", "method", "Create inline group"),
            ("groupEnd()", "method", "End inline group"),
            ("assert()", "method", "Assert condition")
        ]
        return SharedCompletionBuilder.createMemberItems(from: members, filter: filter)
    }
    
    private func createArrayMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("length", "property", "Number of elements"),
            ("push()", "method", "Add elements to end"),
            ("pop()", "method", "Remove last element"),
            ("shift()", "method", "Remove first element"),
            ("unshift()", "method", "Add elements to beginning"),
            ("slice()", "method", "Extract section of array"),
            ("splice()", "method", "Add/remove elements"),
            ("concat()", "method", "Merge arrays"),
            ("join()", "method", "Join elements into string"),
            ("reverse()", "method", "Reverse array in place"),
            ("sort()", "method", "Sort array in place"),
            ("filter()", "method", "Filter elements"),
            ("map()", "method", "Transform elements"),
            ("reduce()", "method", "Reduce to single value"),
            ("forEach()", "method", "Execute function for each element"),
            ("find()", "method", "Find first matching element"),
            ("findIndex()", "method", "Find first matching index"),
            ("includes()", "method", "Check if includes value"),
            ("indexOf()", "method", "Find index of value"),
            ("every()", "method", "Test if all elements pass"),
            ("some()", "method", "Test if any element passes")
        ]
        return SharedCompletionBuilder.createMemberItems(from: members, filter: filter)
    }
    
    private func createStringMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("length", "property", "Number of characters"),
            ("charAt()", "method", "Character at index"),
            ("charCodeAt()", "method", "Unicode of character"),
            ("concat()", "method", "Concatenate strings"),
            ("includes()", "method", "Check if contains substring"),
            ("indexOf()", "method", "Find index of substring"),
            ("lastIndexOf()", "method", "Find last index of substring"),
            ("match()", "method", "Match against regex"),
            ("replace()", "method", "Replace substring"),
            ("search()", "method", "Search for match"),
            ("slice()", "method", "Extract section"),
            ("split()", "method", "Split into array"),
            ("substring()", "method", "Extract substring"),
            ("toLowerCase()", "method", "Convert to lowercase"),
            ("toUpperCase()", "method", "Convert to uppercase"),
            ("trim()", "method", "Remove whitespace"),
            ("trimStart()", "method", "Remove leading whitespace"),
            ("trimEnd()", "method", "Remove trailing whitespace"),
            ("padStart()", "method", "Pad start of string"),
            ("padEnd()", "method", "Pad end of string"),
            ("repeat()", "method", "Repeat string")
        ]
        return SharedCompletionBuilder.createMemberItems(from: members, filter: filter)
    }
    
    private func createObjectMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("assign()", "method", "Copy properties"),
            ("create()", "method", "Create new object"),
            ("defineProperty()", "method", "Define property"),
            ("defineProperties()", "method", "Define properties"),
            ("entries()", "method", "Get [key, value] pairs"),
            ("freeze()", "method", "Freeze object"),
            ("fromEntries()", "method", "Create from entries"),
            ("getOwnPropertyDescriptor()", "method", "Get property descriptor"),
            ("getOwnPropertyNames()", "method", "Get property names"),
            ("getPrototypeOf()", "method", "Get prototype"),
            ("hasOwnProperty()", "method", "Check own property"),
            ("is()", "method", "Check if same value"),
            ("isExtensible()", "method", "Check if extensible"),
            ("isFrozen()", "method", "Check if frozen"),
            ("isSealed()", "method", "Check if sealed"),
            ("keys()", "method", "Get keys"),
            ("seal()", "method", "Seal object"),
            ("values()", "method", "Get values")
        ]
        return SharedCompletionBuilder.createMemberItems(from: members, filter: filter)
    }
    
    private func createPromiseMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("then()", "method", "Handle resolved value"),
            ("catch()", "method", "Handle rejection"),
            ("finally()", "method", "Execute after settlement"),
            ("all()", "method", "Wait for all promises"),
            ("allSettled()", "method", "Wait for all settlements"),
            ("any()", "method", "First fulfilled promise"),
            ("race()", "method", "First settled promise"),
            ("reject()", "method", "Create rejected promise"),
            ("resolve()", "method", "Create resolved promise")
        ]
        return SharedCompletionBuilder.createMemberItems(from: members, filter: filter)
    }
    
    private func createMathMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("PI", "property", "Pi constant"),
            ("E", "property", "Euler's constant"),
            ("abs()", "method", "Absolute value"),
            ("ceil()", "method", "Round up"),
            ("floor()", "method", "Round down"),
            ("round()", "method", "Round to nearest"),
            ("max()", "method", "Maximum value"),
            ("min()", "method", "Minimum value"),
            ("pow()", "method", "Power"),
            ("sqrt()", "method", "Square root"),
            ("random()", "method", "Random number"),
            ("sin()", "method", "Sine"),
            ("cos()", "method", "Cosine"),
            ("tan()", "method", "Tangent"),
            ("log()", "method", "Natural logarithm")
        ]
        return SharedCompletionBuilder.createMemberItems(from: members, filter: filter)
    }
    
    private func createCommonMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("toString()", "method", "Convert to string"),
            ("valueOf()", "method", "Primitive value"),
            ("constructor", "property", "Constructor function"),
            ("hasOwnProperty()", "method", "Check own property")
        ]
        return SharedCompletionBuilder.createMemberItems(from: members, filter: filter)
    }
}

// MARK: - Rust Member Completions

public struct RustMemberCompletions: LanguageMemberCompletions {
    public func createMemberCompletions(for targetType: String?, filter: String) -> [CompletionItemModel] {
        guard let targetType else { return [] }
        
        switch targetType.lowercased() {
        case "string", "str":
            return createStringMemberCompletions(filter: filter)

        case "vec":
            return createVecMemberCompletions(filter: filter)

        case "option":
            return createOptionMemberCompletions(filter: filter)

        case "result":
            return createResultMemberCompletions(filter: filter)

        case "std":
            return createStdModuleCompletions(filter: filter)

        default:
            return createCommonMemberCompletions(filter: filter)
        }
    }
    
    private func createStringMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("len()", "method", "Get string length"),
            ("is_empty()", "method", "Check if empty"),
            ("chars()", "method", "Iterator over chars"),
            ("bytes()", "method", "Iterator over bytes"),
            ("contains()", "method", "Check substring"),
            ("starts_with()", "method", "Check prefix"),
            ("ends_with()", "method", "Check suffix"),
            ("find()", "method", "Find substring"),
            ("replace()", "method", "Replace substring"),
            ("trim()", "method", "Trim whitespace"),
            ("to_lowercase()", "method", "Convert to lowercase"),
            ("to_uppercase()", "method", "Convert to uppercase"),
            ("split()", "method", "Split string"),
            ("lines()", "method", "Iterator over lines"),
            ("parse()", "method", "Parse string")
        ]
        return SharedCompletionBuilder.createMemberItems(from: members, filter: filter)
    }
    
    private func createVecMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("len()", "method", "Get vector length"),
            ("is_empty()", "method", "Check if empty"),
            ("push()", "method", "Add element"),
            ("pop()", "method", "Remove last element"),
            ("insert()", "method", "Insert at index"),
            ("remove()", "method", "Remove at index"),
            ("clear()", "method", "Remove all elements"),
            ("get()", "method", "Get element option"),
            ("first()", "method", "Get first element"),
            ("last()", "method", "Get last element"),
            ("iter()", "method", "Get iterator"),
            ("iter_mut()", "method", "Get mutable iterator"),
            ("sort()", "method", "Sort elements"),
            ("reverse()", "method", "Reverse elements"),
            ("contains()", "method", "Check if contains")
        ]
        return SharedCompletionBuilder.createMemberItems(from: members, filter: filter)
    }
    
    private func createOptionMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("is_some()", "method", "Check if Some"),
            ("is_none()", "method", "Check if None"),
            ("unwrap()", "method", "Extract value or panic"),
            ("unwrap_or()", "method", "Extract or default"),
            ("unwrap_or_else()", "method", "Extract or compute"),
            ("map()", "method", "Transform value"),
            ("and_then()", "method", "Chain operations"),
            ("or()", "method", "Provide alternative"),
            ("or_else()", "method", "Compute alternative"),
            ("filter()", "method", "Filter by predicate"),
            ("take()", "method", "Take ownership"),
            ("as_ref()", "method", "Convert to reference"),
            ("as_mut()", "method", "Convert to mutable ref"),
            ("ok_or()", "method", "Convert to Result"),
            ("expect()", "method", "Extract with message")
        ]
        return SharedCompletionBuilder.createMemberItems(from: members, filter: filter)
    }
    
    private func createResultMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("is_ok()", "method", "Check if Ok"),
            ("is_err()", "method", "Check if Err"),
            ("ok()", "method", "Convert to Option"),
            ("err()", "method", "Get error as Option"),
            ("unwrap()", "method", "Extract value or panic"),
            ("unwrap_or()", "method", "Extract or default"),
            ("unwrap_or_else()", "method", "Extract or compute"),
            ("expect()", "method", "Extract with message"),
            ("map()", "method", "Transform Ok value"),
            ("map_err()", "method", "Transform Err value"),
            ("and_then()", "method", "Chain operations"),
            ("or()", "method", "Provide alternative"),
            ("or_else()", "method", "Compute alternative"),
            ("as_ref()", "method", "Convert to reference"),
            ("as_mut()", "method", "Convert to mutable ref")
        ]
        return SharedCompletionBuilder.createMemberItems(from: members, filter: filter)
    }
    
    private func createStdModuleCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("io", "module", "I/O operations"),
            ("fs", "module", "File system"),
            ("path", "module", "Path operations"),
            ("env", "module", "Environment"),
            ("process", "module", "Process control"),
            ("thread", "module", "Threading"),
            ("sync", "module", "Synchronization"),
            ("time", "module", "Time operations"),
            ("collections", "module", "Collections"),
            ("vec", "module", "Vector module"),
            ("string", "module", "String module"),
            ("fmt", "module", "Formatting"),
            ("error", "module", "Error handling"),
            ("mem", "module", "Memory operations")
        ]
        return SharedCompletionBuilder.createMemberItems(from: members, filter: filter)
    }
    
    private func createCommonMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("clone()", "method", "Clone value"),
            ("to_string()", "method", "Convert to String"),
            ("fmt()", "method", "Format value"),
            ("eq()", "method", "Equality check"),
            ("cmp()", "method", "Ordering comparison"),
            ("hash()", "method", "Hash value")
        ]
        return SharedCompletionBuilder.createMemberItems(from: members, filter: filter)
    }
}
