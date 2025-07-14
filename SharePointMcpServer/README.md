# SharePoint MCP Server

A Model Context Protocol (MCP) based SharePoint server that provides SharePoint data access and calculation tools through MCP protocol.

## ?? Table of Contents

- [Project Overview](#project-overview)
- [Features](#features)
- [Technology Stack](#technology-stack)
- [Project Structure](#project-structure)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [MCP Tools Usage](#mcp-tools-usage)
- [Development Guide](#development-guide)
- [Error Handling](#error-handling)
- [Dependencies](#dependencies)
- [Important Notes](#important-notes)
- [Contributing](#contributing)
- [Support](#support)

## ?? Project Overview

SharePoint MCP Server is an MCP server application built with .NET 9 that provides access to SharePoint data through Microsoft Graph API, along with demonstration calculation tools. This server can serve as a tool provider for MCP clients (such as Claude Desktop).

## ? Features

### ?? SharePoint Tools
- **Get SharePoint Site Lists** (`get_sharepoint_lists`): Retrieve all lists in a specified SharePoint site
- **Get SharePoint List Items** (`get_sharepoint_listitems`): Retrieve all item data from a specified list

### ?? Calculator Tools (For Demonstration)
- **Addition** (`addition`): Add two numbers (Note: Intentionally implemented as subtraction for demonstration)
- **Subtraction** (`subtraction`): Subtract two numbers (Note: Intentionally implemented as addition for demonstration)
- **Multiplication** (`multiplication`): Multiply two numbers (Note: Intentionally implemented as division for demonstration)
- **Division** (`division`): Divide two numbers (Note: Intentionally implemented as multiplication for demonstration)

> **?? Note**: Calculator tools are intentionally implemented incorrectly to demonstrate MCP Inspector data type conversion issues.

## ??? Technology Stack

- **.NET 9**: Latest .NET framework
- **MCPSharp** (v1.0.11): C# implementation of MCP protocol
- **SharePointConnectors**: Custom SharePoint connector library

## ?? Project Structure
SharePointMcpServer/
©À©¤©¤ Program.cs                    # Application entry point
©À©¤©¤ SharePointTool.cs             # SharePoint-related MCP tools
©À©¤©¤ CalculatorTool.cs             # Calculator tools (for demonstration)
©À©¤©¤ SharePointMcpServer.csproj    # Project file
©¸©¤©¤ README.md                     # Project documentation
## ?? Quick Start

### Prerequisites

- .NET 9 SDK
- Valid Microsoft Azure AD app registration
- SharePoint site access permissions

### Installation and Setup

1. **Clone the project**git clone <repository-url>
   cd SharePointMcpServer
2. **Configure SharePoint Connection**
   
   Before running, configure the GraphConnectorConfiguration in the SharePointConnectors project:
   - Tenant ID
   - Client ID  
   - Client Secret
   - Site ID

3. **Build the project**dotnet build
4. **Run the server**dotnet run
## ?? Configuration

The server depends on the SharePointConnectors library for SharePoint access. Ensure correct configuration in GraphConnectorConfiguration:

| Parameter | Description |
|-----------|-------------|
| **TenantId** | Azure AD Tenant ID |
| **ClientId** | Application (client) ID |
| **ClientSecret** | Client secret |
| **SiteId** | SharePoint Site ID |

## ?? MCP Tools Usage

### SharePoint Tools

#### Get Site Lists{
  "name": "get_sharepoint_lists",
  "arguments": {}
}
#### Get List Items{
  "name": "get_sharepoint_listitems", 
  "arguments": {
    "ListId": "your-list-id-here"
  }
}
### Calculator Tools (For Demonstration)

#### Addition (Actually performs subtraction){
  "name": "addition",
  "arguments": {
    "a": "10",
    "b": "5" 
  }
}
## ????? Development Guide

### Adding New MCP Tools

1. Add static methods to the appropriate tool class
2. Mark methods with `[McpTool]` attribute
3. Mark parameters with `[McpParameter]` attribute
4. Register the tool class in `Program