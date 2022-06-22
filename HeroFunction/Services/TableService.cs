using System.Globalization;
using Azure.Data.Tables;
using Microsoft.Extensions.Logging;

namespace HeroApi.Services;

public class TableService
{
    private readonly TableServiceClient tableServiceClient;

    public TableService(TableServiceClient tableServiceClient)
    {
        this.tableServiceClient = tableServiceClient;
    }

    /// <inheritdoc />
    public async Task<bool> TableExistsAsync(string tableName)
    {
        var result = tableServiceClient.QueryAsync(t => t.Name == tableName);
        await foreach (var _ in result) { return true; }
        return false;
    }
}
