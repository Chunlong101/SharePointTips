namespace SpeAuthorizationDemo.Graph;

public sealed class SpeDeletePreconditionException()
    : InvalidOperationException("The file cannot be deleted because its concurrency metadata is unavailable.");