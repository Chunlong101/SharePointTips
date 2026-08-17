using System.Net;
using Microsoft.Extensions.Options;
using SpeAuthorizationDemo.Configuration;

namespace SpeAuthorizationDemo.Location;

public interface IClientLocationEvaluator
{
    LocationEvidence Evaluate(IPAddress? sourceIp, string? countryCode, string? developmentOverride, bool isDevelopment);
}

public sealed class ClientLocationEvaluator(IOptions<LocationPolicyOptions> options) : IClientLocationEvaluator
{
    private readonly LocationPolicyOptions policy = options.Value;

    public LocationEvidence Evaluate(
        IPAddress? sourceIp,
        string? countryCode,
        string? developmentOverride,
        bool isDevelopment)
    {
        if (sourceIp is null)
            return Evidence(sourceIp, countryCode, false, false, false, "source_ip_missing");

        if (isDevelopment && policy.EnableDevelopmentOverride && IPAddress.IsLoopback(sourceIp) &&
            !string.IsNullOrWhiteSpace(developmentOverride))
        {
            var allowed = policy.AllowedCountryCodes.Contains(developmentOverride, StringComparer.OrdinalIgnoreCase);
            return Evidence(sourceIp, developmentOverride.ToUpperInvariant(), false, true, allowed,
                allowed ? "development_override_allowed" : "development_override_denied");
        }

        if (IsPrivateOrLoopback(sourceIp))
            return Evidence(sourceIp, countryCode, false, false, false, "non_public_source_ip");

        if (policy.AllowedCidrs.Any(cidr => CidrMatcher.IsMatch(sourceIp, cidr)))
            return Evidence(sourceIp, countryCode, true, false, true, "allowed_cidr");

        var countryAllowed = !string.IsNullOrWhiteSpace(countryCode) &&
            policy.AllowedCountryCodes.Contains(countryCode, StringComparer.OrdinalIgnoreCase);
        return Evidence(sourceIp, countryCode?.ToUpperInvariant(), false, false, countryAllowed,
            countryAllowed ? "allowed_country" : "country_not_allowed");
    }

    private static LocationEvidence Evidence(IPAddress? ip, string? country, bool cidr, bool dev, bool allowed, string reason) =>
        new(ip, country, cidr, dev, allowed, reason);

    private static bool IsPrivateOrLoopback(IPAddress address)
    {
        if (IPAddress.IsLoopback(address)) return true;
        if (address.AddressFamily == System.Net.Sockets.AddressFamily.InterNetwork)
        {
            var bytes = address.GetAddressBytes();
            return bytes[0] == 10 || bytes[0] == 127 ||
                   (bytes[0] == 172 && bytes[1] is >= 16 and <= 31) ||
                   (bytes[0] == 192 && bytes[1] == 168) ||
                   (bytes[0] == 169 && bytes[1] == 254);
        }
        return address.IsIPv6LinkLocal || address.IsIPv6SiteLocal;
    }
}
