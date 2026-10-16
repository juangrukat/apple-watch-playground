import SwiftUI
import Network
import Darwin
@main struct PhoneProbe:App {
    var body:some Scene { WindowGroup { ProbeView() } }
}
struct ProbeView:View {
    @StateObject var probe=Probe()
    var body:some View {
        ScrollView { VStack(alignment:.leading,spacing:20) {
            Image(systemName:"network").font(.system(size:54)).foregroundStyle(.mint)
            Text("Playground connection check").font(.title2)
            Text(probe.status).font(.system(.body,design:.monospaced)).textSelection(.enabled)
            TextField("Mac IP address or hostname",text:$probe.host).textFieldStyle(.roundedBorder).textInputAutocapitalization(.never).autocorrectionDisabled().disabled(probe.running)
            Button("Test connection") { probe.run() }.disabled(probe.running || probe.host.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
            Text("Only tests your Mac's two local diagnostic ports. No sensor or health data is collected.").font(.caption).foregroundStyle(.secondary)
        }.padding(28) }
    }
}
@MainActor final class Probe:ObservableObject {
    @Published var status="Ready"
    @Published var running=false
    private var connections:[NWConnection]=[]
    @Published var host=""
    private var generation=UUID()
    private var listener:NWListener?
    private var peers:[NWConnection]=[]
    private func addresses()->String {
        var head:UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head)==0 else { return "unknown" }
        defer { freeifaddrs(head) }
        var cursor=head; var result:[String]=[]
        while let item=cursor {
            defer { cursor=item.pointee.ifa_next }
            guard let addr=item.pointee.ifa_addr,addr.pointee.sa_family==UInt8(AF_INET) else { continue }
            var name=[CChar](repeating:0,count:Int(NI_MAXHOST))
            if getnameinfo(addr,socklen_t(addr.pointee.sa_len),&name,socklen_t(name.count),nil,0,NI_NUMERICHOST)==0 {
                result.append("\(String(cString:item.pointee.ifa_name))=\(String(cString:name))")
            }
        }
        return result.joined(separator:"; ")
    }
    private func startListener() {
        guard listener==nil else { return }
        do {
            let server=try NWListener(using:.tcp,on:8767)
            listener=server
            server.stateUpdateHandler={ [weak self] state in
                Task { @MainActor in self?.append("Reverse listener: \(state)") }
            }
            server.newConnectionHandler={ [weak self] connection in
                Task { @MainActor in
                    guard let self else { return }
                    self.peers.append(connection)
                    connection.start(queue:.global())
                    connection.receive(minimumIncompleteLength:1,maximumLength:2048) { _,_,_,_ in
                        let body="Phone diagnostic OK"
                        let response="HTTP/1.1 200 OK\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
                        connection.send(content:Data(response.utf8),completion:.contentProcessed { _ in connection.cancel() })
                    }
                    self.append("Reverse connection received")
                }
            }
            server.start(queue:.global())
        } catch { append("Reverse listener error: \(error)") }
    }
    func append(_ message:String) {
        status += "\n\(message)"
        let url=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("probe-result.txt")
        try? status.write(to:url,atomically:true,encoding:.utf8)
    }
    func run() {
        guard !running,!host.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { return };host=host.trimmingCharacters(in:.whitespacesAndNewlines)
        for c in connections { c.cancel() }; connections=[]
        generation=UUID(); let token=generation
        running=true; status="Test \(ISO8601DateFormatter().string(from:Date())) — Mac \(host)"
        append("Phone IPv4: \(addresses())")
        startListener()
        for port:UInt16 in [8765,8766] {
            let c=NWConnection(host:NWEndpoint.Host(host),port:NWEndpoint.Port(rawValue:port)!,using:.tcp)
            connections.append(c)
            c.stateUpdateHandler={ [weak self,weak c] state in
                guard let c else { return }
                let path=c.currentPath
                let details="path=\(String(describing:path?.status)) reason=\(String(describing:path?.unsatisfiedReason))"
                Task { @MainActor in
                    guard let self,self.generation==token else { return }
                    switch state {
                    case .preparing:self.append("TCP \(port): preparing \(details)")
                    case .ready:self.append("TCP \(port): connected \(details)")
                    case .waiting(let e):self.append("TCP \(port): waiting \(e) \(details)")
                    case .failed(let e):self.append("TCP \(port): failed \(e) \(details)")
                    default:break
                    }
                }
            }
            c.start(queue:DispatchQueue.global())
        }
        Task {
            await withTaskGroup(of:String.self) { group in
                for port in [8765,8766] {
                    group.addTask { [host] in
                        let path=port==8765 ? "feed":"check"
                        var r=URLRequest(url:URL(string:"http://\(host):\(port)/\(path)")!)
                        r.timeoutInterval=8
                        if port==8765 { r.httpMethod="POST"; r.httpBody=Data("{\"pair\":\"diagnostic-invalid\"}".utf8); r.setValue("application/json",forHTTPHeaderField:"Content-Type") }
                        let config=URLSessionConfiguration.ephemeral; config.waitsForConnectivity=false; config.timeoutIntervalForResource=12
                        let session=URLSession(configuration:config); defer { session.invalidateAndCancel() }
                        do { let (_,response)=try await session.data(for:r); return "HTTP \(port): \((response as? HTTPURLResponse)?.statusCode ?? 0)" }
                        catch { return "HTTP \(port): \((error as NSError).domain) \((error as NSError).code) \(error.localizedDescription)" }
                    }
                }
                for await result in group { append(result) }
            }
            try? await Task.sleep(for:.seconds(2))
            for c in connections { c.cancel() }
            running=false
            append("Finished")
        }
    }
}
