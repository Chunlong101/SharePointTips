namespace SpeAuthorizationDemo.Models;

public sealed record SpeDriveItem(string Id, string Name, long Size, string? WebUrl, bool IsFolder = false);
public sealed record SpeDownload(Stream Content, string FileName, string ContentType);
