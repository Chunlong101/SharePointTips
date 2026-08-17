namespace SpeAuthorizationDemo.Graph;

public static class FileNamePolicy
{
    public static bool IsAllowed(string? fileName)
    {
        if (string.IsNullOrWhiteSpace(fileName) || fileName is "." or "..") return false;
        if (fileName.Contains('/') || fileName.Contains('\\') || fileName.Contains("..", StringComparison.Ordinal)) return false;
        return !fileName.Any(char.IsControl) && fileName.IndexOfAny(Path.GetInvalidFileNameChars()) < 0;
    }

    public static bool IsAllowedLength(long length, long maximum) => length > 0 && maximum > 0 && length <= maximum;
}
