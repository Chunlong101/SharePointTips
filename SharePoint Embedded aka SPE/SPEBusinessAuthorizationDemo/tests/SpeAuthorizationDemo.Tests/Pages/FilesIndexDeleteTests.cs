using System.Net;
using System.Security.Claims;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using SpeAuthorizationDemo.Authorization;
using SpeAuthorizationDemo.Graph;
using SpeAuthorizationDemo.Models;
using SpeAuthorizationDemo.Pages.Files;

namespace SpeAuthorizationDemo.Tests.Pages;

public sealed class FilesIndexDeleteTests
{
    [Fact]
    public async Task Delete_ReaderRole_IsRejectedWithoutGraphCall()
    {
        var graph = new FakeGraphClient();
        var model = CreateModel(
            new AuthorizationDecision(false, BusinessRole.Reader, BusinessOperation.DeleteFile, "operation_not_allowed"),
            graph);

        var result = await model.OnPostDeleteAsync("item-1", CancellationToken.None);

        var redirect = Assert.IsType<RedirectToPageResult>(result);
        Assert.Equal("/AccessDenied", redirect.PageName);
        Assert.Equal("operation_not_allowed", redirect.RouteValues!["reason"]);
        Assert.Equal(0, graph.DeleteCalls);
    }

    [Fact]
    public async Task Delete_WriterRole_DeletesAndReturnsSuccessMessage()
    {
        var graph = new FakeGraphClient();
        var model = CreateModel(
            new AuthorizationDecision(true, BusinessRole.Writer, BusinessOperation.DeleteFile, "allowed"),
            graph);
        model.TestLocation = "China";

        var result = await model.OnPostDeleteAsync("item-1", CancellationToken.None);

        var redirect = Assert.IsType<RedirectToPageResult>(result);
        Assert.Equal("/Files/Index", redirect.PageName);
        Assert.Equal("item-1", graph.DeletedItemId);
        Assert.Equal("文件已移入回收站。", model.StatusMessage);
        Assert.Equal("China", redirect.RouteValues!["testLocation"]);
    }

    [Fact]
    public async Task Delete_Folder_IsRejected()
    {
        var graph = new FakeGraphClient
        {
            Items = [new SpeDriveItem("folder-1", "Folder", 0, null, true)]
        };
        var model = CreateModel(
            new AuthorizationDecision(true, BusinessRole.Writer, BusinessOperation.DeleteFile, "allowed"),
            graph);

        var result = await model.OnPostDeleteAsync("folder-1", CancellationToken.None);

        var redirect = Assert.IsType<RedirectToPageResult>(result);
        Assert.Equal("folder_delete_not_allowed", redirect.RouteValues!["reason"]);
        Assert.Equal(0, graph.DeleteCalls);
    }

    [Fact]
    public async Task Delete_GraphForbidden_UsesSafeReasonCode()
    {
        var graph = new FakeGraphClient
        {
            GraphFailure = new SpeGraphException("upstream", HttpStatusCode.Forbidden)
        };
        var model = CreateModel(
            new AuthorizationDecision(true, BusinessRole.Writer, BusinessOperation.DeleteFile, "allowed"),
            graph);

        var result = await model.OnPostDeleteAsync("item-1", CancellationToken.None);

        var redirect = Assert.IsType<RedirectToPageResult>(result);
        Assert.Equal("container_permission_denied", redirect.RouteValues!["reason"]);
    }

    [Fact]
    public async Task Delete_ItemNotInCurrentRootList_IsRejectedBeforeDelete()
    {
        var graph = new FakeGraphClient();
        var model = CreateModel(
            new AuthorizationDecision(true, BusinessRole.Writer, BusinessOperation.DeleteFile, "allowed"),
            graph);

        var result = await model.OnPostDeleteAsync("arbitrary-item", CancellationToken.None);

        var redirect = Assert.IsType<RedirectToPageResult>(result);
        Assert.Equal("delete_target_not_allowed", redirect.RouteValues!["reason"]);
        Assert.Equal(0, graph.DeleteCalls);
    }

    private static IndexModel CreateModel(AuthorizationDecision decision, FakeGraphClient graph)
    {
        var context = new DefaultHttpContext
        {
            User = new ClaimsPrincipal(new ClaimsIdentity([new Claim("oid", Guid.NewGuid().ToString())], "test"))
        };
        return new IndexModel(new FakeAuthorizationService(decision), new FakeGraphClientFactory(graph))
        {
            PageContext = new PageContext { HttpContext = context }
        };
    }

    private sealed class FakeAuthorizationService(AuthorizationDecision decision) : IBusinessAuthorizationService
    {
        public Task<AuthorizationDecision> AuthorizeAsync(
            ClaimsPrincipal user,
            HttpContext httpContext,
            BusinessOperation operation,
            CancellationToken cancellationToken) => Task.FromResult(decision);
    }

    private sealed class FakeGraphClientFactory(FakeGraphClient graph) : ISpeGraphClientFactory
    {
        public ISpeGraphClient CreateDelegated() => graph;
        public ISpeGraphClient CreateAppOnly() => graph;
    }

    private sealed class FakeGraphClient : ISpeGraphClient
    {
        public IReadOnlyList<SpeDriveItem> Items { get; init; } =
            [new SpeDriveItem("item-1", "file.txt", 12, null)];
        public SpeGraphException? GraphFailure { get; init; }
        public int DeleteCalls { get; private set; }
        public string? DeletedItemId { get; private set; }

        public Task DeleteFileAsync(string itemId, CancellationToken cancellationToken)
        {
            DeleteCalls++;
            if (GraphFailure is not null) throw GraphFailure;
            DeletedItemId = itemId;
            return Task.CompletedTask;
        }

        public Task<IReadOnlyList<SpeDriveItem>> ListRootAsync(CancellationToken cancellationToken) =>
            Task.FromResult(Items);

        public Task<SpeDownload> DownloadAsync(string itemId, CancellationToken cancellationToken) =>
            throw new NotSupportedException();

        public Task<SpeDriveItem> UploadSmallFileAsync(string fileName, Stream content, long length, CancellationToken cancellationToken) =>
            throw new NotSupportedException();
    }
}
