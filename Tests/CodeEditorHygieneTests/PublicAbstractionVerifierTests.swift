import Testing

@Test("removed public abstractions do not return")
func publicAbstractions() throws {
    let result = try VerifierTestSupport.run(
        executable: "/usr/bin/python3",
        arguments: [
            VerifierTestSupport.repositoryRoot
                .appending(path: "Scripts/verify-public-abstractions.py")
                .path
        ]
    )
    #expect(result.status == 0, Comment(rawValue: result.output))
}
