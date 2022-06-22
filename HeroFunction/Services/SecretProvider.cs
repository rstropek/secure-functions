using System.Collections.Concurrent;
using Azure.Security.KeyVault.Secrets;

namespace HeroApi.Services;

public class SecretProvider
{
    private readonly SecretClient secretClient;

    private readonly CacheAsyncs<string> secretsCache;

    public SecretProvider(SecretClient secretClient)
    {
        this.secretClient = secretClient;
        secretsCache = new(async secretName => (await secretClient.GetSecretAsync(secretName)).Value.Value);
    }

    /// <inheritdoc />
    public async Task<bool> SecretExistsAsync(string secretName)
    {
        var result = await secretClient.GetSecretAsync(secretName);
        return result.Value != null;
    }

    /// <inheritdoc />
    public async Task<bool[]> SecretsExistsAsync(IEnumerable<string> secretNames)
    {
        var getterTasks = secretNames.Select(name => SecretExistsAsync(name));
        await Task.WhenAll(getterTasks);
        return getterTasks.Select(task => task.Result).ToArray();
    }

    /// <inheritdoc />
    public async Task<string[]> GetSecretsAsync(IEnumerable<string> secretNames)
        => await secretsCache.GetItemsAsync(secretNames);

    /// <inheritdoc />
    public async Task<string> GetSecretAsync(string secretName)
        => await secretsCache.GetItemAsync(secretName);
}
