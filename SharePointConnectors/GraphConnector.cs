using RestSharp;
using System.Text.Json;
using System.Collections.Concurrent;
using System.Net;

namespace SharePointConnectors
{
    /// <summary>
    /// Microsoft Graph API 连接器的配置类
    /// 包含访问 SharePoint 所需的所有认证和配置信息
    /// </summary>
    /// <remarks>
    /// 此类包含了连接到 Microsoft Graph API 和 SharePoint 所需的基本配置：
    /// - Azure AD 认证信息（租户ID、客户端ID、客户端密钥）
    /// - SharePoint 站点信息
    /// - 性能和缓存相关设置
    /// </remarks>
    public class GraphConnectorConfiguration
    {
        public string TenantId { get; set; } = "311ca363-cc76-4086-93a7-94f6b8f4ae2a";

        public string ClientId { get; set; } = "efec52de-b554-40e0-8596-27a895cb4589";

        public string ClientSecret { get; set; } = "xxx";

        public string SiteId { get; set; } = "444685b6-d513-4b4d-b8e0-beb9ede84001";

        /// <summary>
        /// 访问令牌的缓存超时时间
        /// </summary>
        /// <remarks>
        /// Azure AD 访问令牌默认有效期为60分钟
        /// 设置为55分钟可以提供5分钟的安全缓冲时间，避免使用过期令牌
        /// </remarks>
        public TimeSpan TokenCacheTimeout { get; set; } = TimeSpan.FromMinutes(55);

        public TimeSpan RequestTimeout { get; set; } = TimeSpan.FromMinutes(2);
    }

    /// <summary>
    /// 缓存的访问令牌信息
    /// </summary>
    /// <remarks>
    /// 用于在内存中缓存 Azure AD 访问令牌，避免频繁的认证请求
    /// 包含令牌内容和过期时间信息
    /// </remarks>
    public class CachedToken
    {
        /// <summary>
        /// 访问令牌字符串
        /// </summary>
        public string Token { get; set; } = string.Empty;

        /// <summary>
        /// 令牌过期时间（UTC）
        /// </summary>
        public DateTime ExpiresAt { get; set; }

        /// <summary>
        /// 检查令牌是否仍然有效
        /// </summary>
        /// <returns>如果当前时间小于过期时间，返回 true；否则返回 false</returns>
        public bool IsValid => DateTime.UtcNow < ExpiresAt;
    }

    /// <summary>
    /// Microsoft Graph API 连接器的自定义异常类
    /// </summary>
    /// <remarks>
    /// 提供更详细的错误信息，包括 HTTP 状态码和响应内容
    /// 便于调试和错误处理
    /// </remarks>
    public class GraphConnectorException : Exception
    {
        /// <summary>
        /// HTTP 响应状态码
        /// </summary>
        public HttpStatusCode? StatusCode { get; }

        /// <summary>
        /// HTTP 响应内容
        /// </summary>
        public string? ResponseContent { get; }

        /// <summary>
        /// 创建一个简单的异常实例
        /// </summary>
        /// <param name="message">错误消息</param>
        public GraphConnectorException(string message) : base(message) { }

        /// <summary>
        /// 创建一个包含 HTTP 状态信息的异常实例
        /// </summary>
        /// <param name="message">错误消息</param>
        /// <param name="statusCode">HTTP 状态码</param>
        /// <param name="responseContent">HTTP 响应内容</param>
        public GraphConnectorException(string message, HttpStatusCode? statusCode, string? responseContent)
            : base(message)
        {
            StatusCode = statusCode;
            ResponseContent = responseContent;
        }

        /// <summary>
        /// 创建一个包装内部异常的异常实例
        /// </summary>
        /// <param name="message">错误消息</param>
        /// <param name="innerException">内部异常</param>
        public GraphConnectorException(string message, Exception innerException)
            : base(message, innerException) { }
    }

    /// <summary>
    /// Microsoft Graph API 连接器
    /// </summary>
    /// <remarks>
    /// 这是一个静态类，提供与 Microsoft Graph API 交互的核心功能：
    /// - Azure AD 身份验证和令牌管理
    /// - SharePoint 站点列表获取
    /// - SharePoint 列表项获取
    /// - 智能缓存和性能优化
    /// 
    /// 特性：
    /// - 自动令牌缓存和刷新
    /// - 线程安全的操作
    /// - 共享 HTTP 客户端实例
    /// - 详细的错误处理
    /// </remarks>
    public static class GraphConnector
    {
        #region 私有字段

