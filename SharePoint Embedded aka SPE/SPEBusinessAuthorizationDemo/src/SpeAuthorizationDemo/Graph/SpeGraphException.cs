using System.Net;

namespace SpeAuthorizationDemo.Graph;

public sealed class SpeGraphException(
    string message,
    HttpStatusCode statusCode,
    string? requestId = null,
    string? claimsChallenge = null) : Exception(message)
{
    public HttpStatusCode StatusCode { get; } = statusCode;
    public string? RequestId { get; } = requestId;
    public string? ClaimsChallenge { get; } = claimsChallenge;
}
