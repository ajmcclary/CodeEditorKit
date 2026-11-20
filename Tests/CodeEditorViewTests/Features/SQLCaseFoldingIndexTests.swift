import CodeEditorLanguages
import Foundation
import XCTest

/// The SQL providers locate keywords case-insensitively. Upper-casing a
/// string can change its length (`և` → `ԵՒ`, `ﬁ` → `FI`, `ı` → `I`, `ǰ` and
/// `ΐ` gain combining scalars), so an index found in `text.uppercased()` is
/// not an index into `text`. These tests pin that keyword search and slicing
/// use the same string: non-ASCII text before or inside the sliced region
/// neither traps nor shifts the extracted names.
final class SQLCaseFoldingIndexTests: XCTestCase {
    private func selectSymbolName(_ sql: String) async -> String? {
        await SQLSymbolProvider().detectSymbols(in: sql).first?.name
    }

    // MARK: - SELECT ... FROM (symbol provider)

    func testSelectWithLengtheningUppercaseBeforeFromDoesNotTrap() async {
        // 'և' upper-cases to two characters; 'ΐ' to three scalars.
        let first = await selectSymbolName("SELECT 'և' FROM t")
        XCTAssertEqual(first, "SELECT from t")
        let second = await selectSymbolName("SELECT 'ΐ' FROM t")
        XCTAssertEqual(second, "SELECT from t")
    }

    func testSelectWithCombiningUppercaseBeforeFromFindsTheTable() async {
        // 'ǰ' upper-cases to J + U+030C; this used to yield an empty table list.
        let name = await selectSymbolName("SELECT 'ǰ' FROM t")
        XCTAssertEqual(name, "SELECT from t")
    }

    func testSelectWithShorteningUppercaseBeforeFromIsNotShifted() async {
        // 'ı' (2 UTF-8 bytes) → 'I' (1); 'ﬁ' (3) → "FI" (2).
        let dotless = await selectSymbolName("SELECT 'ıııı' FROM users")
        XCTAssertEqual(dotless, "SELECT from users")
        let ligature = await selectSymbolName("SELECT 'ﬁﬁﬁﬁ' FROM users, orders")
        XCTAssertEqual(ligature, "SELECT from users, orders")
    }

    func testStopKeywordAfterNonASCIITableNameIsNotShifted() async {
        let shorter = await selectSymbolName("SELECT x FROM users_ıııı WHERE y = 1")
        XCTAssertEqual(shorter, "SELECT from users_ıııı")
        let longer = await selectSymbolName("SELECT x FROM և_tab, b ORDER BY x")
        XCTAssertEqual(longer, "SELECT from և_tab, b")
    }

    // MARK: - Keyword object names (shared utility)

    func testObjectNameAfterLengtheningUppercaseIsExact() {
        let name = SQLParsingUtility.extractObjectName(
            from: "/* և ΐ */ CREATE TABLE users (id INT)",
            afterKeyword: "CREATE TABLE"
        )
        XCTAssertEqual(name, "users")
    }

    func testObjectNameAfterShorteningUppercaseIsExact() {
        let name = SQLParsingUtility.extractObjectName(
            from: "/* ıııı ﬁﬁﬁﬁ */ CREATE VIEW active_users AS SELECT 1",
            afterKeyword: "CREATE VIEW"
        )
        XCTAssertEqual(name, "active_users")
    }

    func testObjectNameAtEndOfStatementAfterLengtheningUppercaseDoesNotTrap() {
        let name = SQLParsingUtility.extractObjectName(from: "'ևևևև' INSERT INTO t", afterKeyword: "insert into")
        XCTAssertEqual(name, "t")
    }

    // MARK: - Folding provider (reaches the shared utility)

    func testInsertFoldTitleAfterNonASCIITextNamesTheTable() async {
        let sql = """
        INSERT /* ıııı ﬁﬁﬁﬁ
        legacy */
        INSERT INTO target_table
        VALUES (1),
        (2)
        """
        let regions = await SQLFoldingProvider().detectFoldableRegions(in: sql)
        XCTAssertEqual(regions.map(\.title), ["INSERT into target_table"])
    }

    // MARK: - ASCII regressions

    func testASCIISelectTablesAreUnchanged() async {
        let upper = await selectSymbolName("SELECT a, b FROM users, orders WHERE x = 1")
        XCTAssertEqual(upper, "SELECT from users, orders")
        let lower = await selectSymbolName("select * from users order by id")
        XCTAssertEqual(lower, "SELECT from users")
        let limited = await selectSymbolName("SELECT 1 FROM t LIMIT 5")
        XCTAssertEqual(limited, "SELECT from t")
        let noFrom = await selectSymbolName("SELECT 1")
        XCTAssertEqual(noFrom, "SELECT from unknown")
    }

    func testASCIIObjectNamesAreUnchanged() async {
        let symbols = await SQLSymbolProvider().detectSymbols(in: """
        CREATE TABLE users (id INT);
        create table Accounts(id int);
        CREATE INDEX idx_users ON users(id);
        INSERT INTO users VALUES (1);
        UPDATE users SET id = 2;
        DELETE FROM users WHERE id = 2;
        ALTER TABLE users ADD COLUMN name TEXT;
        """)
        XCTAssertEqual(symbols.map(\.name), [
            "TABLE users",
            "TABLE Accounts",
            "INDEX idx_users",
            "INSERT into users",
            "UPDATE users",
            "DELETE from users",
            "ALTER TABLE users"
        ])
        XCTAssertNil(SQLParsingUtility.extractObjectName(from: "SELECT 1", afterKeyword: "CREATE TABLE"))
    }
}
