using System.Net;
using SpeAuthorizationDemo.Graph;

namespace SpeAuthorizationDemo.Tests.Graph;

public sealed class SpeGraphErrorMapperTests
{
    [Theory]
    [InlineData(HttpStatusCode.Forbidden, "container_permission_denied")]
    [InlineData(HttpStatusCode.Unauthorized, "reauthentication_required")]
    [InlineData(HttpStatusCode.TooManyRequests, "graph_temporarily_unavailable")]
    [InlineData(HttpStatusCode.InternalServerError, "graph_temporarily_unavailable")]
    [InlineData(HttpStatusCode.BadRequest, "graph_request_failed")]
    public void ToReasonCode_MapsGraphStatusWithoutExposingDetails(HttpStatusCode status, string expected)
    {
        var exception = new SpeGraphException("sensitive upstream detail", status, "request-id");

        Assert.Equal(expected, SpeGraphErrorMapper.ToReasonCode(exception));
    }
}
