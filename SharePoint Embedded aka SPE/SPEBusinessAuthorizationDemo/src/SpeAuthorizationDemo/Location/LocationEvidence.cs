using System.Net;

namespace SpeAuthorizationDemo.Location;

public sealed record LocationEvidence(
    IPAddress? SourceIp,
    string? CountryCode,
    bool IsAllowedCidr,
    bool IsDevelopmentOverride,
    bool IsAllowed,
    string ReasonCode);
