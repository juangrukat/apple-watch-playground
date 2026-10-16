import SwiftUI
import WatchKit
import AVFoundation

@MainActor final class WatchSession:ObservableObject {
    let store=SampleStore()
    private lazy var capture=CaptureEngine(store:store)
    private lazy var sensors=SensorServices(store:store)
    private var bluetooth:BluetoothTransport?
    private var http:HTTPTransport?
    private var uiTimer:Timer?
    private var serviceTimer:Timer?
    private var ledger=CommandLedger()
    private var epoch=UUID()
    private var active=true,dimmed=false
    private var uiTick=ProcessInfo.processInfo.systemUptime
    private var sampler=ResourceSampler()
    private var player:AVAudioPlayer?
    private var soundTask:Task<Void,Never>?
    private var outputCount=0
    @Published private(set) var running=false
    @Published private(set) var snapshot=CaptureSnapshot()
    @Published private(set) var link=LinkSnapshot()
    @Published private(set) var cpu=0.0
    @Published private(set) var memory=0.0
    @Published private(set) var uiLag=0.0
    @Published private(set) var thermal="Nominal"
    @Published private(set) var microphoneOn=false
    @Published private(set) var locationOn=false
    @Published private(set) var rate=50.0
    @Published var page=0
    @Published var crown=0.0
    @Published private(set) var taps=0
    @Published var outputColor:Color?
    @Published private(set) var outputMessage="No output tested"
    @Published private(set) var runtimeLabel="Active"
    @Published var notice="Start a session to explore"
    init() {
        let args=ProcessInfo.processInfo.arguments
        if args.contains("--bluetooth") || args.contains("--audit-all") || args.contains("--local") {
            Task { [weak self] in
                guard let self else { return };self.start()
                if args.contains("--bluetooth") { self.connectBluetooth() }
                if args.contains("--audit-all") { self.allFeeds() }
            }
        }
    }
    func start() {
        guard !running else { return }
        epoch=UUID();running=true;store.start();store.runtime(active:active,dimmed:dimmed)
        store.put("crown",[crown]);store.put("touch",[Double(taps)])
        capture.start(rate:rate);sensors.start();notice="Capturing locally"
        serviceTimer=Timer.scheduledTimer(withTimeInterval:0.1,repeats:true) { [weak self] _ in Task { @MainActor in self?.sensors.tick() } }
        startUITimer();refresh()
    }
    func stop() {
        epoch=UUID();soundTask?.cancel();soundTask=nil;player?.stop();player=nil
        bluetooth?.stop();bluetooth=nil;http?.stop();http=nil
        capture.stop();sensors.stop();store.stop();running=false
        serviceTimer?.invalidate();serviceTimer=nil;uiTimer?.invalidate();uiTimer=nil
        outputColor=nil;link=LinkSnapshot();notice="Session stopped";refresh()
    }
    private func changeTransport() {
        bluetooth?.stop();bluetooth=nil;http?.stop();http=nil;link=LinkSnapshot();epoch=UUID()
    }
    func connectBluetooth() {
        start();changeTransport()
        let code=UserDefaults.standard.string(forKey:"pairCode") ?? ""
        guard code.count==6,code.allSatisfy(\.isNumber) else { notice="Enter the Mac’s six-digit code in Setup";return }
        let token=epoch,device=WKInterfaceDevice.current()
        bluetooth=BluetoothTransport(store:store,code:code,crownLeft:device.crownOrientation == .left,wristRight:device.wristLocation == .right,onCommand:{ [weak self] command,id in
            Task { @MainActor in guard let self,self.epoch==token,self.running else { return };self.execute(command,id:id) }
        },onRate:{ [weak self] rate in Task { @MainActor in guard let self,self.epoch==token else { return };self.rate=rate;self.capture.setRate(rate) } })
        notice="Bluetooth session started"
    }
    func connectHTTP() {
        start();changeTransport()
        let host=(UserDefaults.standard.string(forKey:"macHost") ?? "").trimmingCharacters(in:.whitespacesAndNewlines)
        let code=UserDefaults.standard.string(forKey:"pairCode") ?? ""
        guard !host.isEmpty,!host.contains("/"),!host.contains("@"),code.count==6,code.allSatisfy(\.isNumber),let url=URL(string:"http://\(host):8765/feed"),url.host != nil else { notice="Enter a Mac IP address and six-digit code";return }
        let token=epoch
        http=HTTPTransport(store:store,url:url,code:code,onCommand:{ [weak self] command,id in Task { @MainActor in guard let self,self.epoch==token,self.running else { return };self.execute(command,id:id) } })
        notice="Local HTTP session started"
    }
    func disconnect() { changeTransport();notice="Capturing locally · Mac disconnected" }
    func runtime(active:Bool,dimmed:Bool) {
        self.active=active;self.dimmed=dimmed;runtimeLabel=active ? (dimmed ? "Dimmed":"Active"):"Background / inactive"
        store.runtime(active:active,dimmed:dimmed)
        if running { startUITimer();if active { bluetooth?.resume();sensors.tick();refresh() } }
    }
    private func startUITimer() {
        uiTimer?.invalidate();uiTick=ProcessInfo.processInfo.systemUptime
        uiTimer=Timer.scheduledTimer(withTimeInterval:active && !dimmed ? 0.1:1,repeats:true) { [weak self] _ in Task { @MainActor in self?.refresh() } }
    }
    private var resourceTick=0.0
    func refresh() {
        let now=ProcessInfo.processInfo.systemUptime,expected=active && !dimmed ? 0.1:1
        uiLag=max(0,now-uiTick-expected)*1000;uiTick=now
        snapshot=store.read(now:now);link=bluetooth?.monitor.read() ?? http?.monitor.read() ?? LinkSnapshot()
        microphoneOn=sensors.microphoneOn;locationOn=sensors.locationOn
        if now-resourceTick>=1 {
            resourceTick=now;let r=sampler.sample(now:now);cpu=r.cpuPercent ?? 0;memory=r.residentMB ?? 0
            thermal=["Nominal","Fair","Serious","Critical"][min(3,max(0,r.thermal))]
        }
    }
    func touch() { guard running else { return };taps += 1;store.put("touch",[Double(taps)]);snapshot=store.read() }
    func turn(_ value:Double) { guard running,value.isFinite else { return };crown=value;store.put("crown",[value]) }
    func resetCrown() { turn(0) }
    func microphone(_ enabled:Bool) { start();sensors.setMicrophone(enabled);refresh() }
    func location(_ enabled:Bool) { start();sensors.setLocation(enabled);refresh() }
    func savedHealth() { start();sensors.readHealth() }
    func allFeeds() { start();sensors.setMicrophone(true);sensors.setLocation(true);sensors.readHealth();notice="All implemented feeds requested" }
    func execute(_ command:UInt8,id:UInt32?=nil) {
        guard (1...5).contains(command) else { bluetooth?.acknowledge(command,id:id,accepted:false);return }
        if let id,!ledger.accept(id) { bluetooth?.acknowledge(command,id:id,accepted:true);return }
        switch command {
        case 1:WKInterfaceDevice.current().play(.notification);outputMessage="Notification haptic invoked"
        case 2:outputColor = .mint;outputMessage="Mint display test"
        case 3:outputColor = .purple;outputMessage="Violet display test"
        case 4:outputColor=nil;outputMessage="Display reset"
        case 5:allFeeds()
        default:break
        }
        outputCount += 1;store.put("lastOutput",[Double(command),Double(outputCount)])
        bluetooth?.acknowledge(command,id:id,accepted:true)
    }
    func sound() {
        guard soundTask==nil else { return }
        let restore=sensors.pauseForSound()
        do {
            let session=AVAudioSession.sharedInstance();try session.setCategory(.playback,mode:.default);try session.setActive(true)
            let player=try AVAudioPlayer(data:TestTone.wave());player.volume=1;player.prepareToPlay()
            self.player=player;outputMessage=player.play() ? "Watch tone playback started":"Watch tone could not start"
        } catch { outputMessage="Sound error: \(error.localizedDescription)" }
        soundTask=Task { [weak self] in
            try? await Task.sleep(for:.seconds(1.2));guard let self,!Task.isCancelled else { return }
            self.player?.stop();self.player=nil;try? AVAudioSession.sharedInstance().setActive(false)
            self.sensors.restoreAfterSound(restore);self.soundTask=nil
        }
    }
}
enum TestTone {
    static func wave()->Data {
        let rate=22050,count=rate
        func le<T:FixedWidthInteger>(_ value:T)->Data { var value=value.littleEndian;return withUnsafeBytes(of:&value){Data($0)} }
        var pcm=Data()
        for index in 0..<count {
            let t=Double(index)/Double(rate),edge=min(1,min(t/0.02,(1-t)/0.05))
            pcm.append(le(Int16(sin(t*2*Double.pi*660)*max(0,edge)*0.45*32767)))
        }
        var wav=Data("RIFF".utf8);wav.append(le(UInt32(36+pcm.count)));wav.append(Data("WAVEfmt ".utf8));wav.append(le(UInt32(16)));wav.append(le(UInt16(1)));wav.append(le(UInt16(1)));wav.append(le(UInt32(rate)));wav.append(le(UInt32(rate*2)));wav.append(le(UInt16(2)));wav.append(le(UInt16(16)));wav.append(Data("data".utf8));wav.append(le(UInt32(pcm.count)));wav.append(pcm);return wav
    }
}
