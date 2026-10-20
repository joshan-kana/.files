using System.Net;
using System.Net.Sockets;
using System.Text.Json;
using DnsServerCore.ApplicationCommon;
using TechnitiumLibrary.Net;
using TechnitiumLibrary.Net.Dns;
using TechnitiumLibrary.Net.Dns.ResourceRecords;

namespace RoamingDns;

// DHCP A records take precedence over APP records; transform only selected final answers.
public sealed class App : IDnsApplication, IDnsPostProcessor, IDnsApplicationPreference
{
    private sealed record Snapshot(bool LanHealthy, IPAddress[] V4, IPAddress[] V6)
    {
        public static readonly Snapshot Empty = new(false, [], []);
    }

    private sealed class Device(string name, string fallbackHost, int port)
    {
        public string Name { get; } = name;
        public string FallbackHost { get; } = fallbackHost;
        public int Port { get; } = port;
        public volatile Snapshot Status = Snapshot.Empty;
    }

    private CancellationTokenSource? _stopping;
    private Task? _worker;
    private IDnsServer? _dns;
    private Dictionary<string, Device> _devices = new(StringComparer.OrdinalIgnoreCase);
    private NetworkAddress? _lanSubnet;
    private IPAddress? _remoteDnsSource;
    private TimeSpan _interval;
    private TimeSpan _timeout;
    private uint _ttl;

    public string Description =>
        "LAN-first DNS for DHCP-managed roaming hosts with alternate-network fallback.";
    public byte Preference => 60; // After DNS64 (30) and Split Horizon (40).

    public Task InitializeAsync(IDnsServer dnsServer, string? config)
    {
        _dns = dnsServer;
        using var parsed = JsonDocument.Parse(
            config ?? throw new FormatException("Missing roaming DNS configuration")
        );
        var root = parsed.RootElement;
        if (!NetworkAddress.TryParse(root.GetProperty("lanSubnet").GetString(), out var subnet))
            throw new FormatException("Invalid LAN subnet");
        _lanSubnet = subnet;
        _remoteDnsSource = IPAddress.Parse(root.GetProperty("remoteDnsSource").GetString()!);
        _interval = TimeSpan.FromSeconds(
            Math.Clamp(root.GetProperty("pollSeconds").GetInt32(), 5, 300)
        );
        _timeout = TimeSpan.FromMilliseconds(
            Math.Clamp(root.GetProperty("timeoutMs").GetInt32(), 100, 5000)
        );
        _ttl = (uint)Math.Clamp(root.GetProperty("answerTtl").GetInt32(), 5, 60);
        foreach (var entry in root.GetProperty("devices").EnumerateArray())
        {
            var name = entry.GetProperty("name").GetString()!.TrimEnd('.');
            var target = entry.GetProperty("fallbackHost").GetString()!.TrimEnd('.');
            var port = entry.GetProperty("port").GetInt32();
            if (
                !name.EndsWith(".home", StringComparison.OrdinalIgnoreCase)
                || !target.Contains('.', StringComparison.Ordinal)
                || name.Equals(target, StringComparison.OrdinalIgnoreCase)
                || port is < 1 or > 65535
            )
                throw new FormatException("Invalid roaming device");
            if (!_devices.TryAdd(name, new Device(name, target, port)))
                throw new FormatException("Duplicate roaming hostname: " + name);
        }
        _stopping?.Cancel();
        _stopping = new CancellationTokenSource();
        _worker = Task.Run(() => PollAsync(_stopping.Token));
        return Task.CompletedTask;
    }

    private async Task PollAsync(CancellationToken stopping)
    {
        try
        {
            while (!stopping.IsCancellationRequested)
            {
                await Task.WhenAll(_devices.Values.Select(d => UpdateAsync(d, stopping)));
                await Task.Delay(_interval, stopping);
            }
        }
        catch (OperationCanceledException) when (stopping.IsCancellationRequested) { }
    }

    private async Task<IPAddress[]> ResolveAsync(
        string name,
        DnsResourceRecordType type,
        CancellationToken stopping
    )
    {
        try
        {
            var response = await _dns!.DirectQueryAsync(
                new DnsQuestionRecord(name, type, DnsClass.IN),
                timeout: (int)_timeout.TotalMilliseconds,
                cancellationToken: stopping
            );
            return response
                .Answer.Where(rr =>
                    rr.Type == type && rr.Name.Equals(name, StringComparison.OrdinalIgnoreCase)
                )
                .Select(rr =>
                    type == DnsResourceRecordType.A
                        ? ((DnsARecordData)rr.RDATA).Address
                        : ((DnsAAAARecordData)rr.RDATA).Address
                )
                .ToArray();
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            _dns!.WriteLog(ex);
            return [];
        }
    }

