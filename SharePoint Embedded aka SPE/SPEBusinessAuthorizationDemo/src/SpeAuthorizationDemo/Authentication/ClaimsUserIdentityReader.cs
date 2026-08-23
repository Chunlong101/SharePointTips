using System.Security.Claims;
using System.Text.Json;

namespace SpeAuthorizationDemo.Authentication;

public interface IUserIdentityReader
{
    IdentityReadResult Read(ClaimsPrincipal principal);
}

public sealed class ClaimsUserIdentityReader : IUserIdentityReader
{
    private const string MappedTenantId = "http://schemas.microsoft.com/identity/claims/tenantid";
    private const string MappedObjectId = "http://schemas.microsoft.com/identity/claims/objectidentifier";
    private const string MappedGroups = "http://schemas.microsoft.com/ws/2008/06/identity/claims/groups";

    public IdentityReadResult Read(ClaimsPrincipal principal)
    {
        if (!Guid.TryParse(FindFirstValue(principal, "tid", MappedTenantId), out var tenantId))
            return IdentityReadResult.Failure("missing_tid");
        if (!Guid.TryParse(FindFirstValue(principal, "oid", MappedObjectId), out var objectId))
            return IdentityReadResult.Failure("missing_oid");

        var groups = principal.Claims
            .Where(claim => claim.Type is "groups" or MappedGroups)
            .Select(claim => Guid.TryParse(claim.Value, out var groupId) ? groupId : Guid.Empty)
            .Where(groupId => groupId != Guid.Empty)
            .ToHashSet();

        var overage = HasGroupOverage(principal.FindFirstValue("_claim_names"));
        var name = principal.FindFirstValue("name") ?? principal.Identity?.Name ?? objectId.ToString();
        return IdentityReadResult.Success(new UserIdentity(tenantId, objectId, name, groups, overage));
    }

    private static string? FindFirstValue(ClaimsPrincipal principal, params string[] claimTypes) =>
        principal.Claims.FirstOrDefault(claim => claimTypes.Contains(claim.Type, StringComparer.Ordinal))?.Value;

    private static bool HasGroupOverage(string? claimNames)
    {
        if (string.IsNullOrWhiteSpace(claimNames)) return false;
        try
        {
            using var document = JsonDocument.Parse(claimNames);
            return document.RootElement.TryGetProperty("groups", out _);
        }
        catch (JsonException)
        {
            return true;
        }
    }
}
