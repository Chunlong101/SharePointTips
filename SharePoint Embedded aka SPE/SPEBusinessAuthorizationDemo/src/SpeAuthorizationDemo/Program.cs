using System.Net;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.Identity.Web;
using Microsoft.Identity.Web.UI;
using SpeAuthorizationDemo.Authentication;
using SpeAuthorizationDemo.Authorization;
using SpeAuthorizationDemo.Configuration;
using SpeAuthorizationDemo.Graph;
using SpeAuthorizationDemo.Location;

var builder = WebApplication.CreateBuilder(args);
builder.Configuration.AddJsonFile("appsettings.Local.json", optional: true, reloadOnChange: true);

builder.Services.Configure<AzureAdOptions>(builder.Configuration.GetSection(AzureAdOptions.SectionName));
builder.Services.Configure<SpeOptions>(builder.Configuration.GetSection(SpeOptions.SectionName));
builder.Services.Configure<AuthorizationPolicyOptions>(builder.Configuration.GetSection(AuthorizationPolicyOptions.SectionName));
builder.Services.Configure<LocationPolicyOptions>(builder.Configuration.GetSection(LocationPolicyOptions.SectionName));
builder.Services.AddHostedService<DemoConfigurationStartupValidator>();

builder.Services
    .AddAuthentication(OpenIdConnectDefaults.AuthenticationScheme)
    .AddMicrosoftIdentityWebApp(builder.Configuration.GetSection(AzureAdOptions.SectionName))
    .EnableTokenAcquisitionToCallDownstreamApi([
        "https://microsoftgraph.chinacloudapi.cn/FileStorageContainer.Selected",
        "https://microsoftgraph.chinacloudapi.cn/GroupMember.Read.All"
    ])
    .AddInMemoryTokenCaches();

builder.Services.AddAuthorization();
builder.Services.AddRazorPages().AddMicrosoftIdentityUI();
builder.Services.AddHttpClient("SpeGraph");
builder.Services.AddHttpClient<GraphGroupMembershipFallback>();
builder.Services.AddScoped<IUserIdentityReader, ClaimsUserIdentityReader>();
builder.Services.AddScoped<IGroupMembershipFallback>(provider => provider.GetRequiredService<GraphGroupMembershipFallback>());
builder.Services.AddScoped<IGroupMembershipResolver, CompositeGroupMembershipResolver>();
builder.Services.AddScoped<IClientLocationEvaluator, ClientLocationEvaluator>();
builder.Services.AddSingleton<IGeoCountryResolver, MaxMindGeoCountryResolver>();
builder.Services.AddScoped<AuthorizationEngine>();
builder.Services.AddScoped<IBusinessAuthorizationService, BusinessAuthorizationService>();
builder.Services.AddScoped<IDelegatedGraphAccessTokenProvider, DelegatedGraphAccessTokenProvider>();
builder.Services.AddScoped<IAppOnlyGraphAccessTokenProvider, AppOnlyGraphAccessTokenProvider>();
builder.Services.AddScoped<ISpeGraphClientFactory, SpeGraphClientFactory>();

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    options.ForwardLimit = 1;
    options.KnownProxies.Clear();
    foreach (var proxy in builder.Configuration.GetSection("LocationPolicy:KnownProxies").Get<string[]>() ?? [])
        if (IPAddress.TryParse(proxy, out var address)) options.KnownProxies.Add(address);
    foreach (var cidr in builder.Configuration.GetSection("LocationPolicy:KnownNetworks").Get<string[]>() ?? [])
    {
        var parts = cidr.Split('/', 2);
        if (parts.Length == 2 && IPAddress.TryParse(parts[0], out var networkAddress) && int.TryParse(parts[1], out var prefixLength))
            options.KnownNetworks.Add(new Microsoft.AspNetCore.HttpOverrides.IPNetwork(networkAddress, prefixLength));
    }
});

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

app.UseForwardedHeaders();
app.UseHttpsRedirection();

app.UseRouting();

app.UseAuthentication();
app.UseAuthorization();

app.MapStaticAssets();
app.MapControllers();
app.MapRazorPages()
   .WithStaticAssets();

app.Run();

public partial class Program;
