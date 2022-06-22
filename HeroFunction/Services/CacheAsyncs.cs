using System.Collections.Concurrent;

namespace HeroApi.Services;

public class CacheAsyncs<T> where T: class
{
    private readonly ConcurrentDictionary<string, T> itemsCache = new();
    private readonly Func<string, Task<T>> itemGetter;

    public CacheAsyncs(Func<string, Task<T>> itemGetter)
    {
        this.itemGetter = itemGetter;
    }

    public async Task<T> GetItemAsync(string key)
    {
        if (itemsCache.TryGetValue(key, out var chachedItem))
        {
            return chachedItem;
        }

        var result = await itemGetter(key);
        itemsCache[key] = result;
        return result;
    }

    public async Task<T[]> GetItemsAsync(IEnumerable<string> keys)
    {
        var tasks = keys.Select(k => GetItemAsync(k));
        await Task.WhenAll(tasks);
        return tasks.Select(t => t.Result).ToArray();
    }
}