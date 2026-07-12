import Testing

@Test("all code-quality findings have structural evidence")
func architectureRemediation() throws {
    let result = try VerifierTestSupport.run(
        executable: "/usr/bin/python3",
        arguments: [
            VerifierTestSupport.repositoryRoot
                .appending(path: "Scripts/verify-architecture-remediation.py")
                .path
        ]
    )
    #expect(result.status == 0, Comment(rawValue: result.output))
}
