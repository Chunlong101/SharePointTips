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
    public bool CanDelete => Decision?.Role >= BusinessRole.Writer;
    [TempData] public string? StatusMessage { get; set; }
    [BindProperty(SupportsGet = true)] public string? TestLocation { get; set; }

    public async Task<IActionResult> OnGetAsync(CancellationToken cancellationToken)
    {
        Decision = await authorization.AuthorizeAsync(User, HttpContext, BusinessOperation.ListFiles, cancellationToken);
        if (!Decision.IsAllowed) return RedirectToPage("/AccessDenied", new { reason = Decision.ReasonCode });
        try
        {
            Items = await clients.CreateDelegated().ListRootAsync(cancellationToken);
        }
        catch (SpeGraphException exception)
        {
            return RedirectToPage("/AccessDenied", new { reason = SpeGraphErrorMapper.ToReasonCode(exception) });
        }
        return Page();
    }

    public async Task<IActionResult> OnPostDeleteAsync(
        string itemId,
        CancellationToken cancellationToken)
    {
        var decision = await authorization.AuthorizeAsync(
            User,
            HttpContext,
            BusinessOperation.DeleteFile,
            cancellationToken);
        if (!decision.IsAllowed)
            return RedirectToPage("/AccessDenied", new { reason = decision.ReasonCode });

        try
        {
            var client = clients.CreateDelegated();
            var currentItems = await client.ListRootAsync(cancellationToken);
            var target = currentItems.SingleOrDefault(item => item.Id == itemId);
            if (target is null)
                return RedirectToPage("/AccessDenied", new { reason = "delete_target_not_allowed" });
            if (target.IsFolder)
                return RedirectToPage("/AccessDenied", new { reason = "folder_delete_not_allowed" });

            await client.DeleteFileAsync(itemId, cancellationToken);
        }
        catch (SpeFolderDeleteNotAllowedException)
        {
            return RedirectToPage("/AccessDenied", new { reason = "folder_delete_not_allowed" });
        }
        catch (SpeDeletePreconditionException)
        {
            return RedirectToPage("/AccessDenied", new { reason = "delete_precondition_failed" });
        }
        catch (SpeGraphException exception)
        {
            return RedirectToPage("/AccessDenied", new { reason = SpeGraphErrorMapper.ToReasonCode(exception) });
        }

        StatusMessage = "文件已移入回收站。";
        return RedirectToPage("/Files/Index", new { testLocation = TestLocation });
    }
}
