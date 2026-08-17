using SpeAuthorizationDemo.Graph;

namespace SpeAuthorizationDemo.Tests.Graph;

public sealed class FileNamePolicyTests
{
    [Theory]
    [InlineData("report.docx", true)]
    [InlineData("../secret.txt", false)]
    [InlineData("folder/file.txt", false)]
    [InlineData("folder\\file.txt", false)]
    [InlineData("bad\0name.txt", false)]
    [InlineData("", false)]
    public void IsAllowed_RejectsUnsafeNames(string name, bool expected)
    {
        Assert.Equal(expected, FileNamePolicy.IsAllowed(name));
    }

    [Theory]
    [InlineData(4_000_000, true)]
    [InlineData(4_000_001, false)]
    [InlineData(0, false)]
    public void IsAllowedLength_EnforcesConfiguredLimit(long length, bool expected)
    {
        Assert.Equal(expected, FileNamePolicy.IsAllowedLength(length, 4_000_000));
    }
}
