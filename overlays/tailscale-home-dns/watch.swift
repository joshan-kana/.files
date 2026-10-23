import Darwin
import Foundation
import SystemConfiguration

// Keep the VPN connected; select LAN DNS only when a cryptographically
// authenticated Tailscale peer is directly reachable without a gateway.

func output(_ command: String, _ arguments: [String]) -> String? {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: command)
    process.arguments = arguments
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    do {
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return String(data: data, encoding: .utf8)
    } catch {
        return nil
    }
}

// Launch the vendor CLI through a shell. Direct execution from launchd can
// trigger Tailscale's GUI path rather than its command-line interface.
func tailscale(_ arguments: [String]) -> String? {
    output("/bin/sh", [
        "-c",
        "exec /Applications/Tailscale.app/Contents/MacOS/Tailscale \"$@\"",
        "tailscale",
    ] + arguments)
}

func directlyConnected(_ peer: String) -> Bool {
    guard let reply = tailscale(["ping", "--c=3", "--timeout=2s", peer]) else {
        return false
    }
    for line in reply.split(separator: "\n") where line.contains(" via ") {
        let fields = line.split(separator: " ")
        guard let index = fields.firstIndex(of: "via"), index + 1 < fields.count else { continue }
        let address = String(fields[index + 1].split(separator: ":")[0])
        guard address.contains("."), let route = output("/sbin/route", ["-n", "get", address]) else {
            continue
        }
        let physicalInterface = route.split(separator: "\n").contains { line in
            line.trimmingCharacters(in: .whitespaces).hasPrefix("interface: en")
        }
        if physicalInterface && !route.contains("gateway:") { return true }
    }
    return false
}

func reconcile(_ peer: String) {
    guard let preferences = tailscale(["debug", "prefs"]),
          let json = preferences.data(using: .utf8),
          let state = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
          let acceptingDNS = state["CorpDNS"] as? Bool else { return }
    let atHome = directlyConnected(peer)
    guard acceptingDNS == atHome else { return }
    if tailscale(["set", "--accept-dns=\(atHome ? "false" : "true")"]) != nil {
        fputs("Tailscale DNS: \(atHome ? "LAN" : "tailnet")\n", stderr)
    }
}

let peer = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "nixos-server"
var networkRevision = 0
func networkChanged() {
    networkRevision += 1
    let revision = networkRevision
    reconcile(peer)
    // A newly connected peer can initially use DERP before negotiating its LAN path.
    // Retry only this change, not indefinitely while offline.
    for seconds in [4.0, 15.0] {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            if networkRevision == revision { reconcile(peer) }
        }
    }
}

if CommandLine.arguments.contains("--once") {
    reconcile(peer)
} else {
    // Restore normal Tailscale DNS if the launch agent is disabled or removed.
    signal(SIGTERM, SIG_IGN)
    let termination = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .global(qos: .utility))
    termination.setEventHandler {
        _ = tailscale(["set", "--accept-dns=true"])
        exit(0)
    }
    termination.resume()

    let callback: SCDynamicStoreCallBack = { _, _, _ in networkChanged() }
    guard let store = SCDynamicStoreCreate(nil, "Tailscale LAN DNS" as CFString, callback, nil) else {
        exit(1)
    }
    let patterns = [
        "State:/Network/Global/IPv4",
        "State:/Network/Service/.*/IPv4",
        "State:/Network/Interface/.*/IPv4",
    ] as CFArray
    guard SCDynamicStoreSetNotificationKeys(store, nil, patterns),
          let source = SCDynamicStoreCreateRunLoopSource(nil, store, 0) else { exit(1) }
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .defaultMode)
    networkChanged()
    CFRunLoopRun()
}
