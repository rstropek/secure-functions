namespace HeroApi.Services;

/// <summary>
/// Add JSON serialization support for <see cref="System.DateOnly"/>.
/// </summary>
/// <remarks>
/// This code is necessary because the <see cref="System.DateTime"/> type does not support
/// JSON serialization yet. This code can be removed once Microsoft fixes the issue.
/// </remarks>
public class DateOnlyConverter : JsonConverter<DateOnly>
{
    public override DateOnly Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
        => DateOnly.Parse(reader.GetString()!);

    public override void Write(Utf8JsonWriter writer, DateOnly value, JsonSerializerOptions options)
        => writer.WriteStringValue(value.ToString("yyyy-MM-dd"));
}
