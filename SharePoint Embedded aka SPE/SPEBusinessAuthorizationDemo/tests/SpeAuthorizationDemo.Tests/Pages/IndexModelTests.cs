using System.Net;
using System.Security.Claims;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.Identity.Client;
using Microsoft.Identity.Web;
using SpeAuthorizationDemo.Authorization;
using SpeAuthorizationDemo.Graph;
using SpeAuthorizationDemo.Models;
using SpeAuthorizationDemo.Pages;

namespace SpeAuthorizationDemo.Tests.Pages;

public sealed class IndexModelTests
{
    [Fact]
    public async Task Validate_BusinessDenied_DoesNotCallContainer()
    {
        var graph = new FakeGraphClient();
        var model = CreateModel(
            new AuthorizationDecision(false, BusinessRole.None, BusinessOperation.ListFiles, "group_not_allowed"),
            graph);

        await model.OnPostValidateAsync(CancellationToken.None);

        Assert.True(model.HasValidationResult);
        Assert.False(model.BusinessAllowed);
        Assert.False(model.ContainerChecked);
        Assert.False(model.FinalAllowed);
        Assert.Equal("group_not_allowed", model.BusinessReasonCode);
        Assert.Equal(0, graph.ListCalls);
    }

    [Fact]
    public async Task Validate_BusinessAndContainerAllowed_ShowsOnlyFileCount()
    {
        var graph = new FakeGraphClient
        {
            Items =
            [
                new SpeDriveItem("1", "secret-one.docx", 12, null),
                new SpeDriveItem("2", "secret-two.pdf", 34, null)
            ]
        };
        var model = CreateModel(
            new AuthorizationDecision(true, BusinessRole.Reader, BusinessOperation.ListFiles, "allowed"),
            graph);

        await model.OnPostValidateAsync(CancellationToken.None);

        Assert.True(model.BusinessAllowed);
        Assert.True(model.ContainerChecked);
        Assert.True(model.ContainerAllowed);
        Assert.True(model.FinalAllowed);
        Assert.Equal(2, model.FileCount);
        Assert.Equal(BusinessRole.Reader, model.Role);
        Assert.Equal(1, graph.ListCalls);
    }

    [Fact]
    public async Task Validate_ContainerForbidden_ShowsContainerPermissionDenied()
    {
        var graph = new FakeGraphClient
        {
            Failure = new SpeGraphException("upstream detail", HttpStatusCode.Forbidden)
        };
        var model = CreateModel(
            new AuthorizationDecision(true, BusinessRole.DemoAdmin, BusinessOperation.ListFiles, "allowed"),
            graph);

        await model.OnPostValidateAsync(CancellationToken.None);

        Assert.True(model.BusinessAllowed);
        Assert.True(model.ContainerChecked);
        Assert.False(model.ContainerAllowed);
        Assert.False(model.FinalAllowed);
        Assert.Equal("container_permission_denied", model.ContainerReasonCode);
    }

    [Fact]
    public async Task Validate_ReauthenticationRequired_ChallengesOpenIdConnect()
    {
        var graph = new FakeGraphClient();
        var model = CreateModel(
            new AuthorizationDecision(false, BusinessRole.None, BusinessOperation.ListFiles, "reauthentication_required"),
            graph);

        var result = await model.OnPostValidateAsync(CancellationToken.None);

        var challenge = Assert.IsType<ChallengeResult>(result);
        Assert.Contains(OpenIdConnectDefaults.AuthenticationScheme, challenge.AuthenticationSchemes);
        Assert.Equal("/", challenge.Properties?.RedirectUri);
        Assert.Equal(0, graph.ListCalls);
    }

    [Fact]
    public async Task Validate_DelegatedTokenCacheMissing_ChallengesOpenIdConnect()
    {
        var graph = new FakeGraphClient
        {
            Failure = new MicrosoftIdentityWebChallengeUserException(
                new MsalUiRequiredException("user_null", "No cached account."),
                ["https://microsoftgraph.chinacloudapi.cn/FileStorageContainer.Selected"],
                null)
        };
        var model = CreateModel(
            new AuthorizationDecision(true, BusinessRole.Reader, BusinessOperation.ListFiles, "allowed"),
            graph);

        var result = await model.OnPostValidateAsync(CancellationToken.None);

        var challenge = Assert.IsType<ChallengeResult>(result);
        Assert.Contains(OpenIdConnectDefaults.AuthenticationScheme, challenge.AuthenticationSchemes);
        Assert.Equal("/", challenge.Properties?.RedirectUri);
        Assert.Equal(1, graph.ListCalls);
    }

    [Fact]
    public async Task Validate_ConditionalAccessChallenge_IsPreserved()
    {
        var expected = new MicrosoftIdentityWebChallengeUserException(
            new MsalUiRequiredException("claims_challenge", "Additional claims are required."),
            ["https://microsoftgraph.chinacloudapi.cn/FileStorageContainer.Selected"],
            null);
        var graph = new FakeGraphClient { Failure = expected };
        var model = CreateModel(
            new AuthorizationDecision(true, BusinessRole.Reader, BusinessOperation.ListFiles, "allowed"),
            graph);

        var actual = await Assert.ThrowsAsync<MicrosoftIdentityWebChallengeUserException>(() =>
            model.OnPostValidateAsync(CancellationToken.None));

        Assert.Same(expected, actual);
    }

    private static IndexModel CreateModel(AuthorizationDecision decision, FakeGraphClient graph)
    {
        var context = new DefaultHttpContext
        {
            User = new ClaimsPrincipal(new ClaimsIdentity(
            [
                new Claim("tid", Guid.NewGuid().ToString()),
                new Claim("oid", Guid.NewGuid().ToString())
            ], "test"))
        };
        return new IndexModel(new FakeAuthorizationService(decision), new FakeGraphClientFactory(graph))
        {
            PageContext = new PageContext { HttpContext = context }
        };
    }

    private sealed class FakeAuthorizationService(AuthorizationDecision decision) : IBusinessAuthorizationService
    {
        public Task<AuthorizationDecision> AuthorizeAsync(
            ClaimsPrincipal user,
            HttpContext httpContext,
            BusinessOperation operation,
            CancellationToken cancellationToken) => Task.FromResult(decision);
    }

    private sealed class FakeGraphClientFactory(FakeGraphClient graph) : ISpeGraphClientFactory
    {
        public ISpeGraphClient CreateDelegated() => graph;
        public ISpeGraphClient CreateAppOnly() => graph;
    }

    private sealed class FakeGraphClient : ISpeGraphClient
    {
        public IReadOnlyList<SpeDriveItem> Items { get; init; } = [];
        public Exception? Failure { get; init; }
        public int ListCalls { get; private set; }

        public Task<IReadOnlyList<SpeDriveItem>> ListRootAsync(CancellationToken cancellationToken)
        {
            ListCalls++;
            if (Failure is not null) throw Failure;
            return Task.FromResult(Items);
        }

        public Task<SpeDownload> DownloadAsync(string itemId, CancellationToken cancellationToken) =>
            throw new NotSupportedException();

        public Task<SpeDriveItem> UploadSmallFileAsync(
            string fileName,
            Stream content,
            long length,
            CancellationToken cancellationToken) => throw new NotSupportedException();

        public Task DeleteFileAsync(string itemId, CancellationToken cancellationToken) =>
            throw new NotSupportedException();
    }
}
