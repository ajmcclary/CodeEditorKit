import Testing

@Test("target import verifier accepts the package")
func targetImports() throws {
    let result = try VerifierTestSupport.run(
        executable: "/usr/bin/python3",
        arguments: [
            VerifierTestSupport.repositoryRoot
                .appending(path: "Scripts/verify-target-imports.py")
                .path
        ]
    )
    #expect(result.status == 0, Comment(rawValue: result.output))
}
