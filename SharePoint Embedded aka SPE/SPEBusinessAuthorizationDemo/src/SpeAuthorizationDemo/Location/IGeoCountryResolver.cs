using System.Net;

namespace SpeAuthorizationDemo.Location;

public interface IGeoCountryResolver
{
    ValueTask<string?> ResolveCountryCodeAsync(IPAddress address, CancellationToken cancellationToken);
}

public sealed class NullGeoCountryResolver : IGeoCountryResolver
{
    public ValueTask<string?> ResolveCountryCodeAsync(IPAddress address, CancellationToken cancellationToken) =>
        ValueTask.FromResult<string?>(null);
}
