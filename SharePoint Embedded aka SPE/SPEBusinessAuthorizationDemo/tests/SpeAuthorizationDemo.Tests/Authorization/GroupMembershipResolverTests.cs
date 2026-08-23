using SpeAuthorizationDemo.Authentication;
using SpeAuthorizationDemo.Authorization;

namespace SpeAuthorizationDemo.Tests.Authorization;

public sealed class GroupMembershipResolverTests
{
    [Fact]
    public async Task ResolveAsync_UsesCompleteTokenClaimsWithoutFallback()
    {
        var relevant = Guid.NewGuid();
        var fallback = new FakeFallback(new HashSet<Guid> { Guid.NewGuid() });
        var resolver = new CompositeGroupMembershipResolver(fallback);
        var identity = Identity([relevant], false);

        var result = await resolver.ResolveAsync(identity, new HashSet<Guid> { relevant }, CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Contains(relevant, result.GroupIds);
        Assert.Equal(0, fallback.CallCount);
    }

    [Fact]
    public async Task ResolveAsync_UsesFallbackForGroupOverage()
    {
        var relevant = Guid.NewGuid();
        var fallback = new FakeFallback(new HashSet<Guid> { relevant });
        var resolver = new CompositeGroupMembershipResolver(fallback);

        var result = await resolver.ResolveAsync(Identity([], true), new HashSet<Guid> { relevant }, CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Contains(relevant, result.GroupIds);
        Assert.Equal(1, fallback.CallCount);
    }

    [Fact]
    public async Task ResolveAsync_UsesFallbackWhenTokenContainsNoGroups()
    {
        var relevant = Guid.NewGuid();
        var fallback = new FakeFallback(new HashSet<Guid> { relevant });
        var resolver = new CompositeGroupMembershipResolver(fallback);

        var result = await resolver.ResolveAsync(Identity([], false), new HashSet<Guid> { relevant }, CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Contains(relevant, result.GroupIds);
        Assert.Equal(1, fallback.CallCount);
    }

    [Fact]
    public async Task ResolveAsync_FailsClosedWhenFallbackFails()
    {
        var resolver = new CompositeGroupMembershipResolver(new FakeFallback(new HashSet<Guid>(), false));

        var result = await resolver.ResolveAsync(Identity([], true), new HashSet<Guid> { Guid.NewGuid() }, CancellationToken.None);

        Assert.False(result.IsSuccess);
        Assert.Equal("group_fallback_failed", result.ReasonCode);
    }

    private static UserIdentity Identity(IEnumerable<Guid> groups, bool overage) =>
        new(Guid.NewGuid(), Guid.NewGuid(), "User", groups.ToHashSet(), overage);

    private sealed class FakeFallback(IReadOnlySet<Guid> groups, bool success = true) : IGroupMembershipFallback
    {
        public int CallCount { get; private set; }

        public Task<GroupResolutionResult> ResolveAsync(
            UserIdentity identity,
            IReadOnlySet<Guid> relevantGroupIds,
            CancellationToken cancellationToken)
        {
            CallCount++;
            return Task.FromResult(success
                ? GroupResolutionResult.Success(groups)
                : GroupResolutionResult.Failure("group_fallback_failed"));
        }
    }
}
