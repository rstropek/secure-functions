using System.Net;

namespace HeroApi.Services;

public class DnsUtil
{
    public string ResolveDnsName(string dnsName)
        => string.Join(',', Dns.GetHostAddresses(dnsName).Select(a => a.ToString()));
}