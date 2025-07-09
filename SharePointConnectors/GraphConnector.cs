using RestSharp;
using System.Text.Json;

namespace SharePointConnectors
{
    public static class GraphConnector
    {
        private static string _tenantId = "311ca363-cc76-4086-93a7-94f6b8f4ae2a"; // Replace with your tenant ID
        private static string _clientId = "efec52de-b554-40e0-8596-27a895cb4589"; // Replace with your client ID
        private static string _clientSecret = "xxx"; // Replace with your client secret
        private static string _siteId = "444685b6-d513-4b4d-b8e0-beb9ede84001"; // Replace with your site ID

        public static async Task<string> GetAccessTokenAsync(string tenantId = null, string clientId = null, string clientSecret = null)
        {
            tenantId ??= _tenantId;
            clientId ??= _clientId;
            clientSecret ??= _clientSecret;
            if (string.IsNullOrEmpty(tenantId) || string.IsNullOrEmpty(clientId) || string.IsNullOrEmpty(clientSecret))
            {
                throw new ArgumentException("Tenant ID, Client ID, and Client Secret must be provided.");
            }

            var options = new RestClientOptions("https://login.microsoftonline.com")
            {
                Timeout = TimeSpan.FromMinutes(2),
            };
            var client = new RestClient(options);
            var request = new RestRequest($"/{tenantId}/oauth2/v2.0/token", Method.Post);
            request.AddHeader("Content-Type", "application/x-www-form-urlencoded");
            request.AddHeader("SdkVersion", "postman-graph/v1.0");
            request.AddParameter("grant_type", "client_credentials");
            request.AddParameter("client_id", clientId);
            request.AddParameter("client_secret", clientSecret);
            request.AddParameter("scope", "https://graph.microsoft.com/.default");

            RestResponse response = await client.ExecuteAsync(request);

            if (response.IsSuccessful)
            {
                var tokenResponse = JsonSerializer.Deserialize<JsonElement>(response.Content ?? string.Empty);
                return tokenResponse.GetProperty("access_token").GetString() ?? string.Empty;
            }
            else
            {
                throw new Exception($"Token request failed: {response.StatusCode} - {response.Content}");
            }
        }

        public static async Task<string> GetSiteListsAsync(string AccessToken = null)
        {
            AccessToken ??= await GetAccessTokenAsync();
            if (string.IsNullOrEmpty(AccessToken))
            {
                throw new Exception("Access token is null or empty. Please check your credentials.");
            }

            var options = new RestClientOptions("https://graph.microsoft.com")
            {
                Timeout = TimeSpan.FromMilliseconds(-1),
            };
            var client = new RestClient(options);

            var request = new RestRequest($"/v1.0/sites/{_siteId}/lists", Method.Get);
            request.AddHeader("Content-Type", "application/json");
            request.AddHeader("Authorization", $"Bearer {AccessToken}");

            RestResponse response = await client.ExecuteAsync(request);

            if (response.IsSuccessful)
            {
                return response.Content ?? string.Empty;
            }
            else
            {
                throw new Exception($"API call failed: {response.StatusCode} - {response.Content}");
            }
        }

        public static async Task<string> GetListItemsAsync(string listId, string accessToken = null)
        {
            if (string.IsNullOrEmpty(listId))
            {
                throw new ArgumentException("List ID cannot be null or empty.", nameof(listId));
            }
            accessToken ??= await GetAccessTokenAsync();
            if (string.IsNullOrEmpty(accessToken))
            {
                throw new Exception("Access token is null or empty. Please check your credentials.");
            }

            var options = new RestClientOptions("https://graph.microsoft.com")
            {
                Timeout = TimeSpan.FromMilliseconds(-1),
            };
            var client = new RestClient(options);

            var request = new RestRequest($"/v1.0/sites/{_siteId}/lists/{listId}/items?expand=fields", Method.Get);
            request.AddHeader("Content-Type", "application/json");
            request.AddHeader("Authorization", $"Bearer {accessToken}");

            RestResponse response = await client.ExecuteAsync(request);

            if (response.IsSuccessful)
            {
                return response.Content ?? string.Empty;
            }
            else
            {
                throw new Exception($"API call failed: {response.StatusCode} - {response.Content}");
            }
        }
    }
}
