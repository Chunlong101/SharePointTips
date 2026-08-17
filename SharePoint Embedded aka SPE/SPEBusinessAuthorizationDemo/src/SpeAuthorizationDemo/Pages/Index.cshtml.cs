using Microsoft.AspNetCore.Mvc.RazorPages;

namespace SpeAuthorizationDemo.Pages;

public sealed class IndexModel : PageModel
{
    public string? TenantId => User.FindFirst("tid")?.Value ?? User.FindFirst("http://schemas.microsoft.com/identity/claims/tenantid")?.Value;
    public string? ObjectId => User.FindFirst("oid")?.Value ?? User.FindFirst("http://schemas.microsoft.com/identity/claims/objectidentifier")?.Value;
    public IReadOnlyList<string> Groups => User.Claims
        .Where(claim => claim.Type is "groups" or "http://schemas.microsoft.com/ws/2008/06/identity/claims/groups")
        .Select(claim => claim.Value)
        .ToArray();
    public bool HasGroupOverage => User.HasClaim(claim => claim.Type == "_claim_names" && claim.Value.Contains("groups", StringComparison.Ordinal));
    public void OnGet() { }
}
