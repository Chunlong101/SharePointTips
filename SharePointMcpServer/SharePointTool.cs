using MCPSharp;

namespace SharePointMcpServer
{
    public class SharePointTool
    {
        [McpTool(name: "get_sharepoint_lists", Description = "获取SharePoint站点的所有列表")]
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

        [McpTool(name: "get_sharepoint_listitems", Description = "获取SharePoint站点列表中的所有项目")]
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
