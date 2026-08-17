using SpeAuthorizationDemo.Authentication;

namespace SpeAuthorizationDemo.Authorization;

public sealed record GroupResolutionResult(
    bool IsSuccess,
    IReadOnlySet<Guid> GroupIds,
    string ReasonCode)
{
    public static GroupResolutionResult Success(IReadOnlySet<Guid> groups) => new(true, groups, "groups_resolved");
    public static GroupResolutionResult Failure(string reason) => new(false, new HashSet<Guid>(), reason);
}

public interface IGroupMembershipFallback
{
    Task<GroupResolutionResult> ResolveAsync(
        UserIdentity identity,
        IReadOnlySet<Guid> relevantGroupIds,
        CancellationToken cancellationToken);
}

public interface IGroupMembershipResolver
{
    Task<GroupResolutionResult> ResolveAsync(
        UserIdentity identity,
        IReadOnlySet<Guid> relevantGroupIds,
        CancellationToken cancellationToken);
}

public sealed class CompositeGroupMembershipResolver(IGroupMembershipFallback fallback) : IGroupMembershipResolver
{
    public Task<GroupResolutionResult> ResolveAsync(
        UserIdentity identity,
        IReadOnlySet<Guid> relevantGroupIds,
        CancellationToken cancellationToken)
    {
        if (identity.HasGroupOverage || identity.GroupIds.Count == 0)
            return fallback.ResolveAsync(identity, relevantGroupIds, cancellationToken);

        var matches = identity.GroupIds.Where(relevantGroupIds.Contains).ToHashSet();
        return Task.FromResult(GroupResolutionResult.Success(matches));
    }
}
