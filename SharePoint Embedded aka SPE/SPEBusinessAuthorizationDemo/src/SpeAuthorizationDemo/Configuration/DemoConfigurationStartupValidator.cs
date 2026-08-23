using Microsoft.Extensions.Options;

namespace SpeAuthorizationDemo.Configuration;

public sealed class DemoConfigurationStartupValidator(
    IOptions<AzureAdOptions> azureAd,
    IOptions<SpeOptions> spe,
    IOptions<AuthorizationPolicyOptions> authorization) : IHostedService
{
    public Task StartAsync(CancellationToken cancellationToken)
    {
        var errors = DemoOptionsValidator.Validate(azureAd.Value, spe.Value, authorization.Value);
        if (errors.Count > 0)
            throw new OptionsValidationException("SPE authorization demo", typeof(object), errors);
        return Task.CompletedTask;
    }

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}
