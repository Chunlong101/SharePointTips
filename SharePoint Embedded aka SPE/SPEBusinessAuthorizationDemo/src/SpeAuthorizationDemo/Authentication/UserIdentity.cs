namespace SpeAuthorizationDemo.Authentication;

public sealed record UserIdentity(
    Guid TenantId,
    Guid ObjectId,
    string DisplayName,
    IReadOnlySet<Guid> GroupIds,
    bool HasGroupOverage);

public sealed record IdentityReadResult(
    bool IsSuccess,
    UserIdentity? Identity,
    string ReasonCode)
{
    public static IdentityReadResult Success(UserIdentity identity) => new(true, identity, "identity_valid");
    public static IdentityReadResult Failure(string reasonCode) => new(false, null, reasonCode);
}
