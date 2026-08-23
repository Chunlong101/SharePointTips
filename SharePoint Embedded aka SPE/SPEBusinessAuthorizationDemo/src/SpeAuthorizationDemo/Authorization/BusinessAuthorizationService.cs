using System.Security.Claims;
using Microsoft.Extensions.Options;
using SpeAuthorizationDemo.Authentication;
using SpeAuthorizationDemo.Configuration;
using SpeAuthorizationDemo.Location;

namespace SpeAuthorizationDemo.Authorization;

public interface IBusinessAuthorizationService
{
    Task<AuthorizationDecision> AuthorizeAsync(
        ClaimsPrincipal user,
        HttpContext httpContext,
        BusinessOperation operation,
        CancellationToken cancellationToken);
}

public sealed class BusinessAuthorizationService : IBusinessAuthorizationService
{
    private readonly IUserIdentityReader identityReader;
    private readonly IGroupMembershipResolver groupResolver;
    private readonly IClientLocationEvaluator locationEvaluator;
    private readonly IGeoCountryResolver countryResolver;
    private readonly AuthorizationEngine engine;
    private readonly IHostEnvironment environment;
    private readonly ILogger<BusinessAuthorizationService> logger;
    private readonly HashSet<Guid> relevantGroups;
    private readonly Guid allowedTenantId;

    public BusinessAuthorizationService(
        IUserIdentityReader identityReader,
        IGroupMembershipResolver groupResolver,
        IClientLocationEvaluator locationEvaluator,
        IGeoCountryResolver countryResolver,
        AuthorizationEngine engine,
        IHostEnvironment environment,
        IOptions<AuthorizationPolicyOptions> options,
        ILogger<BusinessAuthorizationService> logger)
    {
        this.identityReader = identityReader;
        this.groupResolver = groupResolver;
        this.locationEvaluator = locationEvaluator;
        this.countryResolver = countryResolver;
        this.engine = engine;
        this.environment = environment;
        this.logger = logger;
        relevantGroups =
        [
            Guid.Parse(options.Value.ReaderGroupId),
            Guid.Parse(options.Value.WriterGroupId),
            Guid.Parse(options.Value.AdminGroupId)
        ];
        allowedTenantId = Guid.Parse(options.Value.AllowedTenantId);
    }

    public async Task<AuthorizationDecision> AuthorizeAsync(
        ClaimsPrincipal user,
        HttpContext httpContext,
        BusinessOperation operation,
        CancellationToken cancellationToken)
    {
        var identityResult = identityReader.Read(user);
        if (!identityResult.IsSuccess)
            return Denied(operation, identityResult.ReasonCode);

        var identity = identityResult.Identity!;
        if (identity.TenantId != allowedTenantId)
            return Denied(operation, "tenant_not_allowed");

        var groupResult = await groupResolver.ResolveAsync(identity, relevantGroups, cancellationToken);
        if (!groupResult.IsSuccess)
            return Denied(operation, groupResult.ReasonCode);

        var sourceIp = httpContext.Connection.RemoteIpAddress;
        var country = sourceIp is null
            ? null
            : await countryResolver.ResolveCountryCodeAsync(sourceIp, cancellationToken);
        var developmentOverride = httpContext.Request.Query["testLocation"].FirstOrDefault();
        var location = locationEvaluator.Evaluate(
            sourceIp,
            country,
            developmentOverride,
            environment.IsDevelopment());
        var resolvedIdentity = identity with { GroupIds = groupResult.GroupIds };
        var decision = engine.Decide(resolvedIdentity, location, operation);

        logger.LogInformation(
            "Authorization {Decision}: tenant={TenantId}, user={ObjectId}, ip={SourceIp}, country={Country}, operation={Operation}, role={Role}, reason={Reason}.",
            decision.IsAllowed ? "allowed" : "denied",
            identity.TenantId,
            identity.ObjectId,
            sourceIp,
            location.CountryCode,
            operation,
            decision.Role,
            decision.ReasonCode);
        return decision;
    }

    private static AuthorizationDecision Denied(BusinessOperation operation, string reason) =>
        new(false, BusinessRole.None, operation, reason);
}
