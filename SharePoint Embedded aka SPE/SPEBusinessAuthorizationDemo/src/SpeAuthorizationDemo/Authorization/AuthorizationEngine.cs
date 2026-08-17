using Microsoft.Extensions.Options;
using SpeAuthorizationDemo.Authentication;
using SpeAuthorizationDemo.Configuration;
using SpeAuthorizationDemo.Location;

namespace SpeAuthorizationDemo.Authorization;

public enum BusinessRole { None = 0, Reader = 1, Writer = 2, DemoAdmin = 3 }
public enum BusinessOperation { ListFiles, DownloadFile, UploadFile, RunAppOnlyComparison }

public sealed record AuthorizationDecision(
    bool IsAllowed,
    BusinessRole Role,
    BusinessOperation Operation,
    string ReasonCode);

public sealed class AuthorizationEngine
{
    private readonly Guid allowedTenant;
    private readonly Guid readerGroup;
    private readonly Guid writerGroup;
    private readonly Guid adminGroup;

    public AuthorizationEngine(IOptions<AuthorizationPolicyOptions> options)
    {
        allowedTenant = Guid.Parse(options.Value.AllowedTenantId);
        readerGroup = Guid.Parse(options.Value.ReaderGroupId);
        writerGroup = Guid.Parse(options.Value.WriterGroupId);
        adminGroup = Guid.Parse(options.Value.AdminGroupId);
    }

    public AuthorizationDecision Decide(
        UserIdentity identity,
        LocationEvidence location,
        BusinessOperation operation)
    {
        if (identity.TenantId != allowedTenant) return Deny(BusinessRole.None, operation, "tenant_not_allowed");
        var role = ResolveRole(identity.GroupIds);
        if (role == BusinessRole.None) return Deny(role, operation, "group_not_allowed");
        if (!location.IsAllowed) return Deny(role, operation, "location_not_allowed");

        var allowed = operation switch
        {
            BusinessOperation.ListFiles or BusinessOperation.DownloadFile => role >= BusinessRole.Reader,
            BusinessOperation.UploadFile => role >= BusinessRole.Writer,
            BusinessOperation.RunAppOnlyComparison => role >= BusinessRole.DemoAdmin,
            _ => false
        };
        return new AuthorizationDecision(allowed, role, operation, allowed ? "allowed" : "operation_not_allowed");
    }

    private BusinessRole ResolveRole(IReadOnlySet<Guid> groups)
    {
        if (groups.Contains(adminGroup)) return BusinessRole.DemoAdmin;
        if (groups.Contains(writerGroup)) return BusinessRole.Writer;
        if (groups.Contains(readerGroup)) return BusinessRole.Reader;
        return BusinessRole.None;
    }

    private static AuthorizationDecision Deny(BusinessRole role, BusinessOperation operation, string reason) =>
        new(false, role, operation, reason);
}
