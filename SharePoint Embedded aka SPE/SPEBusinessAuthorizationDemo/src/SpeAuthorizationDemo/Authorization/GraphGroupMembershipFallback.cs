using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Identity.Web;
using SpeAuthorizationDemo.Authentication;

namespace SpeAuthorizationDemo.Authorization;

public sealed class GraphGroupMembershipFallback(
    HttpClient httpClient,
    ITokenAcquisition tokenAcquisition,
    ILogger<GraphGroupMembershipFallback> logger) : IGroupMembershipFallback
{
    public async Task<GroupResolutionResult> ResolveAsync(
        UserIdentity identity,
        IReadOnlySet<Guid> relevantGroupIds,
        CancellationToken cancellationToken)
    {
        if (relevantGroupIds.Count == 0) return GroupResolutionResult.Success(new HashSet<Guid>());
        try
        {
            var token = await tokenAcquisition.GetAccessTokenForUserAsync(
                ["https://microsoftgraph.chinacloudapi.cn/GroupMember.Read.All"]);
            using var request = new HttpRequestMessage(
                HttpMethod.Post,
                "https://microsoftgraph.chinacloudapi.cn/v1.0/me/checkMemberGroups");
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
            request.Content = JsonContent.Create(new { groupIds = relevantGroupIds.Select(id => id.ToString()).ToArray() });
            using var response = await httpClient.SendAsync(request, cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                logger.LogWarning("Group membership fallback failed with HTTP {StatusCode} for user {ObjectId}.",
                    (int)response.StatusCode, identity.ObjectId);
                return GroupResolutionResult.Failure("group_fallback_failed");
            }

            await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
            using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
            var groups = document.RootElement.GetProperty("value").EnumerateArray()
                .Select(value => Guid.TryParse(value.GetString(), out var id) ? id : Guid.Empty)
                .Where(id => id != Guid.Empty)
                .ToHashSet();
            return GroupResolutionResult.Success(groups);
        }
        catch (MicrosoftIdentityWebChallengeUserException exception)
        {
            logger.LogInformation(
                "Delegated token reauthentication is required for user {ObjectId}: {ExceptionType}.",
                identity.ObjectId,
                exception.GetType().Name);
            return GroupResolutionResult.Failure("reauthentication_required");
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            logger.LogWarning("Group membership fallback failed for user {ObjectId}: {ExceptionType}.",
                identity.ObjectId, exception.GetType().Name);
            return GroupResolutionResult.Failure("group_fallback_failed");
        }
    }
}
