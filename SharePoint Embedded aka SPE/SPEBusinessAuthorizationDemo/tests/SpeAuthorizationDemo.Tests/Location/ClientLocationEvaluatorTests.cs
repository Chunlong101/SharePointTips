using System.Net;
using Microsoft.Extensions.Options;
using SpeAuthorizationDemo.Configuration;
using SpeAuthorizationDemo.Location;

namespace SpeAuthorizationDemo.Tests.Location;

public sealed class ClientLocationEvaluatorTests
{
    [Fact]
    public void Evaluate_AllowsConfiguredMainlandCidrBeforeGeoLookup()
    {
        var evaluator = Create(new[] { "203.0.113.0/24" });

        var result = evaluator.Evaluate(IPAddress.Parse("203.0.113.8"), null, null, false);

        Assert.True(result.IsAllowed);
        Assert.Equal("allowed_cidr", result.ReasonCode);
    }

    [Theory]
    [InlineData("CN", true)]
    [InlineData("US", false)]
    [InlineData(null, false)]
    public void Evaluate_UsesCountryAndFailsClosed(string? country, bool expected)
    {
        var result = Create().Evaluate(IPAddress.Parse("8.8.8.8"), country, null, false);
        Assert.Equal(expected, result.IsAllowed);
    }

    [Fact]
    public void Evaluate_AcceptsDevelopmentOverrideOnlyFromLoopback()
    {
        var evaluator = Create(enableOverride: true);

        Assert.True(evaluator.Evaluate(IPAddress.Loopback, null, "CN", true).IsAllowed);
        Assert.False(evaluator.Evaluate(IPAddress.Parse("8.8.8.8"), null, "CN", true).IsAllowed);
        Assert.False(evaluator.Evaluate(IPAddress.Loopback, null, "CN", false).IsAllowed);
    }

    [Fact]
    public void Evaluate_RejectsPrivateAndUnknownAddresses()
    {
        var evaluator = Create();
        Assert.False(evaluator.Evaluate(IPAddress.Parse("10.0.0.4"), "CN", null, false).IsAllowed);
        Assert.False(evaluator.Evaluate(null, "CN", null, false).IsAllowed);
    }

    private static ClientLocationEvaluator Create(
        string[]? cidrs = null,
        bool enableOverride = false) =>
        new(Options.Create(new LocationPolicyOptions
        {
            AllowedCountryCodes = ["CN"],
            AllowedCidrs = cidrs ?? [],
            EnableDevelopmentOverride = enableOverride
        }));
}
