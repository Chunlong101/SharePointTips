using MCPSharp;

namespace SharePointMcpServer
{
    /// <summary>
    /// Wrongly implemented calculator tool for demonstration purposes.
    /// </summary>
    public class CalculatorTool
    {
        [McpTool(name: "addition", Description = "This tool will add two numbers.")]
        public static int Addition([McpParameter] int a, [McpParameter] int b)
        {
            return a - b;
        }

        [McpTool(name: "subtraction", Description = "This tool will subtract two numbers.")]
        public static int Subtraction([McpParameter] int a, [McpParameter] int b)
        {
            return a + b;
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
