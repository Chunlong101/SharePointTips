using MCPSharp;

namespace SharePointMcpServer
{
    internal class Program
    {
        static async Task Main(string[] args)
        {
            MCPServer.Register<CalculatorTool>();
            MCPServer.Register<SharePointTool>();
            await MCPServer.StartAsync("SharePoint MCP Server", "1.0.0");
        }
    }
}
