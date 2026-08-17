using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using SpeAuthorizationDemo.Authorization;
using SpeAuthorizationDemo.Graph;
using SpeAuthorizationDemo.Models;

namespace SpeAuthorizationDemo.Pages.Files;

[Authorize]
public sealed class IndexModel(
    IBusinessAuthorizationService authorization,
    ISpeGraphClientFactory clients) : PageModel
{
    public IReadOnlyList<SpeDriveItem> Items { get; private set; } = [];
    public AuthorizationDecision? Decision { get; private set; }
    [BindProperty(SupportsGet = true)] public string? TestLocation { get; set; }

    public async Task<IActionResult> OnGetAsync(CancellationToken cancellationToken)
    {
        Decision = await authorization.AuthorizeAsync(User, HttpContext, BusinessOperation.ListFiles, cancellationToken);
        if (!Decision.IsAllowed) return RedirectToPage("/AccessDenied", new { reason = Decision.ReasonCode });
        Items = await clients.CreateDelegated().ListRootAsync(cancellationToken);
        return Page();
    }
}
