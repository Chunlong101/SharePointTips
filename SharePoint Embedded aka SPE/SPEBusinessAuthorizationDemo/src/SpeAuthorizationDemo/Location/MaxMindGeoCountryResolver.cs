using System.Net;
using MaxMind.GeoIP2;
using Microsoft.Extensions.Options;
using SpeAuthorizationDemo.Configuration;

namespace SpeAuthorizationDemo.Location;

public sealed class MaxMindGeoCountryResolver : IGeoCountryResolver, IDisposable
{
    private readonly DatabaseReader? reader;
    private readonly ILogger<MaxMindGeoCountryResolver> logger;

    public MaxMindGeoCountryResolver(IOptions<LocationPolicyOptions> options, ILogger<MaxMindGeoCountryResolver> logger)
    {
        this.logger = logger;
        var path = options.Value.GeoIpDatabasePath;
        if (!string.IsNullOrWhiteSpace(path) && File.Exists(path))
            reader = new DatabaseReader(path);
        else
            logger.LogWarning("GeoIP database is not configured; only allowed CIDRs and development overrides can pass location checks.");
    }

    public ValueTask<string?> ResolveCountryCodeAsync(IPAddress address, CancellationToken cancellationToken)
    {
        if (reader is null) return ValueTask.FromResult<string?>(null);
        try
        {
            return ValueTask.FromResult(reader.Country(address).Country.IsoCode);
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            logger.LogWarning("GeoIP lookup failed for {Address}: {ExceptionType}.", address, exception.GetType().Name);
            return ValueTask.FromResult<string?>(null);
        }
    }

    public void Dispose() => reader?.Dispose();
}
