using System.Net;
using System.Security.Claims;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using SpeAuthorizationDemo.Authentication;
using SpeAuthorizationDemo.Authorization;
using SpeAuthorizationDemo.Configuration;
using SpeAuthorizationDemo.Location;

namespace SpeAuthorizationDemo.Tests.Authorization;

public sealed class BusinessAuthorizationServiceTests
{
    [Fact]
    public async Task AuthorizeAsync_AllowsReaderListFromMainland()
    {
        var tenant = Guid.NewGuid();
        var reader = Guid.NewGuid();
        var service = Create(tenant, reader, new SuccessfulGroups(new HashSet<Guid> { reader }), "CN");
        var context = Context(tenant, IPAddress.Parse("8.8.8.8"));

        var decision = await service.AuthorizeAsync(context.User, context, BusinessOperation.ListFiles, CancellationToken.None);

        Assert.True(decision.IsAllowed);
        Assert.Equal(BusinessRole.Reader, decision.Role);
    }

    [Fact]
    public async Task AuthorizeAsync_FailsClosedWhenGroupResolutionFails()
    {
        var tenant = Guid.NewGuid();
        var service = Create(tenant, Guid.NewGuid(), new FailedGroups(), "CN");
        var context = Context(tenant, IPAddress.Parse("8.8.8.8"));

        var decision = await service.AuthorizeAsync(context.User, context, BusinessOperation.ListFiles, CancellationToken.None);

        Assert.False(decision.IsAllowed);
        Assert.Equal("group_fallback_failed", decision.ReasonCode);
    }

    [Fact]
    public async Task AuthorizeAsync_RejectsNonMainlandLocation()
    {
        var tenant = Guid.NewGuid();
        var reader = Guid.NewGuid();
        var service = Create(tenant, reader, new SuccessfulGroups(new HashSet<Guid> { reader }), "US");
        var context = Context(tenant, IPAddress.Parse("8.8.8.8"));

        var decision = await service.AuthorizeAsync(context.User, context, BusinessOperation.ListFiles, CancellationToken.None);

        Assert.False(decision.IsAllowed);
        Assert.Equal("location_not_allowed", decision.ReasonCode);
    }

    [Fact]
    public async Task AuthorizeAsync_RejectsWrongTenantBeforeGroupResolution()
    {
        var tenant = Guid.NewGuid();
        var groups = new TrackingGroups();
        var service = Create(tenant, Guid.NewGuid(), groups, "CN");
        var context = Context(Guid.NewGuid(), IPAddress.Parse("8.8.8.8"));

        var decision = await service.AuthorizeAsync(context.User, context, BusinessOperation.ListFiles, CancellationToken.None);

        Assert.False(decision.IsAllowed);
        Assert.Equal("tenant_not_allowed", decision.ReasonCode);
        Assert.Equal(0, groups.CallCount);
    }

    private static BusinessAuthorizationService Create(
        Guid tenant,
        Guid reader,
        IGroupMembershipResolver groups,
        string country)
    {
        var options = Options.Create(new AuthorizationPolicyOptions
        {
            AllowedTenantId = tenant.ToString(),
            ReaderGroupId = reader.ToString(),
            WriterGroupId = Guid.NewGuid().ToString(),
            AdminGroupId = Guid.NewGuid().ToString()
        });
        return new BusinessAuthorizationService(
            new ClaimsUserIdentityReader(),
            groups,
            new ClientLocationEvaluator(Options.Create(new LocationPolicyOptions { AllowedCountryCodes = ["CN"] })),
            new StaticCountryResolver(country),
            new AuthorizationEngine(options),
            new FakeHostEnvironment(),
            options,
            NullLogger<BusinessAuthorizationService>.Instance);
    }

    private static DefaultHttpContext Context(Guid tenant, IPAddress address)
    {
        var context = new DefaultHttpContext();
        context.Connection.RemoteIpAddress = address;
        context.User = new ClaimsPrincipal(new ClaimsIdentity([
            new Claim("tid", tenant.ToString()),
            new Claim("oid", Guid.NewGuid().ToString()),
            new Claim("name", "Test User")
        ], "test"));
        return context;
    }

    private sealed class SuccessfulGroups(IReadOnlySet<Guid> ids) : IGroupMembershipResolver
    {
        public Task<GroupResolutionResult> ResolveAsync(UserIdentity identity, IReadOnlySet<Guid> relevantGroupIds, CancellationToken cancellationToken) =>
            Task.FromResult(GroupResolutionResult.Success(ids));
    }

    private sealed class FailedGroups : IGroupMembershipResolver
    {
        public Task<GroupResolutionResult> ResolveAsync(UserIdentity identity, IReadOnlySet<Guid> relevantGroupIds, CancellationToken cancellationToken) =>
            Task.FromResult(GroupResolutionResult.Failure("group_fallback_failed"));
    }

    private sealed class TrackingGroups : IGroupMembershipResolver
    {
        public int CallCount { get; private set; }
        public Task<GroupResolutionResult> ResolveAsync(UserIdentity identity, IReadOnlySet<Guid> relevantGroupIds, CancellationToken cancellationToken)
        {
            CallCount++;
            return Task.FromResult(GroupResolutionResult.Success(new HashSet<Guid>()));
        }
    }

    private sealed class StaticCountryResolver(string country) : IGeoCountryResolver
    {
        public ValueTask<string?> ResolveCountryCodeAsync(IPAddress address, CancellationToken cancellationToken) => ValueTask.FromResult<string?>(country);
    }

    private sealed class FakeHostEnvironment : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = Environments.Production;
        public string ApplicationName { get; set; } = "Test";
        public string ContentRootPath { get; set; } = "";
        public Microsoft.Extensions.FileProviders.IFileProvider ContentRootFileProvider { get; set; } = null!;
    }
}
