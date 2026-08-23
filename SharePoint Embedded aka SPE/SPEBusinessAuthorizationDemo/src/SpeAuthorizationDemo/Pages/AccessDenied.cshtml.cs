using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace SpeAuthorizationDemo.Pages;

public sealed class AccessDeniedModel : PageModel
{
    [BindProperty(SupportsGet = true)] public string Reason { get; set; } = "access_denied";
}
