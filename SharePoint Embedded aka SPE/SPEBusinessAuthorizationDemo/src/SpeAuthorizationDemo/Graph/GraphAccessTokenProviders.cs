using Microsoft.Extensions.Options;
using Microsoft.Identity.Client;
using Microsoft.Identity.Web;
using SpeAuthorizationDemo.Configuration;

namespace SpeAuthorizationDemo.Graph;

public interface IDelegatedGraphAccessTokenProvider : IGraphAccessTokenProvider;
public interface IAppOnlyGraphAccessTokenProvider : IGraphAccessTokenProvider;

public sealed class DelegatedGraphAccessTokenProvider(ITokenAcquisition tokenAcquisition) : IDelegatedGraphAccessTokenProvider
{
    public Task<string> GetTokenAsync(CancellationToken cancellationToken) =>
        tokenAcquisition.GetAccessTokenForUserAsync([
            "https://microsoftgraph.chinacloudapi.cn/FileStorageContainer.Selected"
        ]);
}

public sealed class AppOnlyGraphAccessTokenProvider : IAppOnlyGraphAccessTokenProvider
{
    private readonly IConfidentialClientApplication application;
    private readonly string[] scopes;

    public AppOnlyGraphAccessTokenProvider(IOptions<AzureAdOptions> azureAd, IOptions<SpeOptions> spe)
    {
        var authority = $"{azureAd.Value.Instance.TrimEnd('/')}/{azureAd.Value.TenantId}";
        application = ConfidentialClientApplicationBuilder
            .Create(azureAd.Value.ClientId)
            .WithClientSecret(azureAd.Value.ClientSecret)
            .WithAuthority(authority)
            .Build();
        scopes = [$"{spe.Value.GraphBaseUrl.TrimEnd('/')}/.default"];
    }

    public async Task<string> GetTokenAsync(CancellationToken cancellationToken) =>
        (await application.AcquireTokenForClient(scopes).ExecuteAsync(cancellationToken)).AccessToken;
}

public interface ISpeGraphClientFactory
{
    ISpeGraphClient CreateDelegated();
    ISpeGraphClient CreateAppOnly();
}

public sealed class SpeGraphClientFactory(
    IHttpClientFactory httpClientFactory,
    IDelegatedGraphAccessTokenProvider delegated,
    IAppOnlyGraphAccessTokenProvider appOnly,
    IOptions<SpeOptions> options) : ISpeGraphClientFactory
{
    public ISpeGraphClient CreateDelegated() => new SpeGraphClient(httpClientFactory.CreateClient("SpeGraph"), delegated, options);
    public ISpeGraphClient CreateAppOnly() => new SpeGraphClient(httpClientFactory.CreateClient("SpeGraph"), appOnly, options);
}
