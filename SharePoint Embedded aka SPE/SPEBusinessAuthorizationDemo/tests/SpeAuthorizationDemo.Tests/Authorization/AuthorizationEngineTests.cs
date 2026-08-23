using System.Net;
using Microsoft.Extensions.Options;
using SpeAuthorizationDemo.Authentication;
using SpeAuthorizationDemo.Authorization;
using SpeAuthorizationDemo.Configuration;
using SpeAuthorizationDemo.Location;

namespace SpeAuthorizationDemo.Tests.Authorization;

public sealed class AuthorizationEngineTests
{
    private readonly Guid tenantId = Guid.NewGuid();
    private readonly Guid readerGroup = Guid.NewGuid();
    private readonly Guid writerGroup = Guid.NewGuid();
    private readonly Guid adminGroup = Guid.NewGuid();

    [Theory]
    [InlineData(BusinessRole.Reader, BusinessOperation.ListFiles, true)]
    [InlineData(BusinessRole.Reader, BusinessOperation.DownloadFile, true)]
    [InlineData(BusinessRole.Reader, BusinessOperation.UploadFile, false)]
    [InlineData(BusinessRole.Writer, BusinessOperation.UploadFile, true)]
    [InlineData(BusinessRole.Reader, BusinessOperation.DeleteFile, false)]
    [InlineData(BusinessRole.Writer, BusinessOperation.DeleteFile, true)]
    [InlineData(BusinessRole.DemoAdmin, BusinessOperation.DeleteFile, true)]
    [InlineData(BusinessRole.Writer, BusinessOperation.RunAppOnlyComparison, false)]
    [InlineData(BusinessRole.DemoAdmin, BusinessOperation.RunAppOnlyComparison, true)]
    public void Decide_EnforcesRoleOperationMatrix(
        BusinessRole role,
        BusinessOperation operation,
        bool expected)
    {
        var engine = CreateEngine();
        var groups = role switch
        {
            BusinessRole.Reader => new HashSet<Guid> { readerGroup },
            BusinessRole.Writer => new HashSet<Guid> { writerGroup },
            _ => new HashSet<Guid> { adminGroup }
        };

        var decision = engine.Decide(Identity(tenantId, groups), AllowedLocation(), operation);

        Assert.Equal(expected, decision.IsAllowed);
    }

    [Fact]
    public void Decide_FailsClosedForWrongTenantNoGroupOrLocation()
    {
        var engine = CreateEngine();
        engine.Decide(Identity(Guid.NewGuid(), [readerGroup]), AllowedLocation(), BusinessOperation.ListFiles)
            .ReasonCode.ShouldBe("tenant_not_allowed");
        engine.Decide(Identity(tenantId, []), AllowedLocation(), BusinessOperation.ListFiles)
            .ReasonCode.ShouldBe("group_not_allowed");
        engine.Decide(Identity(tenantId, [readerGroup]), DeniedLocation(), BusinessOperation.ListFiles)
            .ReasonCode.ShouldBe("location_not_allowed");
    }

    [Fact]
    public void Decide_SelectsHighestRole()
    {
        var decision = CreateEngine().Decide(
            Identity(tenantId, [readerGroup, writerGroup]),
            AllowedLocation(),
            BusinessOperation.UploadFile);

        Assert.True(decision.IsAllowed);
        Assert.Equal(BusinessRole.Writer, decision.Role);
    }

    private AuthorizationEngine CreateEngine() => new(Options.Create(new AuthorizationPolicyOptions
    {
        AllowedTenantId = tenantId.ToString(),
        ReaderGroupId = readerGroup.ToString(),
        WriterGroupId = writerGroup.ToString(),
        AdminGroupId = adminGroup.ToString()
    }));

    private static UserIdentity Identity(Guid tenant, IEnumerable<Guid> groups) =>
        new(tenant, Guid.NewGuid(), "Test User", groups.ToHashSet(), false);

    private static LocationEvidence AllowedLocation() =>
        new(IPAddress.Parse("8.8.8.8"), "CN", false, false, true, "allowed_country");

    private static LocationEvidence DeniedLocation() =>
        new(IPAddress.Parse("8.8.8.8"), "US", false, false, false, "country_not_allowed");
}

file static class AssertionExtensions
{
    public static void ShouldBe<T>(this T actual, T expected) => Assert.Equal(expected, actual);
}
