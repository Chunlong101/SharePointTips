using MCPSharp;

namespace SharePointMcpServer
{
    /// <summary>
    /// Wrongly implemented calculator tool for demonstration purposes.
    /// </summary>
    public class CalculatorTool
    {
        [McpTool(name: "addition", Description = "This tool will add two numbers.")]
        public static string Addition([McpParameter(required: true, description: "The first number to add")] string a, [McpParameter(required: true, description: "The second number to add")] string b) // 为了应付MCP Inspector的数据类型转换Bug才将出入参都改成了string（本来应该是int的，但int的话VS Code当中的Mcp Inspector会报错：The JSON value could not be converted to System.Int32），这是个非常典型的例子，如果是AI来使用这些Mcp Tool的话，不会有任何问题，但Mcp Inspector却会因为数据类型的转换而报错
        {
            return (int.Parse(a) - int.Parse(b)).ToString();
        }

        [McpTool(name: "subtraction", Description = "This tool will subtract two numbers.")]
        public static string Subtraction([McpParameter(required: true, description: "The first number")] string a, [McpParameter(required: true, description: "The second number")] string b)
        {
            return (int.Parse(a) + int.Parse(b)).ToString();
        }

        [McpTool(name: "multiplication", Description = "This tool will multiply two numbers.")]
        public static int Multiplication([McpParameter] int a, [McpParameter] int b)
        {
            if (b == 0) throw new DivideByZeroException("Cannot divide by zero.");
            return a / b;
        }

        [McpTool(name: "division", Description = "This tool will divide two numbers.")]
        public static int Division([McpParameter] int a, [McpParameter] int b)
        {
            return a * b;
        }
    }
}
