namespace SpeAuthorizationDemo.Configuration;

public sealed class AzureAdOptions
{
    public const string SectionName = "AzureAd";
    public string TenantId { get; set; } = "";
    public string ClientId { get; set; } = "84ddb0d9-4d5f-4b0e-80b4-b3530e345f9b";
    public string ClientSecret { get; set; } = "";
    public string Instance { get; set; } = "https://login.chinacloudapi.cn/";
    public string CallbackPath { get; set; } = "/signin-oidc";
}

public sealed class SpeOptions
{
    public const string SectionName = "Spe";
    public string ContainerId { get; set; } = "";
    public string GraphBaseUrl { get; set; } = "https://microsoftgraph.chinacloudapi.cn";
    public int MaxUploadBytes { get; set; } = 4_000_000;
}

public sealed class AuthorizationPolicyOptions
{
    public const string SectionName = "AuthorizationPolicy";
    public string AllowedTenantId { get; set; } = "";
    public string ReaderGroupId { get; set; } = "";
    public string WriterGroupId { get; set; } = "";
    public string AdminGroupId { get; set; } = "";
}

public sealed class LocationPolicyOptions
{
    public const string SectionName = "LocationPolicy";
    public string[] AllowedCountryCodes { get; set; } = ["CN"];
    public string[] AllowedCidrs { get; set; } = [];
    public bool EnableDevelopmentOverride { get; set; }
    public string[] KnownProxies { get; set; } = [];
    public string[] KnownNetworks { get; set; } = [];
    public string GeoIpDatabasePath { get; set; } = "";
}

public static class DemoOptionsValidator
{
    public static IReadOnlyList<string> Validate(
        AzureAdOptions azureAd,
        SpeOptions spe,
        AuthorizationPolicyOptions authorization)
    {
        var errors = new List<string>();
        RequireGuid(azureAd.TenantId, "AzureAd:TenantId", errors);
        RequireGuid(azureAd.ClientId, "AzureAd:ClientId", errors);
        if (string.IsNullOrWhiteSpace(azureAd.ClientSecret)) errors.Add("AzureAd:ClientSecret must be stored in User Secrets or App Service settings.");
        if (string.IsNullOrWhiteSpace(spe.ContainerId)) errors.Add("Spe:ContainerId is required.");
        if (!string.Equals(spe.GraphBaseUrl.TrimEnd('/'), "https://microsoftgraph.chinacloudapi.cn", StringComparison.OrdinalIgnoreCase))
            errors.Add("Spe:GraphBaseUrl must use the China Graph endpoint.");
        if (spe.MaxUploadBytes is <= 0 or > 4_000_000) errors.Add("Spe:MaxUploadBytes must be between 1 and 4 MB.");
        RequireGuid(authorization.AllowedTenantId, "AuthorizationPolicy:AllowedTenantId", errors);
        RequireGuid(authorization.ReaderGroupId, "AuthorizationPolicy:ReaderGroupId", errors);
        RequireGuid(authorization.WriterGroupId, "AuthorizationPolicy:WriterGroupId", errors);
        RequireGuid(authorization.AdminGroupId, "AuthorizationPolicy:AdminGroupId", errors);
        return errors;
    }

    private static void RequireGuid(string value, string name, ICollection<string> errors)
    {
        if (!Guid.TryParse(value, out _)) errors.Add($"{name} must be a GUID.");
    }
}
