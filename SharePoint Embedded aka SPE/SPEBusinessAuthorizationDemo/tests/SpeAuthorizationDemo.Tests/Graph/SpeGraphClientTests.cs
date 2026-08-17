using System.Net;
using System.Net.Http.Headers;
using System.Text;
using Microsoft.Extensions.Options;
using SpeAuthorizationDemo.Configuration;
using SpeAuthorizationDemo.Graph;

namespace SpeAuthorizationDemo.Tests.Graph;

public sealed class SpeGraphClientTests
{
    [Fact]
    public async Task ListRootAsync_UsesConfiguredChinaContainerAndBearerToken()
    {
        var handler = new RecordingHandler(_ => new HttpResponseMessage(HttpStatusCode.OK)
        {
            Content = new StringContent("{\"value\":[{\"id\":\"1\",\"name\":\"report.docx\",\"size\":12}]}", Encoding.UTF8, "application/json")
        });
        var client = Create(handler);

        var items = await client.ListRootAsync(CancellationToken.None);

        Assert.Single(items);
        Assert.Equal("report.docx", items[0].Name);
        Assert.Equal("https://microsoftgraph.chinacloudapi.cn/v1.0/drives/b%21configured/root/children", handler.LastRequest!.RequestUri!.AbsoluteUri);
        Assert.Equal(new AuthenticationHeaderValue("Bearer", "test-token"), handler.LastRequest.Headers.Authorization);
    }

    [Fact]
    public async Task UploadSmallFileAsync_RejectsUnsafeNameBeforeSendingRequest()
    {
        var handler = new RecordingHandler(_ => throw new InvalidOperationException("HTTP must not be called"));
        var client = Create(handler);
        await using var content = new MemoryStream([1, 2, 3]);

        await Assert.ThrowsAsync<ArgumentException>(() =>
            client.UploadSmallFileAsync("../secret.txt", content, 3, CancellationToken.None));
        Assert.Null(handler.LastRequest);
    }

    [Fact]
    public async Task UploadSmallFileAsync_RejectsOversizeBeforeSendingRequest()
    {
        var handler = new RecordingHandler(_ => throw new InvalidOperationException("HTTP must not be called"));
        var client = Create(handler);
        await using var content = new MemoryStream([1]);

        await Assert.ThrowsAsync<ArgumentOutOfRangeException>(() =>
            client.UploadSmallFileAsync("file.txt", content, 4_000_001, CancellationToken.None));
        Assert.Null(handler.LastRequest);
    }

    [Fact]
    public async Task ListRootAsync_MapsForbiddenWithoutLeakingResponseBody()
    {
        var handler = new RecordingHandler(_ => new HttpResponseMessage(HttpStatusCode.Forbidden)
        {
            Content = new StringContent("secret diagnostic body")
        });
        var client = Create(handler);

        var exception = await Assert.ThrowsAsync<SpeGraphException>(() => client.ListRootAsync(CancellationToken.None));

        Assert.Equal(HttpStatusCode.Forbidden, exception.StatusCode);
        Assert.DoesNotContain("secret diagnostic body", exception.Message);
    }

    [Fact]
    public async Task ListRootAsync_RetriesTransientReadFailures()
    {
        var attempts = 0;
        var handler = new RecordingHandler(_ =>
        {
            attempts++;
            return attempts < 3
                ? new HttpResponseMessage(HttpStatusCode.TooManyRequests)
                : new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = new StringContent("{\"value\":[]}", Encoding.UTF8, "application/json")
                };
        });

        var items = await Create(handler).ListRootAsync(CancellationToken.None);

        Assert.Empty(items);
        Assert.Equal(3, attempts);
    }

    [Fact]
    public async Task UploadSmallFileAsync_DoesNotRetryTransientFailure()
    {
        var attempts = 0;
        var handler = new RecordingHandler(_ =>
        {
            attempts++;
            return new HttpResponseMessage(HttpStatusCode.ServiceUnavailable);
        });
        await using var content = new MemoryStream([1]);

        await Assert.ThrowsAsync<SpeGraphException>(() =>
            Create(handler).UploadSmallFileAsync("file.txt", content, 1, CancellationToken.None));
        Assert.Equal(1, attempts);
    }

    [Fact]
    public async Task ListRootAsync_PreservesClaimsChallenge()
    {
        var response = new HttpResponseMessage(HttpStatusCode.Unauthorized);
        response.Headers.WwwAuthenticate.ParseAdd("Bearer claims=\"challenge-value\"");
        var handler = new RecordingHandler(_ => response);

        var exception = await Assert.ThrowsAsync<SpeGraphException>(() =>
            Create(handler).ListRootAsync(CancellationToken.None));

        Assert.Contains("claims=", exception.ClaimsChallenge);
    }

    private static SpeGraphClient Create(HttpMessageHandler handler) => new(
        new HttpClient(handler),
        new StaticTokenProvider(),
        Options.Create(new SpeOptions
        {
            ContainerId = "b!configured",
            GraphBaseUrl = "https://microsoftgraph.chinacloudapi.cn",
            MaxUploadBytes = 4_000_000
        }));

    private sealed class StaticTokenProvider : IGraphAccessTokenProvider
    {
        public Task<string> GetTokenAsync(CancellationToken cancellationToken) => Task.FromResult("test-token");
    }

    private sealed class RecordingHandler(Func<HttpRequestMessage, HttpResponseMessage> response) : HttpMessageHandler
    {
        public HttpRequestMessage? LastRequest { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            LastRequest = request;
            return Task.FromResult(response(request));
        }
    }
}
