using System.Security.Claims;
using SpeAuthorizationDemo.Authentication;

namespace SpeAuthorizationDemo.Tests.Authentication;

public sealed class ClaimsUserIdentityReaderTests
{
    [Fact]
    public void Read_ParsesTrustedIdentityAndGroups()
    {
        var tenantId = Guid.NewGuid();
        var objectId = Guid.NewGuid();
        var groupId = Guid.NewGuid();
        var principal = Principal(
            new("tid", tenantId.ToString()),
            new("oid", objectId.ToString()),
            new("name", "Reader User"),
            new("groups", groupId.ToString()));

        var result = new ClaimsUserIdentityReader().Read(principal);

        Assert.True(result.IsSuccess);
        Assert.Equal(tenantId, result.Identity!.TenantId);
        Assert.Equal(objectId, result.Identity.ObjectId);
        Assert.Contains(groupId, result.Identity.GroupIds);
        Assert.False(result.Identity.HasGroupOverage);
    }

    [Theory]
    [InlineData("tid")]
    [InlineData("oid")]
    public void Read_FailsClosedWhenRequiredClaimIsMissing(string missingClaim)
    {
        var claims = new List<Claim>
        {
            new("tid", Guid.NewGuid().ToString()),
            new("oid", Guid.NewGuid().ToString())
        };
        claims.RemoveAll(claim => claim.Type == missingClaim);

        var result = new ClaimsUserIdentityReader().Read(Principal(claims.ToArray()));

        Assert.False(result.IsSuccess);
        Assert.Equal($"missing_{missingClaim}", result.ReasonCode);
    }

    [Fact]
    public void Read_DetectsGroupOverage()
    {
        var principal = Principal(
            new("tid", Guid.NewGuid().ToString()),
            new("oid", Guid.NewGuid().ToString()),
            new("_claim_names", "{\"groups\":\"src1\"}"));

        var result = new ClaimsUserIdentityReader().Read(principal);

        Assert.True(result.IsSuccess);
        Assert.True(result.Identity!.HasGroupOverage);
    }

    [Fact]
    public void Read_ParsesMicrosoftIdentityMappedClaims()
    {
        var tenantId = Guid.NewGuid();
        var objectId = Guid.NewGuid();
        var groupId = Guid.NewGuid();
        var principal = Principal(
            new("http://schemas.microsoft.com/identity/claims/tenantid", tenantId.ToString()),
            new("http://schemas.microsoft.com/identity/claims/objectidentifier", objectId.ToString()),
            new("http://schemas.microsoft.com/ws/2008/06/identity/claims/groups", groupId.ToString()));

        var result = new ClaimsUserIdentityReader().Read(principal);

        Assert.True(result.IsSuccess);
        Assert.Equal(tenantId, result.Identity!.TenantId);
        Assert.Equal(objectId, result.Identity.ObjectId);
        Assert.Contains(groupId, result.Identity.GroupIds);
    }

    private static ClaimsPrincipal Principal(params Claim[] claims) =>
        new(new ClaimsIdentity(claims, "test"));
}