        /// <summary>
        /// 连接器配置实例
        /// </summary>
        /// <remarks>
        /// 包含所有必要的配置信息，如认证凭据、站点ID等
        /// 可以通过 Configure 方法进行修改
        /// </remarks>
        private static readonly GraphConnectorConfiguration _config = new();

        /// <summary>
        /// 访问令牌缓存
        /// </summary>
        /// <remarks>
        /// 使用 ConcurrentDictionary 确保线程安全
        /// 键格式："{tenantId}:{clientId}"
        /// 值：CachedToken 对象
        /// </remarks>
        private static readonly ConcurrentDictionary<string, CachedToken> _tokenCache = new();

        /// <summary>
        /// Azure AD 认证服务的 HTTP 客户端
        /// </summary>
        /// <remarks>
        /// 使用 Lazy 延迟初始化，仅在需要时创建
        /// 专门用于与 login.microsoftonline.com 的认证交互
        /// </remarks>
        private static readonly Lazy<RestClient> _authClient = new(() =>
            new RestClient(new RestClientOptions("https://login.microsoftonline.com")
            {
                Timeout = _config.RequestTimeout,
            }));

        /// <summary>
        /// Microsoft Graph API 的 HTTP 客户端
        /// </summary>
        /// <remarks>
        /// 使用 Lazy 延迟初始化，仅在需要时创建
        /// 专门用于与 graph.microsoft.com 的 API 交互
        /// </remarks>
        private static readonly Lazy<RestClient> _graphClient = new(() =>
            new RestClient(new RestClientOptions("https://graph.microsoft.com")
            {
                Timeout = _config.RequestTimeout,
            }));

        /// <summary>
        /// JSON 序列化配置选项
        /// </summary>
        /// <remarks>
        /// 配置了驼峰命名策略和大小写不敏感解析
        /// 适用于 Microsoft Graph API 的 JSON 响应格式
        /// </remarks>
        private static readonly JsonSerializerOptions _jsonOptions = new()
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            PropertyNameCaseInsensitive = true
        };

        #endregion

        #region 公共方法

        /// <summary>
        /// 配置 GraphConnector 的设置
        /// </summary>
        /// <param name="configure">配置委托，用于修改配置对象</param>
        /// <remarks>
        /// 此方法允许在运行时修改连接器的配置
        /// 通常在应用程序启动时调用一次
        /// 
        /// 示例：
        /// GraphConnector.Configure(config => {
        ///     config.TenantId = "your-tenant-id";
        ///     config.ClientId = "your-client-id";
        ///     config.ClientSecret = "your-secret";
        /// });
        /// </remarks>
        public static void Configure(Action<GraphConnectorConfiguration> configure)
        {
            configure(_config);
        }

