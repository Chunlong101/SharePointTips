namespace SpeAuthorizationDemo.Graph;

public sealed class SpeFolderDeleteNotAllowedException()
    : InvalidOperationException("Folder deletion is not allowed by this application.");