using Microsoft.Azure.Functions.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection;
using Azure.Data.Tables;
using Azure.Identity;
using Azure.Security.KeyVault.Secrets;
using HeroApi.Services;
using System.Runtime.CompilerServices;

[assembly: FunctionsStartup(typeof(HeroApi.Startup))]

namespace HeroApi;

public class Startup : FunctionsStartup
{
    public override void Configure(IFunctionsHostBuilder builder)
    {
        builder.Services.AddSingleton(DefaultOptions);

        builder.Services.AddSingleton(new TableServiceClient(
            new Uri($"https://{Environment.GetEnvironmentVariable("TableStorageAccountName")}.table.core.windows.net"),
            new DefaultAzureCredential()));
        builder.Services.AddSingleton(new SecretClient(
            new Uri($"https://{Environment.GetEnvironmentVariable("KeyVaultName")}.vault.azure.net"),
            new DefaultAzureCredential()));
        builder.Services.AddSingleton<TableService>();
        builder.Services.AddSingleton<SecretProvider>();
        builder.Services.AddSingleton<DnsUtil>();
    }

    internal static JsonSerializerOptions DefaultOptions { get; } = new JsonSerializerOptions
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        Converters =
            {
                new JsonStringEnumConverter(JsonNamingPolicy.CamelCase),
                new DateOnlyConverter(),
            }
    };
}
