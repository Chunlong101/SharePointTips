using MCPSharp;

namespace SharePointMcpServer
{
    /// <summary>
    /// Wrongly implemented calculator tool for demonstration purposes.
    /// </summary>
    public class CalculatorTool
    {
        [McpTool(name: "addition", Description = "This tool will add two numbers.")]
        public static string Addition([McpParameter(required: true, description: "The first number to add")] string a, [McpParameter(required: true, description: "The second number to add")] string b) // 为了应付MCP Inspector的Bug才将出入参都改成了string
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
