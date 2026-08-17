namespace SpeAuthorizationDemo.Models;

public sealed record SpeDriveItem(string Id, string Name, long Size, string? WebUrl);
public sealed record SpeDownload(Stream Content, string FileName, string ContentType);
