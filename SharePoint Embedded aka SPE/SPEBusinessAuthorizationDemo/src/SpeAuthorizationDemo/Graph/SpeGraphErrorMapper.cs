using System.Net;

namespace SpeAuthorizationDemo.Graph;

public static class SpeGraphErrorMapper
{
    public static string ToReasonCode(SpeGraphException exception) => exception.StatusCode switch
    {
        HttpStatusCode.Forbidden => "container_permission_denied",
        HttpStatusCode.Unauthorized => "reauthentication_required",
        HttpStatusCode.TooManyRequests => "graph_temporarily_unavailable",
        >= HttpStatusCode.InternalServerError => "graph_temporarily_unavailable",
        _ => "graph_request_failed"
    };
}