        /// <summary>
        /// 获取或刷新 Azure AD 访问令牌
        /// </summary>
        /// <param name="tenantId">Azure AD 租户ID（可选，默认使用配置中的值）</param>
        /// <param name="clientId">应用客户端ID（可选，默认使用配置中的值）</param>
        /// <param name="clientSecret">应用客户端密钥（可选，默认使用配置中的值）</param>
        /// <returns>有效的访问令牌字符串</returns>
        /// <exception cref="ArgumentException">当必要的认证参数为空时抛出</exception>
        /// <exception cref="GraphConnectorException">当认证失败或网络错误时抛出</exception>
        /// <remarks>
        /// 此方法实现了智能缓存机制：
        /// 1. 首先检查缓存中是否有有效的令牌
        /// 2. 如果缓存中的令牌有效，直接返回
        /// 3. 如果缓存中没有有效令牌，向 Azure AD 请求新令牌
        /// 4. 将新令牌缓存，过期时间设置为令牌实际过期时间减去5分钟
        /// 
        /// 使用 OAuth 2.0 客户端凭据流进行认证
        /// 缓存键格式："{tenantId}:{clientId}"，支持多租户场景
        /// </remarks>
        public static async Task<string> GetAccessTokenAsync(string? tenantId = null, string? clientId = null, string? clientSecret = null)
        {
            // 使用提供的参数或默认配置值
            tenantId ??= _config.TenantId;
            clientId ??= _config.ClientId;
            clientSecret ??= _config.ClientSecret;

            // 验证必要参数
            if (string.IsNullOrEmpty(tenantId) || string.IsNullOrEmpty(clientId) || string.IsNullOrEmpty(clientSecret))
            {
                throw new ArgumentException("Tenant ID, Client ID, and Client Secret must be provided.");
            }

            // 生成缓存键，支持多租户和多应用场景
            var cacheKey = $"{tenantId}:{clientId}";

            // 检查缓存中是否有有效令牌
            if (_tokenCache.TryGetValue(cacheKey, out var cachedToken) && cachedToken.IsValid)
            {
                return cachedToken.Token;
            }

            try
            {
                // 构建 OAuth 2.0 令牌请求
                var request = new RestRequest($"/{tenantId}/oauth2/v2.0/token", Method.Post);
                request.AddHeader("Content-Type", "application/x-www-form-urlencoded");

                // 添加 OAuth 2.0 客户端凭据流所需的参数
                request.AddParameter("grant_type", "client_credentials");
                request.AddParameter("client_id", clientId);
                request.AddParameter("client_secret", clientSecret);
                request.AddParameter("scope", "https://graph.microsoft.com/.default");

                // 发送认证请求
                var response = await _authClient.Value.ExecuteAsync(request);

                // 检查响应是否成功
                if (!response.IsSuccessful)
                {
                    throw new GraphConnectorException(
                        "Failed to obtain access token",
                        response.StatusCode,
                        response.Content);
                }

                // 解析令牌响应
                var tokenResponse = JsonSerializer.Deserialize<JsonElement>(
                    response.Content ?? string.Empty, _jsonOptions);

                // 提取访问令牌
                var accessToken = tokenResponse.GetProperty("access_token").GetString() ?? string.Empty;

                // 提取令牌过期时间（秒），默认为1小时
                var expiresIn = tokenResponse.TryGetProperty("expires_in", out var expiresInElement)
                    ? expiresInElement.GetInt32()
                    : 3600;

                // 计算缓存过期时间，提前5分钟过期以避免使用即将过期的令牌
                var cacheExpiry = DateTime.UtcNow.AddSeconds(expiresIn - 300);

                // 更新缓存（线程安全）
                _tokenCache.AddOrUpdate(cacheKey,
                    new CachedToken { Token = accessToken, ExpiresAt = cacheExpiry },
                    (key, existing) => new CachedToken { Token = accessToken, ExpiresAt = cacheExpiry });

                return accessToken;
            }
            catch (Exception ex) when (!(ex is GraphConnectorException))
            {
                // 包装非 GraphConnectorException 异常
                throw new GraphConnectorException("An error occurred while obtaining access token", ex);
            }
        }

        /// <summary>
        /// 获取 SharePoint 站点中的所有列表
        /// </summary>
        /// <param name="accessToken">访问令牌（可选，如果未提供将自动获取）</param>
        /// <param name="siteId">SharePoint 站点ID（可选，默认使用配置中的值）</param>
        /// <returns>包含站点列表信息的 JSON 字符串</returns>
        /// <exception cref="ArgumentException">当站点ID为空时抛出</exception>
        /// <exception cref="GraphConnectorException">当API调用失败时抛出</exception>
        /// <remarks>
        /// 此方法调用 Microsoft Graph API 获取指定 SharePoint 站点中的所有列表
        /// API 端点：GET /v1.0/sites/{site-id}/lists
        /// 
        /// 返回的 JSON 包含列表的详细信息：
        /// - 列表ID、名称、描述
        /// - 列表类型、模板类型
        /// - 创建和修改时间
        /// - 列表设置和权限信息
        /// 
        /// 如果未提供访问令牌，会自动调用 GetAccessTokenAsync() 获取
        /// </remarks>
        public static async Task<string> GetSiteListsAsync(string? accessToken = null, string? siteId = null)
        {
            // 获取访问令牌（如果未提供）
            accessToken ??= await GetAccessTokenAsync();
            siteId ??= _config.SiteId;

            // 验证必要参数
            if (string.IsNullOrEmpty(accessToken))
            {
                throw new GraphConnectorException("Access token is null or empty. Please check your credentials.");
            }

            if (string.IsNullOrEmpty(siteId))
            {
                throw new ArgumentException("Site ID must be provided.", nameof(siteId));
            }

            try
            {
                // 构建获取站点列表的请求
                var request = new RestRequest($"/v1.0/sites/{siteId}/lists", Method.Get);
                request.AddHeader("Authorization", $"Bearer {accessToken}");
                request.AddHeader("Accept", "application/json");

                // 发送请求
                var response = await _graphClient.Value.ExecuteAsync(request);

                // 检查响应状态
                if (!response.IsSuccessful)
                {
                    throw new GraphConnectorException(
                        "Failed to get site lists",
                        response.StatusCode,
                        response.Content);
                }

                return response.Content ?? string.Empty;
            }
            catch (Exception ex) when (!(ex is GraphConnectorException))
            {
                // 包装非 GraphConnectorException 异常
                throw new GraphConnectorException("An error occurred while getting site lists", ex);
            }
        }

