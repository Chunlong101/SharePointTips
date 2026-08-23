using System.Net.Http.Headers;
using System.Text.Json;
using Microsoft.Extensions.Options;
using SpeAuthorizationDemo.Configuration;
using SpeAuthorizationDemo.Models;

namespace SpeAuthorizationDemo.Graph;

public interface ISpeGraphClient
{
    Task<IReadOnlyList<SpeDriveItem>> ListRootAsync(CancellationToken cancellationToken);
    Task<SpeDownload> DownloadAsync(string itemId, CancellationToken cancellationToken);
    Task<SpeDriveItem> UploadSmallFileAsync(string fileName, Stream content, long length, CancellationToken cancellationToken);
}

public sealed class SpeGraphClient(
    HttpClient httpClient,
    IGraphAccessTokenProvider tokenProvider,
    IOptions<SpeOptions> options) : ISpeGraphClient
{
    private readonly SpeOptions spe = options.Value;

    public async Task<IReadOnlyList<SpeDriveItem>> ListRootAsync(CancellationToken cancellationToken)
    {
        using var response = await SendReadWithRetryAsync(
            () => CreateRequestAsync(HttpMethod.Get, "root/children", cancellationToken),
            HttpCompletionOption.ResponseContentRead,
            cancellationToken);
        await EnsureSuccessAsync(response, cancellationToken);
        await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
        using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
        return document.RootElement.GetProperty("value").EnumerateArray()
            .Select(ParseItem)
            .ToArray();
    }

    public async Task<SpeDownload> DownloadAsync(string itemId, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(itemId)) throw new ArgumentException("Item ID is required.", nameof(itemId));
        var response = await SendReadWithRetryAsync(
            () => CreateRequestAsync(HttpMethod.Get, $"items/{Uri.EscapeDataString(itemId)}/content", cancellationToken),
            HttpCompletionOption.ResponseHeadersRead,
            cancellationToken);
        try
        {
            await EnsureSuccessAsync(response, cancellationToken);
            var name = response.Content.Headers.ContentDisposition?.FileNameStar?.Trim('"') ?? "download";
            var type = response.Content.Headers.ContentType?.MediaType ?? "application/octet-stream";
            var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
            return new SpeDownload(new ResponseOwnedStream(stream, response), name, type);
        }
        catch
        {
            response.Dispose();
            throw;
        }
    }

    public async Task<SpeDriveItem> UploadSmallFileAsync(
        string fileName,
        Stream content,
        long length,
        CancellationToken cancellationToken)
    {
        if (!FileNamePolicy.IsAllowed(fileName)) throw new ArgumentException("Unsafe file name.", nameof(fileName));
        if (!FileNamePolicy.IsAllowedLength(length, spe.MaxUploadBytes))
            throw new ArgumentOutOfRangeException(nameof(length), $"File must be between 1 and {spe.MaxUploadBytes} bytes.");

        using var request = await CreateRequestAsync(
            HttpMethod.Put,
            $"root:/{Uri.EscapeDataString(fileName)}:/content",
            cancellationToken);
        request.Content = new StreamContent(content);
        request.Content.Headers.ContentType = new MediaTypeHeaderValue("application/octet-stream");
        request.Content.Headers.ContentLength = length;
        using var response = await httpClient.SendAsync(request, cancellationToken);
        await EnsureSuccessAsync(response, cancellationToken);
        await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
        using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
        return ParseItem(document.RootElement);
    }

    private async Task<HttpRequestMessage> CreateRequestAsync(HttpMethod method, string relativePath, CancellationToken cancellationToken)
    {
        var containerId = Uri.EscapeDataString(spe.ContainerId);
        var uri = $"{spe.GraphBaseUrl.TrimEnd('/')}/v1.0/drives/{containerId}/{relativePath}";
        var request = new HttpRequestMessage(method, uri);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", await tokenProvider.GetTokenAsync(cancellationToken));
        request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
        return request;
    }

    private async Task<HttpResponseMessage> SendReadWithRetryAsync(
        Func<Task<HttpRequestMessage>> requestFactory,
        HttpCompletionOption completionOption,
        CancellationToken cancellationToken)
    {
        for (var attempt = 1; attempt <= 3; attempt++)
        {
            using var request = await requestFactory();
            var response = await httpClient.SendAsync(request, completionOption, cancellationToken);
            if ((response.StatusCode == (System.Net.HttpStatusCode)429 || (int)response.StatusCode >= 500) && attempt < 3)
            {
                response.Dispose();
                await Task.Delay(TimeSpan.FromMilliseconds(100 * attempt), cancellationToken);
                continue;
            }
            return response;
        }
        throw new InvalidOperationException("Read retry loop ended unexpectedly.");
    }

    private static SpeDriveItem ParseItem(JsonElement item) => new(
        item.GetProperty("id").GetString() ?? "",
        item.GetProperty("name").GetString() ?? "",
        item.TryGetProperty("size", out var size) ? size.GetInt64() : 0,
        item.TryGetProperty("webUrl", out var webUrl) ? webUrl.GetString() : null);

    private static async Task EnsureSuccessAsync(HttpResponseMessage response, CancellationToken cancellationToken)
    {
        if (response.IsSuccessStatusCode) return;
        var requestId = response.Headers.TryGetValues("request-id", out var values) ? values.FirstOrDefault() : null;
        var challenge = response.Headers.WwwAuthenticate.FirstOrDefault()?.ToString();
        _ = await response.Content.ReadAsStringAsync(cancellationToken);
        throw new SpeGraphException(
            $"Microsoft Graph request failed with HTTP {(int)response.StatusCode}.",
            response.StatusCode,
            requestId,
            challenge);
    }
}

file sealed class ResponseOwnedStream(Stream inner, HttpResponseMessage owner) : Stream
{
    public override bool CanRead => inner.CanRead;
    public override bool CanSeek => inner.CanSeek;
    public override bool CanWrite => false;
    public override long Length => inner.Length;
    public override long Position { get => inner.Position; set => inner.Position = value; }
    public override void Flush() => inner.Flush();
    public override int Read(byte[] buffer, int offset, int count) => inner.Read(buffer, offset, count);
    public override long Seek(long offset, SeekOrigin origin) => inner.Seek(offset, origin);
    public override void SetLength(long value) => throw new NotSupportedException();
    public override void Write(byte[] buffer, int offset, int count) => throw new NotSupportedException();
    public override Task<int> ReadAsync(byte[] buffer, int offset, int count, CancellationToken cancellationToken) => inner.ReadAsync(buffer, offset, count, cancellationToken);
    public override ValueTask<int> ReadAsync(Memory<byte> buffer, CancellationToken cancellationToken = default) => inner.ReadAsync(buffer, cancellationToken);
    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            inner.Dispose();
            owner.Dispose();
        }
        base.Dispose(disposing);
    }
    public override async ValueTask DisposeAsync()
    {
        await inner.DisposeAsync();
        owner.Dispose();
        GC.SuppressFinalize(this);
    }
}
