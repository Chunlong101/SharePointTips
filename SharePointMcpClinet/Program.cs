using MCPSharp;
using MCPSharp.Model;
using System.Diagnostics;

namespace SharePointMcpClinet
{
    internal class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("=== SharePoint MCP Client Starting ===");
            Console.WriteLine($"Application started at: {DateTime.Now:yyyy-MM-dd HH:mm:ss}");
            Console.WriteLine($"Command line arguments: {string.Join(" ", args)}");
            Console.WriteLine();

            try
            {
                Console.WriteLine("Initializing MCP Client...");
                var serverPath = "C:/Users/chunlonl/source/repos/SharePointTips/SharePointMcpServer/bin/Debug/net9.0/SharePointMcpServer.exe";
                Console.WriteLine($"Server path: {serverPath}");
                Console.WriteLine($"Client name: SharePoint MCP Client");
                Console.WriteLine($"Client version: 1.0.0");

                var stopwatch = Stopwatch.StartNew();
                var client = new MCPClient("SharePoint MCP Client", "1.0.0", serverPath);
                stopwatch.Stop();
                Console.WriteLine($"✓ MCP Client initialized successfully in {stopwatch.ElapsedMilliseconds}ms");
                Console.WriteLine();

                Console.WriteLine("=== Discovering Available Tools ===");
                stopwatch.Restart();
                List<Tool> tools = client.GetToolsAsync().GetAwaiter().GetResult();
                stopwatch.Stop();
                Console.WriteLine($"✓ Found {tools.Count} tools in {stopwatch.ElapsedMilliseconds}ms");
                Console.WriteLine();

                foreach (var tool in tools)
                {
                    Console.WriteLine($"🔧 Tool Name: {tool.Name}");
                    Console.WriteLine($"   Description: {tool.Description}");

                    if (tool.InputSchema?.Properties != null)
                    {
                        Console.WriteLine($"   Parameters ({tool.InputSchema.Properties.Count} total):");
                        foreach (var param in tool.InputSchema.Properties)
                        {
                            var isRequired = tool.InputSchema.Required?.Contains(param.Key) == true ? " (Required)" : " (Optional)";
                            Console.WriteLine($"     • {param.Key}: {param.Value.Type ?? "unknown"}{isRequired}");
                            if (!string.IsNullOrEmpty(param.Value.Description))
                            {
                                Console.WriteLine($"       📝 {param.Value.Description}");
                            }
                        }
                    }
                    else
                    {
                        Console.WriteLine("   Parameters: None");
                    }

                    Console.WriteLine("   ---");
                }

                Console.WriteLine("\n=== Tool Invocation Examples ===");
                Console.WriteLine($"Starting tool invocations at: {DateTime.Now:HH:mm:ss}");
                Console.WriteLine();

                ExecuteToolWithLogging(client, "addition", new Dictionary<string, object> { { "a", "1" }, { "b", "1" } }, "Addition");
                ExecuteToolWithLogging(client, "subtraction", new Dictionary<string, object> { { "a", "2" }, { "b", "2" } }, "Subtraction");
                ExecuteToolWithLogging(client, "multiplication", new Dictionary<string, object> { { "a", 3 }, { "b", 3 } }, "Multiplication");
                ExecuteToolWithLogging(client, "division", new Dictionary<string, object> { { "a", 4 }, { "b", 4 } }, "Division");
                ExecuteToolWithLogging(client, "get_sharepoint_lists", null, "Get SharePoint Lists");
                ExecuteToolWithLogging(client, "get_sharepoint_listitems", new Dictionary<string, object> { { "ListId", "ed8cc489-0d8d-46d4-ad3e-3f67c16ae889" } }, "Get SharePoint List Items");

                Console.WriteLine("\n=== Application Completed Successfully ===");
                Console.WriteLine($"Total execution time: {DateTime.Now:yyyy-MM-dd HH:mm:ss}");
            }
            catch (Exception ex)
            {
                Console.WriteLine("\n❌ FATAL ERROR occurred:");
                Console.WriteLine($"Error Type: {ex.GetType().Name}");
                Console.WriteLine($"Error Message: {ex.Message}");
                Console.WriteLine($"Stack Trace:\n{ex.StackTrace}");

                if (ex.InnerException != null)
                {
                    Console.WriteLine($"\nInner Exception: {ex.InnerException.Message}");
                }
            }
            finally
            {
                Console.WriteLine("\nPress any key to exit...");
                Console.Read();
            }
        }

        private static void ExecuteToolWithLogging(MCPClient client, string toolName, Dictionary<string, object>? parameters, string displayName)
        {
            try
            {
                Console.WriteLine($"🚀 Executing: {displayName} (Tool: {toolName})");

                if (parameters != null && parameters.Count > 0)
                {
                    Console.WriteLine("   Input Parameters:");
                    foreach (var param in parameters)
                    {
                        Console.WriteLine($"     • {param.Key}: {param.Value} ({param.Value?.GetType().Name ?? "null"})");
                    }
                }
                else
                {
                    Console.WriteLine("   Input Parameters: None");
                }

                var stopwatch = Stopwatch.StartNew();
                var result = client.CallToolAsync(toolName, parameters).GetAwaiter().GetResult();
                stopwatch.Stop();

                Console.WriteLine($"   ⏱️  Execution time: {stopwatch.ElapsedMilliseconds}ms");

                // Based on original code structure, result.Content[0].Text suggests it's an array/list
                if (result.Content != null && result.Content.Length > 0)
                {
                    Console.WriteLine($"   📤 Response received with {result.Content.Length} content item(s)");
                    for (int i = 0; i < result.Content.Length; i++)
                    {
                        var content = result.Content[i];
                        Console.WriteLine($"   📋 Content[{i}]: {content.Text}");
                        Console.WriteLine($"       Type: {content.Type}");
                    }
                }
                else
                {
                    Console.WriteLine("   📤 Response received with 0 content items");
                }

                if (result.IsError)
                {
                    Console.WriteLine($"   ⚠️  Tool reported error: {result.IsError}");
                }

                Console.WriteLine($"   ✅ {displayName} completed successfully");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"   ❌ Error executing {displayName}:");
                Console.WriteLine($"      Error Type: {ex.GetType().Name}");
                Console.WriteLine($"      Error Message: {ex.Message}");

                if (ex.InnerException != null)
                {
                    Console.WriteLine($"      Inner Exception: {ex.InnerException.Message}");
                }
            }

            Console.WriteLine();
        }
    }
}
