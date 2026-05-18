import CodeEditorLanguages
@testable import CodeEditorPlugin
@testable import CodeEditorView
import Foundation
import XCTest

/// Verifies that the dedicated folding providers added for Dockerfile, TOML,
/// and Lua actually produce regions. Pure presence checks in
/// `FeatureBehaviorTests` don't catch the M3-era regression where a provider
/// was registered but always returned `[]` — these tests do.
@MainActor
final class FoldingProviderOutputTests: XCTestCase {
    // MARK: - Dockerfile

    func testDockerfileBackslashContinuationFolds() async {
        let source = """
        FROM ubuntu:22.04
        RUN apt-get update && \\
            apt-get install -y curl && \\
            apt-get clean
        LABEL key=value
        """
        let regions = await DockerfileFoldingProvider().detectFoldableRegions(in: source)
        XCTAssertEqual(regions.count, 1, "RUN \\ continuation should fold to one region")
        XCTAssertEqual(regions.first?.title, "RUN")
        XCTAssertEqual(regions.first?.type, .block)
    }

    func testDockerfileHeredocFolds() async {
        let source = """
        FROM ubuntu
        RUN cat > /etc/foo <<EOF
        hello
        world
        EOF
        LABEL k=v
        """
        let regions = await DockerfileFoldingProvider().detectFoldableRegions(in: source)
        XCTAssertEqual(regions.count, 1, "Heredoc body should fold to one region")
        XCTAssertEqual(regions.first?.title, "<<EOF")
        XCTAssertEqual(regions.first?.type, .block)
    }

    func testDockerfileWithoutFoldableConstructsProducesNoRegions() async {
        let source = """
        FROM ubuntu
        WORKDIR /app
        COPY . .
        CMD ["./run"]
        """
        let regions = await DockerfileFoldingProvider().detectFoldableRegions(in: source)
        XCTAssertTrue(regions.isEmpty, "No backslash runs or heredocs → no folds")
    }

    // MARK: - TOML

    func testTomlSectionsFold() async {
        let source = """
        [server]
        host = "localhost"
        port = 8080

        [database]
        url = "postgres://"
        pool = 5
        """
        let regions = await TomlFoldingProvider().detectFoldableRegions(in: source)
        XCTAssertEqual(regions.count, 2, "Two `[section]` headers → two folds")
        XCTAssertEqual(regions.map(\.title), ["[server]", "[database]"])
        for region in regions {
            XCTAssertEqual(region.type, .block)
        }
    }

    func testTomlArrayOfTablesClosesAtNextHeader() async {
        let source = """
        [[products]]
        name = "hammer"
        sku = 738594937

        [[products]]
        name = "nail"
        sku = 284758393

        [other]
        key = "value"
        """
        let regions = await TomlFoldingProvider().detectFoldableRegions(in: source)
        XCTAssertEqual(regions.count, 3, "Two array-of-tables plus one section → three folds")
        XCTAssertEqual(regions.map(\.title), ["[[products]]", "[[products]]", "[other]"])
    }

    func testTomlHeaderInsideMultilineStringIsIgnored() async {
        let source = """
        [config]
        body = \"\"\"
        [not-a-section]
        still string
        \"\"\"
        [next]
        key = 1
        """
        let regions = await TomlFoldingProvider().detectFoldableRegions(in: source)
        XCTAssertEqual(regions.count, 2, "Multi-line string contents must not be parsed as headers")
        XCTAssertEqual(regions.map(\.title), ["[config]", "[next]"])
    }

    // MARK: - Lua

    func testLuaFunctionFolds() async {
        let source = """
        function greet(name)
          print("hi", name)
          return name
        end
        """
        let regions = await LuaFoldingProvider().detectFoldableRegions(in: source)
        XCTAssertEqual(regions.count, 1, "function ... end → one region")
        XCTAssertEqual(regions.first?.type, .function)
        XCTAssertEqual(regions.first?.title, "function greet")
    }

    func testLuaNestedForAndIfFold() async {
        let source = """
        for i = 1, 10 do
          if i > 5 then
            print(i)
          end
        end
        """
        let regions = await LuaFoldingProvider().detectFoldableRegions(in: source)
        XCTAssertEqual(regions.count, 2, "Nested for + if → two regions")
        // The inner `if` closes first, then the outer `for`.
        XCTAssertEqual(regions.map(\.title), ["if", "for"])
    }

    func testLuaRepeatUntilFolds() async {
        let source = """
        repeat
          step()
          step()
        until done
        """
        let regions = await LuaFoldingProvider().detectFoldableRegions(in: source)
        XCTAssertEqual(regions.count, 1, "repeat ... until → one region")
        XCTAssertEqual(regions.first?.title, "repeat")
    }

    func testLuaEndInsideBlockCommentDoesNotClose() async {
        let source = """
        function f()
          --[[ end ]]
          print()
        end
        """
        let regions = await LuaFoldingProvider().detectFoldableRegions(in: source)
        XCTAssertEqual(regions.count, 1, "The `end` inside --[[ ... ]] must not close the function")
        XCTAssertEqual(regions.first?.type, .function)
        XCTAssertEqual(regions.first?.title, "function f")
    }

    func testLuaEndInsideLongStringDoesNotClose() async {
        let source = """
        function f()
          local s = [[
        end
        ]]
          return s
        end
        """
        let regions = await LuaFoldingProvider().detectFoldableRegions(in: source)
        XCTAssertEqual(regions.count, 1, "The `end` inside [[ ... ]] long string must not close the function")
        XCTAssertEqual(regions.first?.type, .function)
    }
}
