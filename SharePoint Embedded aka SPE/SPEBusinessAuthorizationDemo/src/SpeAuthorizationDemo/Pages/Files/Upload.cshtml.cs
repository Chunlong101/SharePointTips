using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.Extensions.Options;
using SpeAuthorizationDemo.Authorization;
using SpeAuthorizationDemo.Configuration;
using SpeAuthorizationDemo.Graph;

namespace SpeAuthorizationDemo.Pages.Files;

[Authorize]
public sealed class UploadModel(
    IBusinessAuthorizationService authorization,
    ISpeGraphClientFactory clients,
    IOptions<SpeOptions> options) : PageModel
{
    [BindProperty] public IFormFile? Upload { get; set; }
    [BindProperty(SupportsGet = true)] public string? TestLocation { get; set; }
    public long MaximumBytes => options.Value.MaxUploadBytes;

    public async Task<IActionResult> OnGetAsync(CancellationToken cancellationToken)
    {
        var decision = await authorization.AuthorizeAsync(User, HttpContext, BusinessOperation.UploadFile, cancellationToken);
        return decision.IsAllowed ? Page() : RedirectToPage("/AccessDenied", new { reason = decision.ReasonCode });
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken cancellationToken)
    {
        var decision = await authorization.AuthorizeAsync(User, HttpContext, BusinessOperation.UploadFile, cancellationToken);
        if (!decision.IsAllowed) return RedirectToPage("/AccessDenied", new { reason = decision.ReasonCode });
        if (Upload is null || !FileNamePolicy.IsAllowed(Upload.FileName) || !FileNamePolicy.IsAllowedLength(Upload.Length, MaximumBytes))
        {
            ModelState.AddModelError(nameof(Upload), $"请选择名称安全且大小不超过 {MaximumBytes:N0} bytes 的文件。");
            return Page();
        }

        await using var stream = Upload.OpenReadStream();
        await clients.CreateDelegated().UploadSmallFileAsync(Upload.FileName, stream, Upload.Length, cancellationToken);
        return RedirectToPage("/Files/Index", new { testLocation = TestLocation });
    }
}
