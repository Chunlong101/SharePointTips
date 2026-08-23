using System.Reflection;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Identity.Client;
using Microsoft.Identity.Web;
using SpeAuthorizationDemo.Authentication;
using SpeAuthorizationDemo.Authorization;

namespace SpeAuthorizationDemo.Tests.Authorization;

public sealed class GraphGroupMembershipFallbackTests
{
    [Fact]
    public async Task Resolve_TokenCacheMissing_ReturnsReauthenticationRequired()
    {
        var exception = CreateChallenge("user_null");
        var fallback = CreateFallback(exception);

        var result = await fallback.ResolveAsync(CreateIdentity(), RelevantGroups(), CancellationToken.None);

        Assert.False(result.IsSuccess);
        Assert.Equal("reauthentication_required", result.ReasonCode);
    }

    [Fact]
    public async Task Resolve_ConditionalAccessChallenge_IsPreserved()
    {
        var expected = CreateChallenge("claims_challenge");
        var fallback = CreateFallback(expected);

        var actual = await Assert.ThrowsAsync<MicrosoftIdentityWebChallengeUserException>(() =>
            fallback.ResolveAsync(CreateIdentity(), RelevantGroups(), CancellationToken.None));

        Assert.Same(expected, actual);
    }

    private static GraphGroupMembershipFallback CreateFallback(Exception exception)
    {
        var tokenAcquisition = DispatchProxy.Create<ITokenAcquisition, ThrowingTokenAcquisitionProxy>();
        ((ThrowingTokenAcquisitionProxy)(object)tokenAcquisition).Exception = exception;
        return new GraphGroupMembershipFallback(
            new HttpClient(),
            tokenAcquisition,
            NullLogger<GraphGroupMembershipFallback>.Instance);
    }

    private static MicrosoftIdentityWebChallengeUserException CreateChallenge(string errorCode) =>
        new(
            new MsalUiRequiredException(errorCode, "Interactive authentication is required."),
            ["https://microsoftgraph.chinacloudapi.cn/GroupMember.Read.All"],
            null);

    private static UserIdentity CreateIdentity() =>
        new(Guid.NewGuid(), Guid.NewGuid(), "Test User", new HashSet<Guid>(), true);

    private static IReadOnlySet<Guid> RelevantGroups() =>
        new HashSet<Guid> { Guid.NewGuid() };

    public class ThrowingTokenAcquisitionProxy : DispatchProxy
    {
        public Exception Exception { get; set; } = new InvalidOperationException();

        protected override object? Invoke(MethodInfo? targetMethod, object?[]? args) => throw Exception;
    }
}
