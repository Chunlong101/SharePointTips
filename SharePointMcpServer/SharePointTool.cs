using MCPSharp;

namespace SharePointMcpServer
{
    public class SharePointTool
    {
        [McpTool(name: "get_sharepoint_lists", Description = "Get SharePoint site lists")]
        public static async Task<string> GetSharePointLists()
        {
            try
            {
                return await SharePointConnectors.GraphConnector.GetSiteListsAsync();
            }
            catch (HttpRequestException httpEx)
            {
                return $"HTTP Error: {httpEx.Message}";
            }
            catch (TimeoutException timeoutEx)
            {
                return $"Timeout Error: {timeoutEx.Message}";
            }
            catch (Exception ex)
            {
                return $"错误: {ex.Message}";
            }
        }

        [McpTool(name: "get_sharepoint_listitems", Description = "Get SharePoint list items")]
        public static async Task<string> GetSharePointListItems([McpParameter(required: true, description: "SharePoint list id")] string ListId)
        {
            try
            {
                return await SharePointConnectors.GraphConnector.GetListItemsAsync(ListId);
            }
            catch (HttpRequestException httpEx)
            {
                return $"HTTP Error: {httpEx.Message}";
            }
            catch (TimeoutException timeoutEx)
            {
                return $"Timeout Error: {timeoutEx.Message}";
            }
            catch (Exception ex)
            {
                return $"错误: {ex.Message}";
            }
        }
    }
}