        /// <summary>
        /// 获取 SharePoint 列表中的所有项目
        /// </summary>
        /// <param name="listId">SharePoint 列表ID（必需）</param>
        /// <param name="accessToken">访问令牌（可选，如果未提供将自动获取）</param>
        /// <param name="siteId">SharePoint 站点ID（可选，默认使用配置中的值）</param>
        /// <returns>包含列表项目信息的 JSON 字符串</returns>
        /// <exception cref="ArgumentException">当列表ID为空或站点ID为空时抛出</exception>
        /// <exception cref="GraphConnectorException">当API调用失败时抛出</exception>
        /// <remarks>
        /// 此方法调用 Microsoft Graph API 获取指定列表中的所有项目
        /// API 端点：GET /v1.0/sites/{site-id}/lists/{list-id}/items?expand=fields
        /// 
        /// 使用 expand=fields 参数确保返回项目的所有字段数据
        /// 
        /// 返回的 JSON 包含：
        /// - 项目基本信息（ID、创建时间、修改时间等）
        /// - 项目的所有字段值（在 fields 属性中）
        /// - 项目的版本信息
        /// - 内容类型信息
        /// 
        /// 如果未提供访问令牌，会自动调用 GetAccessTokenAsync() 获取
        /// 
        /// 注意：大型列表可能需要分页处理，当前实现返回默认页面大小的结果
        /// </remarks>
        public static async Task<string> GetListItemsAsync(string listId, string? accessToken = null, string? siteId = null)
        {
            // 验证必需参数
            if (string.IsNullOrEmpty(listId))
            {
                throw new ArgumentException("List ID cannot be null or empty.", nameof(listId));
            }

            // 获取访问令牌和站点ID（如果未提供）
            accessToken ??= await GetAccessTokenAsync();
            siteId ??= _config.SiteId;

            // 验证获取的参数
            if (string.IsNullOrEmpty(accessToken))
            {
                throw new GraphConnectorException("Access token is null or empty. Please check your credentials.");
            }

            if (string.IsNullOrEmpty(siteId))
            {
                throw new ArgumentException("Site ID must be provided.", nameof(siteId));
            }

            try
            {
                // 构建获取列表项目的请求，使用 expand=fields 获取完整字段信息
                var request = new RestRequest($"/v1.0/sites/{siteId}/lists/{listId}/items?expand=fields", Method.Get);
                request.AddHeader("Authorization", $"Bearer {accessToken}");
                request.AddHeader("Accept", "application/json");

                // 发送请求
                var response = await _graphClient.Value.ExecuteAsync(request);

                // 检查响应状态
                if (!response.IsSuccessful)
                {
                    throw new GraphConnectorException(
                        $"Failed to get list items for list ID: {listId}",
                        response.StatusCode,
                        response.Content);
                }

                return response.Content ?? string.Empty;
            }
            catch (Exception ex) when (!(ex is GraphConnectorException))
            {
                // 包装非 GraphConnectorException 异常，包含列表ID信息便于调试
                throw new GraphConnectorException($"An error occurred while getting list items for list ID: {listId}", ex);
            }
        }

        /// <summary>
        /// 清除所有缓存的访问令牌
        /// </summary>
        /// <remarks>
        /// 此方法会清空内存中的所有缓存令牌
        /// 适用于以下场景：
        /// - 应用程序配置更改（如更换客户端密钥）
        /// - 测试环境中需要强制重新认证
        /// - 怀疑令牌被泄露时的安全措施
        /// - 切换到不同的 Azure AD 租户
        /// 
        /// 清除缓存后，下次调用 GetAccessTokenAsync() 时将重新获取令牌
        /// </remarks>
        public static void ClearTokenCache()
        {
            _tokenCache.Clear();
        }

        /// <summary>
        /// 释放 HTTP 客户端资源
        /// </summary>
        /// <remarks>
        /// 此方法用于清理内部使用的 HTTP 客户端资源
        /// 通常在以下情况下调用：
        /// - 应用程序关闭时
        /// - 长时间不使用 GraphConnector 时
        /// - 内存清理需求
        /// 
        /// 注意：调用此方法后，如果再次使用 GraphConnector 的方法，
        /// 会自动重新创建 HTTP 客户端实例
        /// 
        /// 由于使用了 Lazy 初始化，只有已创建的客户端才会被释放
        /// </remarks>
        public static void Dispose()
        {
            // 只释放已经创建的客户端实例
            if (_authClient.IsValueCreated)
                _authClient.Value?.Dispose();
            if (_graphClient.IsValueCreated)
                _graphClient.Value?.Dispose();
        }

        #endregion
    }
}
