using System.Net;
using System.Net.Sockets;
using System.Reflection;
using System.Text.Json;
using DnsServerCore.ApplicationCommon;
using RoamingDns;
using TechnitiumLibrary.Net.Dns;
using TechnitiumLibrary.Net.Dns.ResourceRecords;

namespace RoamingDns.Tests;

static class Test
{
    internal const string Name = "mac.home";
    internal const string Tail = "mac.tailtest.ts.net";

    internal static DnsDatagram Answer(string name, DnsResourceRecordType type, string address)
    {
        var ip = IPAddress.Parse(address);
        var data =
            type == DnsResourceRecordType.A
                ? (DnsResourceRecordData)new DnsARecordData(ip)
                : new DnsAAAARecordData(ip);
        var question = new DnsQuestionRecord(name, type, DnsClass.IN);
        var answer = new DnsResourceRecord(name, type, DnsClass.IN, 300, data);
        return new DnsDatagram(
            0,
            true,
            DnsOpcode.StandardQuery,
            true,
            false,
            true,
            true,
            false,
            false,
            DnsResponseCode.NoError,
            [question],
            [answer]
        );
    }

    internal static DnsDatagram Empty(
        string name,
        DnsResourceRecordType type,
        DnsResponseCode rcode
    ) =>
        new(
            0,
            true,
            DnsOpcode.StandardQuery,
            true,
            false,
            true,
            true,
            false,
            false,
            rcode,
            [new DnsQuestionRecord(name, type, DnsClass.IN)]
        );

    internal static void Check(bool condition, string test)
    {
        if (!condition)
            throw new InvalidOperationException("FAIL: " + test);
        Console.WriteLine("PASS: " + test);
    }

    internal static async Task<DnsDatagram> Process(
        App app,
        string name,
        DnsResourceRecordType type,
        string answer,
        string client = "127.0.0.1"
    )
    {
        var incoming = Answer(name, type, answer);
        var result = await app.PostProcessAsync(
            incoming,
            new IPEndPoint(IPAddress.Parse(client), 43210),
            DnsTransportProtocol.Udp,
            incoming
        );
        return result ?? throw new InvalidOperationException("Unexpected dropped DNS response");
    }

    internal static string Address(DnsDatagram response)
    {
        if (response.Answer.Count == 0)
            return "NONE";
        return response.Answer[0].RDATA switch
        {
            DnsARecordData a => a.Address.ToString(),
            DnsAAAARecordData aaaa => aaaa.Address.ToString(),
            _ => "OTHER",
        };
    }
}

public class FakeDns : DispatchProxy
{
    private volatile string _lanIp = "127.0.0.1";
    private volatile bool _hasLease = true;

    public string LanIp
    {
        get => _lanIp;
        set => _lanIp = value;
    }
    public bool HasLease
    {
        get => _hasLease;
        set => _hasLease = value;
    }

    protected override object? Invoke(MethodInfo? targetMethod, object?[]? args)
    {
        if (targetMethod?.Name == "WriteLog")
            return null;
        if (targetMethod?.Name != "DirectQueryAsync")
            throw new NotSupportedException(targetMethod?.Name);
        var question = (DnsQuestionRecord)args![0]!;
        if (
            question.Name.Equals(Test.Tail, StringComparison.OrdinalIgnoreCase)
            && question.Type == DnsResourceRecordType.AAAA
        )
            return Task.FromResult(
                Test.Empty(question.Name, question.Type, DnsResponseCode.NoError)
            );
        if (question.Name.Equals(Test.Name, StringComparison.OrdinalIgnoreCase) && !HasLease)
            return Task.FromResult(
                Test.Empty(question.Name, question.Type, DnsResponseCode.NxDomain)
            );
        var address = question.Name.ToLowerInvariant() switch
        {
            Test.Name when question.Type == DnsResourceRecordType.A => LanIp,
            Test.Tail when question.Type == DnsResourceRecordType.A => "100.88.1.2",
            Test.Tail when question.Type == DnsResourceRecordType.AAAA => "fd7a:115c:a1e0::123",
            _ => throw new InvalidOperationException("Unexpected fake DNS question"),
        };
        return Task.FromResult(Test.Answer(question.Name, question.Type, address));
    }
}

