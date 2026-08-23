using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using SpeAuthorizationDemo.Authorization;
using SpeAuthorizationDemo.Graph;

namespace SpeAuthorizationDemo.Pages.Files;

[Authorize]
public sealed class DownloadModel(
    IBusinessAuthorizationService authorization,
    ISpeGraphClientFactory clients) : PageModel
{
    public async Task<IActionResult> OnGetAsync(string id, CancellationToken cancellationToken)
    {
        var decision = await authorization.AuthorizeAsync(User, HttpContext, BusinessOperation.DownloadFile, cancellationToken);
        if (!decision.IsAllowed) return RedirectToPage("/AccessDenied", new { reason = decision.ReasonCode });
        try
        {
            var download = await clients.CreateDelegated().DownloadAsync(id, cancellationToken);
            return File(download.Content, download.ContentType, download.FileName);
        }
        catch (SpeGraphException exception)
        {
            return RedirectToPage("/AccessDenied", new { reason = SpeGraphErrorMapper.ToReasonCode(exception) });
        }
    }
}
