using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using SpeAuthorizationDemo.Authorization;
using SpeAuthorizationDemo.Graph;

namespace SpeAuthorizationDemo.Pages;

public sealed class IndexModel(
    IBusinessAuthorizationService authorization,
    ISpeGraphClientFactory clients) : PageModel
{
    public string? TenantId => User.FindFirst("tid")?.Value ?? User.FindFirst("http://schemas.microsoft.com/identity/claims/tenantid")?.Value;
    public string? ObjectId => User.FindFirst("oid")?.Value ?? User.FindFirst("http://schemas.microsoft.com/identity/claims/objectidentifier")?.Value;
    public IReadOnlyList<string> Groups => User.Claims
        .Where(claim => claim.Type is "groups" or "http://schemas.microsoft.com/ws/2008/06/identity/claims/groups")
        .Select(claim => claim.Value)
        .ToArray();
    public bool HasGroupOverage => User.HasClaim(claim => claim.Type == "_claim_names" && claim.Value.Contains("groups", StringComparison.Ordinal));

    public bool HasValidationResult { get; private set; }
    public bool BusinessAllowed { get; private set; }
    public bool ContainerChecked { get; private set; }
    public bool ContainerAllowed { get; private set; }
    public bool FinalAllowed => BusinessAllowed && ContainerAllowed;
    public int? FileCount { get; private set; }
    public BusinessRole Role { get; private set; } = BusinessRole.None;
    public string BusinessReasonCode { get; private set; } = "not_run";
    public string ContainerReasonCode { get; private set; } = "not_tested";

    public void OnGet() { }

    public async Task<IActionResult> OnPostValidateAsync(CancellationToken cancellationToken)
    {
        HasValidationResult = true;
        var decision = await authorization.AuthorizeAsync(
            User,
            HttpContext,
            BusinessOperation.ListFiles,
            cancellationToken);

        BusinessAllowed = decision.IsAllowed;
        BusinessReasonCode = decision.ReasonCode;
        Role = decision.Role;
        if (!BusinessAllowed)
            return Page();

        ContainerChecked = true;
        try
        {
            var items = await clients.CreateDelegated().ListRootAsync(cancellationToken);
            ContainerAllowed = true;
            ContainerReasonCode = "allowed";
            FileCount = items.Count;
        }
        catch (SpeGraphException exception)
        {
            ContainerAllowed = false;
            ContainerReasonCode = SpeGraphErrorMapper.ToReasonCode(exception);
        }

        return Page();
    }
}
