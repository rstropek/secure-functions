using Microsoft.AspNetCore.Http;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;

namespace HeroApi;

/// <summary>
/// Simplest possible health check funtion.
/// </summary>
/// <remarks>
/// This function can be used to perform the simplest possible health check. It
/// does not require any services in DI or any external services. Call it to see
/// whether there is a general problem with all HTTP handlers.
/// </remarks>
public class HealthPing
{
    [FunctionName(nameof(Ping))]
    public string Ping(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = null)] HttpRequest req
    ) => "Pong";
}
