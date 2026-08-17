using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using SpeAuthorizationDemo.Authorization;
using SpeAuthorizationDemo.Graph;
using SpeAuthorizationDemo.Models;

namespace SpeAuthorizationDemo.Pages.AppOnly;

[Authorize]
public sealed class IndexModel(
    IBusinessAuthorizationService authorization,
    ISpeGraphClientFactory clients) : PageModel
{
    public IReadOnlyList<SpeDriveItem> Items { get; private set; } = [];
    public async Task<IActionResult> OnGetAsync(CancellationToken cancellationToken)
    {
        var decision = await authorization.AuthorizeAsync(User, HttpContext, BusinessOperation.RunAppOnlyComparison, cancellationToken);
        if (!decision.IsAllowed) return RedirectToPage("/AccessDenied", new { reason = decision.ReasonCode });
        Items = await clients.CreateAppOnly().ListRootAsync(cancellationToken);
        return Page();
    }
}
