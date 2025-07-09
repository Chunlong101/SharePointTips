using MCPSharp;

namespace SharePointMcpServer
{
    internal class Program
    {
        static async Task Main(string[] args)
        {
            MCPServer.RegisterTool<CalculatorTool>();
            MCPServer.RegisterTool<SharePointTool>();
            await MCPServer.StartAsync("SharePoint MCP Server", "1.0.0");
        }
    }
}