    private async Task UpdateAsync(Device device, CancellationToken stopping)
    {
        var v4 = ResolveAsync(device.FallbackHost, DnsResourceRecordType.A, stopping);
        var v6 = ResolveAsync(device.FallbackHost, DnsResourceRecordType.AAAA, stopping);
        var lan = await ResolveAsync(device.Name, DnsResourceRecordType.A, stopping);
        var healthy = false;
        foreach (var address in lan)
        {
            if (!_lanSubnet!.Contains(address))
                continue;
            using var client = new TcpClient(AddressFamily.InterNetwork);
            try
            {
                using var probe = CancellationTokenSource.CreateLinkedTokenSource(stopping);
                probe.CancelAfter(_timeout);
                await client.ConnectAsync(address, device.Port, probe.Token);
                healthy = true;
                break;
            }
            catch (Exception ex) when (ex is SocketException or OperationCanceledException)
            {
                if (stopping.IsCancellationRequested)
                    return;
            }
        }
        device.Status = new Snapshot(healthy, await v4, await v6);
    }

    public Task<DnsDatagram?> PostProcessAsync(
        DnsDatagram request,
        IPEndPoint remoteEP,
        DnsTransportProtocol protocol,
        DnsDatagram response
    )
    {
        if (
            request.Question.Count != 1
            || response.RCODE is not (DnsResponseCode.NoError or DnsResponseCode.NxDomain)
        )
            return Task.FromResult<DnsDatagram?>(response);
        var question = request.Question[0];
        if (
            !_devices.TryGetValue(question.Name, out var device)
            || question.Type is not (DnsResourceRecordType.A or DnsResourceRecordType.AAAA)
        )
            return Task.FromResult<DnsDatagram?>(response);

        var status = device.Status;
        // 4via6 queries arrive from the local subnet router address. Returning
        // a private IPv4 A answer there would break on overlapping remote LANs.
        var remoteV4 =
            question.Type == DnsResourceRecordType.A && remoteEP.Address.Equals(_remoteDnsSource);
        if (status.LanHealthy && !remoteV4 && response.RCODE == DnsResponseCode.NoError)
            return Task.FromResult<DnsDatagram?>(WithShortTtl(response));

        var addresses = question.Type == DnsResourceRecordType.A ? status.V4 : status.V6;
        if (addresses.Length == 0)
        {
            // The alternate DNS target may only publish A. Return NODATA for AAAA so clients
            // can connect using the non-overlapping alternate address.
            if (question.Type == DnsResourceRecordType.AAAA && status.V4.Length > 0)
                return Task.FromResult<DnsDatagram?>(
                    Rewrite(response, [], DnsResponseCode.NoError)
                );
            // During the first poll, do not let a DHCP A record cache for 300s.
            if (
                ReferenceEquals(status, Snapshot.Empty)
                && response.RCODE == DnsResponseCode.NoError
            )
                return Task.FromResult<DnsDatagram?>(WithShortTtl(response));
            return Task.FromResult<DnsDatagram?>(
                Rewrite(response, [], DnsResponseCode.ServerFailure)
            );
        }

        var answers = addresses
            .Select(ip => new DnsResourceRecord(
                question.Name,
                question.Type,
                DnsClass.IN,
                _ttl,
                question.Type == DnsResourceRecordType.A
                    ? new DnsARecordData(ip)
                    : new DnsAAAARecordData(ip)
            ))
            .ToArray();
        return Task.FromResult<DnsDatagram?>(Rewrite(response, answers, DnsResponseCode.NoError));
    }

    private DnsDatagram WithShortTtl(DnsDatagram response)
    {
        var answers = response
            .Answer.Select(rr => new DnsResourceRecord(
                rr.Name,
                rr.Type,
                rr.Class,
                Math.Min(rr.TTL, _ttl),
                rr.RDATA
            ))
            .ToArray();
        return Rewrite(response, answers);
    }

    private static DnsDatagram Rewrite(
        DnsDatagram response,
        IReadOnlyList<DnsResourceRecord> answers,
        DnsResponseCode? rcode = null
    ) =>
        new(
            response.Identifier,
            true,
            response.OPCODE,
            response.AuthoritativeAnswer,
            response.Truncation,
            response.RecursionDesired,
            response.RecursionAvailable,
            response.AuthenticData,
            response.CheckingDisabled,
            rcode ?? response.RCODE,
            response.Question,
            answers,
            [],
            []
        )
        {
            Tag = response.Tag,
        };

    public void Dispose()
    {
        _stopping?.Cancel();
    }
}
