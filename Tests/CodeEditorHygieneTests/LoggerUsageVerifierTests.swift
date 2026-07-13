import Testing

@Test("production loggers use canonical identities")
func loggerUsage() throws {
    let result = try VerifierTestSupport.run(
        executable: "/usr/bin/python3",
        arguments: [
            VerifierTestSupport.repositoryRoot
                .appending(path: "Scripts/verify-logger-usage.py")
                .path
        ]
    )
    #expect(result.status == 0, Comment(rawValue: result.output))
}
