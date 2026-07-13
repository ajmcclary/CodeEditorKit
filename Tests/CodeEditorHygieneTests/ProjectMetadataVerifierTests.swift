import Testing

@Test("project metadata matches the package graph")
func projectMetadata() throws {
    let result = try VerifierTestSupport.run(
        executable: "/usr/bin/python3",
        arguments: [
            VerifierTestSupport.repositoryRoot
                .appending(path: "Scripts/verify-project-metadata.py")
                .path
        ]
    )
    #expect(result.status == 0, Comment(rawValue: result.output))
}
