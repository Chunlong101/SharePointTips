using SpeAuthorizationDemo.Configuration;

namespace SpeAuthorizationDemo.Tests.Configuration;

public sealed class DemoOptionsValidatorTests
{
    [Fact]
    public void Validate_AcceptsCompleteChinaConfiguration()
    {
        var errors = DemoOptionsValidator.Validate(
            new AzureAdOptions { TenantId = Guid.NewGuid().ToString(), ClientId = Guid.NewGuid().ToString(), ClientSecret = "not-a-real-secret" },
            new SpeOptions { ContainerId = "b!container", GraphBaseUrl = "https://microsoftgraph.chinacloudapi.cn", MaxUploadBytes = 4_000_000 },
            new AuthorizationPolicyOptions
            {
                AllowedTenantId = Guid.NewGuid().ToString(),
                ReaderGroupId = Guid.NewGuid().ToString(),
                WriterGroupId = Guid.NewGuid().ToString(),
                AdminGroupId = Guid.NewGuid().ToString()
            });

        Assert.Empty(errors);
    }

    [Fact]
    public void Validate_RejectsMissingAndUnsafeValues()
    {
        var errors = DemoOptionsValidator.Validate(
            new AzureAdOptions(),
            new SpeOptions { ContainerId = "", GraphBaseUrl = "https://graph.microsoft.com", MaxUploadBytes = 4_000_001 },
            new AuthorizationPolicyOptions());

        Assert.Contains(errors, error => error.Contains("TenantId"));
        Assert.Contains(errors, error => error.Contains("ClientSecret"));
        Assert.Contains(errors, error => error.Contains("ContainerId"));
        Assert.Contains(errors, error => error.Contains("China Graph"));
        Assert.Contains(errors, error => error.Contains("4 MB"));
        Assert.Contains(errors, error => error.Contains("ReaderGroupId"));
    }
}
