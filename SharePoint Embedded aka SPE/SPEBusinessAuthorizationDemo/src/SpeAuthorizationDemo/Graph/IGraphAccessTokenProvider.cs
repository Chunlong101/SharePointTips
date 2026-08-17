namespace SpeAuthorizationDemo.Graph;

public interface IGraphAccessTokenProvider
{
    Task<string> GetTokenAsync(CancellationToken cancellationToken);
}
