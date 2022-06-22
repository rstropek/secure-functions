using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using HeroApi.Services;

namespace HeroApi;

/// <summary>
/// Health check functions
/// </summary>
public class Health
{
    private readonly TableService tableService;
    private readonly SecretProvider secretProvider;
    private readonly DnsUtil dns;

    #region DTOs
    internal record HealthCheckResponse(
        bool IsAspNetCoreHealthy,
        bool IsTableStorageHealthy,
        bool IsKeyVaultHealthy,
        string TableStorageIp)
    {
        public HealthCheckResponse() : this(true, false, false, string.Empty) { }

        public bool IsTotallyHealthy => IsAspNetCoreHealthy && IsTableStorageHealthy && IsKeyVaultHealthy;
    }
    #endregion

    public Health(TableService tableService, SecretProvider secretProvider, DnsUtil dns)
    {
        this.tableService = tableService;
        this.secretProvider = secretProvider;
        this.dns = dns;
    }

    [FunctionName(nameof(Healthy))]
    public async Task<IActionResult> Healthy(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = null)] HttpRequest req,
        ILogger log)
    {
        var health = new HealthCheckResponse();
        //health = await CheckTableHealth(log, health);
        health = await CheckKeyVaultHealth(log, health);
        //health = health with { TableStorageIp = dns.ResolveDnsName($"{Environment.GetEnvironmentVariable("TableStorageAccountName")}.table.core.windows.net") };
        health = health with { TableStorageIp = $"{Environment.GetEnvironmentVariable("TableStorageAccountName")}.table.core.windows.net" };
        return health.IsTotallyHealthy switch 
        {
            true => new OkObjectResult(health),
            false => new ObjectResult(health) { StatusCode = StatusCodes.Status500InternalServerError }
        };
    }

    private async Task<HealthCheckResponse> CheckKeyVaultHealth(ILogger log, HealthCheckResponse health)
    {
        try
        {
            var existsFlags = await secretProvider.SecretsExistsAsync(new[] { "DataStorageConnectionString" });
            var zohoRefreshTokenExists = existsFlags.All(f => f);
            health = health with { IsKeyVaultHealthy = zohoRefreshTokenExists };
        }
        catch (Exception ex)
        {
            log.LogError(ex, "Key Vault related error during health check");
            health = health with { IsKeyVaultHealthy = false };
        }

        return health;
    }

    private async Task<HealthCheckResponse> CheckTableHealth(ILogger log, HealthCheckResponse health)
    {
        try
        {
            var tableExists = await tableService.TableExistsAsync("data");
            health = health with { IsTableStorageHealthy = tableExists };
        }
        catch (Exception ex)
        {
            log.LogError(ex, "Table storage related error during health check");
            health = health with { IsTableStorageHealthy = false };
        }

        return health;
    }
}
