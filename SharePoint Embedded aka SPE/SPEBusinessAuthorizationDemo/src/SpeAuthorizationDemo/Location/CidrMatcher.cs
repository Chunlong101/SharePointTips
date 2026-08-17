using System.Net;
using System.Net.Sockets;

namespace SpeAuthorizationDemo.Location;

public static class CidrMatcher
{
    public static bool IsMatch(IPAddress address, string cidr)
    {
        var parts = cidr.Split('/', 2);
        if (parts.Length != 2 || !IPAddress.TryParse(parts[0], out var network) ||
            !int.TryParse(parts[1], out var prefixLength)) return false;
        if (address.AddressFamily != network.AddressFamily) return false;

        var addressBytes = address.GetAddressBytes();
        var networkBytes = network.GetAddressBytes();
        var maxBits = address.AddressFamily == AddressFamily.InterNetwork ? 32 : 128;
        if (prefixLength < 0 || prefixLength > maxBits) return false;

        var fullBytes = prefixLength / 8;
        var remainingBits = prefixLength % 8;
        for (var index = 0; index < fullBytes; index++)
            if (addressBytes[index] != networkBytes[index]) return false;
        if (remainingBits == 0) return true;

        var mask = (byte)(0xff << (8 - remainingBits));
        return (addressBytes[fullBytes] & mask) == (networkBytes[fullBytes] & mask);
    }
}