public static class Program
{
    public static async Task Main()
    {
        var listener = new TcpListener(IPAddress.Loopback, 0);
        listener.Start();
        var port = ((IPEndPoint)listener.LocalEndpoint).Port;
        var dns = DispatchProxy.Create<IDnsServer, FakeDns>();
        var fake = (FakeDns)dns;
        using var app = new App();
        var config = JsonSerializer.Serialize(
            new
            {
                lanSubnet = "127.0.0.0/8",
                remoteDnsSource = "192.168.1.3",
                pollSeconds = 5,
                timeoutMs = 150,
                answerTtl = 10,
                devices = new[]
                {
                    new
                    {
                        name = Test.Name,
                        tailscaleHost = Test.Tail,
                        port,
                    },
                },
            }
        );
        await app.InitializeAsync(dns, config);
        await Task.Delay(400);

        var local = await Test.Process(app, Test.Name, DnsResourceRecordType.A, fake.LanIp);
        Test.Check(
            Test.Address(local) == fake.LanIp && local.Answer[0].TTL == 10,
            "Healthy home client uses dynamic LAN A with short TTL"
        );

        var remoteA = await Test.Process(
            app,
            Test.Name,
            DnsResourceRecordType.A,
            fake.LanIp,
            "192.168.1.3"
        );
        Test.Check(
            Test.Address(remoteA) == "100.88.1.2",
            "Remote overlapping-subnet client does not receive LAN IPv4"
        );

        const string mapped = "fd7a:115c:a1e0:b1a:0:1:7f00:1";
        var remoteAAAA = await Test.Process(
            app,
            Test.Name,
            DnsResourceRecordType.AAAA,
            mapped,
            "192.168.1.3"
        );
        Test.Check(
            Test.Address(remoteAAAA) == IPAddress.Parse(mapped).ToString()
                && remoteAAAA.Answer[0].TTL == 10,
            "Healthy remote AAAA preserves existing 4via6 mapping"
        );

        var other = await Test.Process(app, "unrelated.home", DnsResourceRecordType.A, "127.0.0.4");
        Test.Check(
            Test.Address(other) == "127.0.0.4" && other.Answer[0].TTL == 300,
            "Unrelated DHCP DNS response is untouched"
        );

        listener.Stop();
        await Task.Delay(5500);
        var awayA = await Test.Process(app, Test.Name, DnsResourceRecordType.A, fake.LanIp);
        var awayAAAA = await Test.Process(app, Test.Name, DnsResourceRecordType.AAAA, mapped);
        Test.Check(Test.Address(awayA) == "100.88.1.2", "LAN disconnect switches to Tailscale A");
        Test.Check(
            awayAAAA.RCODE == DnsResponseCode.NoError && awayAAAA.Answer.Count == 0,
            "Missing Tailscale AAAA becomes NODATA, not a failing lookup"
        );

        fake.HasLease = false;
        var noLease = Test.Empty(Test.Name, DnsResourceRecordType.A, DnsResponseCode.NxDomain);
        var recovered = await app.PostProcessAsync(
            noLease,
            new IPEndPoint(IPAddress.Loopback, 32000),
            DnsTransportProtocol.Udp,
            noLease
        );
        Test.Check(
            recovered is not null
                && Test.Address(recovered) == "100.88.1.2"
                && recovered.RCODE == DnsResponseCode.NoError,
            "Expired DHCP lease still resolves to Tailscale instead of NXDOMAIN"
        );

        var resumed = new TcpListener(IPAddress.Parse("127.0.0.2"), port);
        resumed.Start();
        fake.LanIp = "127.0.0.2";
        fake.HasLease = true;
        await Task.Delay(5500);
        var rejoined = await Test.Process(app, Test.Name, DnsResourceRecordType.A, fake.LanIp);
        Test.Check(
            Test.Address(rejoined) == "127.0.0.2",
            "New DHCP IP restores direct LAN preference"
        );
        resumed.Stop();
    }
}
