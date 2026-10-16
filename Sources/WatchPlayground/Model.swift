import SwiftUI
import Network
import AVFoundation
import AppKit

struct Capability: Identifiable {
    let id: String, name: String, icon: String, family: String, unit: String, explanation: String, access: String
    let color: Color
    var stream: Bool { access == "Live" || access == "Derived" }
    var activationHint:String {
        switch id {
        case "crown","touch":return "Open Play on Watch"
        case "microphone":return "Enable Microphone level on Watch"
        case "location","heading":return "Enable Location / compass on Watch"
        case "heart","hrv","oxygen","temperature":return "Read saved health data on Watch"
        case "rhythm":return "Repeat deliberate downward gestures"
        case "steps":return "Walk with the Watch to update steps"
        default:return "Waiting for Watch"
        }
    }
}
let catalog: [Capability] = [
    .init(id:"performance",name:"Performance & Watch load",icon:"gauge.with.dots.needle.50percent",family:"Connections",unit:"",explanation:"Measured app load and separate capture, submission, arrival and UI cadences. App CPU is not whole-device utilization.",access:"Diagnostics",color:.orange),
    .init(id:"orientation", name:"Wrist orientation", icon:"rotate.3d", family:"Movement", unit:"rad", explanation:"Physical Watch pose with configured Crown and axes. Align view sets the viewing direction. Neutral pose zeros the numeric signal only. Yaw is relative.", access:"Live", color:.mint),
    .init(id:"acceleration", name:"Acceleration", icon:"waveform.path", family:"Movement", unit:"g", explanation:"Three axes of acceleration including gravity. Flick, sway or gently tap your wrist.", access:"Live", color:.cyan),
    .init(id:"rotation", name:"Rotation speed", icon:"arrow.trianglehead.2.clockwise.rotate.90", family:"Movement", unit:"rad/s", explanation:"Rotation around three axes from device motion. Useful for swirls, steering and expression.", access:"Live", color:.purple),
    .init(id:"gravity", name:"Gravity", icon:"arrow.down", family:"Movement", unit:"g", explanation:"The arrow shows gravity in Watch coordinates, in g. Tilt is measured from face-up. Gravity alone cannot determine yaw.", access:"Live", color:.teal),
    .init(id:"intensity", name:"Movement strength", icon:"sparkles", family:"Movement", unit:"g", explanation:"Derived magnitude of acceleration with gravity removed. Magnitude in g, not energy in joules.", access:"Derived", color:.orange),
    .init(id:"stillness", name:"Stillness", icon:"water.waves", family:"Movement", unit:"", explanation:"A windowed steadiness score derived on the Mac from received movement magnitudes. Adjust the window and movement tolerance; not a medical measure.", access:"Derived", color:.blue),
    .init(id:"rhythm", name:"Gesture rhythm", icon:"metronome", family:"Movement", unit:"BPM", explanation:"Tempo estimated from repeated acceleration peaks. Threshold and movement style affect detection.", access:"Derived", color:.pink),
    .init(id:"crown", name:"Digital Crown", icon:"digitalcrown.horizontal.arrow.clockwise", family:"Interaction", unit:"control", explanation:"Open Play on the Watch. Its dedicated focused surface reads Crown rotation; values are control units, not calibrated physical turns.", access:"Live", color:.yellow),
    .init(id:"touch", name:"Touch", icon:"hand.tap", family:"Interaction", unit:"tap", explanation:"Open Play on the Watch and tap the pink pad. Its visible count should match this feed. Touches elsewhere are not captured.", access:"Live", color:.pink),
    .init(id:"doubletap", name:"Double tap", icon:"hand.pinch", family:"Interaction", unit:"", explanation:"Apple's recognized gesture invokes the touch-pad primary action on supported Watches. It shares the Touch counter; the API does not identify whether activation came from a tap or the gesture.", access:"System action", color:.pink),
    .init(id:"action", name:"Action button", icon:"button.programmable", family:"Interaction", unit:"", explanation:"Ultra supports selected workout/dive App Intents and user-configured Shortcuts. Not a raw global button feed; not implemented in this companion.", access:"System action", color:.orange),
    .init(id:"microphone", name:"Microphone level", icon:"mic", family:"Sound", unit:"dBFS", explanation:"Live microphone level from an opt-in Watch recording session. No audio file is saved or transmitted, only the level.", access:"Live", color:.green),
    .init(id:"audio", name:"Sound output (Mac)", icon:"speaker.wave.2", family:"Sound", unit:"", explanation:"Test a synthesized tone on this Mac. The conductor palette produces a local metronome.", access:"Output", color:.green),
    .init(id:"haptic", name:"Haptic feedback", icon:"waveform", family:"Feedback", unit:"", explanation:"Send a predefined notification haptic to the connected Watch. Apple controls the tactile waveform.", access:"Output", color:.orange),
    .init(id:"display", name:"Watch display", icon:"applewatch", family:"Feedback", unit:"", explanation:"Send a color to the connected companion. WatchOS controls display sleep and app lifecycle.", access:"Output", color:.mint),
    .init(id:"altitude", name:"Relative altitude", icon:"mountain.2", family:"Environment", unit:"m", explanation:"Altitude change since the Watch sensor session started. Not absolute elevation.", access:"Live", color:.brown),
    .init(id:"pressure", name:"Air pressure", icon:"barometer", family:"Environment", unit:"kPa", explanation:"Barometric pressure where supported. Weather and elevation both influence the reading.", access:"Live", color:.teal),
    .init(id:"heading", name:"Compass", icon:"location.north.circle", family:"Environment", unit:"°", explanation:"Magnetic heading through Core Location on supported hardware. Permission required.", access:"Live", color:.yellow),
    .init(id:"location", name:"Location / speed", icon:"location", family:"Environment", unit:"m/s", explanation:"Opt-in location panel shows latitude, longitude and speed. Mac receives these only when you enable location on the Watch.", access:"Live", color:.blue),
    .init(id:"steps", name:"Steps / cadence", icon:"figure.walk", family:"Body", unit:"steps", explanation:"Pedometer totals from session start and cadence where available. Computed by the system.", access:"Live", color:.green),
    .init(id:"heart", name:"Heart rate", icon:"heart", family:"Body", unit:"BPM", explanation:"Latest authorized HealthKit sample with age shown. This companion does not start a workout or promise continuous heart rate.", access:"Historical", color:.red),
    .init(id:"hrv", name:"Heart rate variability", icon:"heart.text.clipboard", family:"Body", unit:"ms", explanation:"Latest saved HealthKit SDNN measurement. Not a live stress or emotion sensor.", access:"Historical", color:.red),
    .init(id:"oxygen", name:"Blood oxygen", icon:"lungs", family:"Body", unit:"%", explanation:"Latest authorized oxygen saturation record where supported and available in your region.", access:"Historical", color:.cyan),
    .init(id:"temperature", name:"Sleeping wrist temperature", icon:"thermometer.medium", family:"Body", unit:"°C", explanation:"Latest saved sleeping wrist temperature. No on-demand skin-temperature stream.", access:"Historical", color:.orange),
    .init(id:"sleep", name:"Sleep stages", icon:"moon.zzz", family:"Body", unit:"", explanation:"Saved HealthKit sleep categories, not a live feed. Explorer documentation only in this version.", access:"Reference", color:.indigo),
    .init(id:"ecg", name:"Saved ECG", icon:"waveform.path.ecg", family:"Body", unit:"", explanation:"Saved ECG voltage samples can be read through supported HealthKit APIs, typically via an iPhone companion. Not implemented here.", access:"Reference", color:.red),
    .init(id:"fitness", name:"Fitness / workouts", icon:"figure.run", family:"Body", unit:"", explanation:"HealthKit includes workout records, routes, energy and fitness metrics. These are separate permissions; not imported in this version.", access:"Reference", color:.green),
    .init(id:"water", name:"Depth / water temperature", icon:"water.waves.and.arrow.down", family:"Environment", unit:"", explanation:"Supported Watches offer submersion, depth, pressure and water temperature with the appropriate capability. Not enabled in this companion.", access:"Model / entitlement", color:.cyan),
    .init(id:"highrate", name:"High-frequency motion", icon:"bolt", family:"Movement", unit:"", explanation:"Supported Watches can deliver batched high-rate motion for workout uses. Not an instant 800 Hz controller feed; not enabled here.", access:"Workout requirement", color:.purple),
    .init(id:"bluetooth", name:"Bluetooth accessories", icon:"antenna.radiowaves.left.and.right", family:"Connections", unit:"", explanation:"Core Bluetooth can communicate with compatible peripherals. Each accessory needs a protocol integration; not a built-in sensor feed.", access:"Reference", color:.blue),
    .init(id:"uwb", name:"Nearby Interaction / UWB", icon:"dot.radiowaves.left.and.right", family:"Connections", unit:"", explanation:"Supported devices and accessories can expose ranging. Requires compatible hardware and a session implementation; not enabled here.", access:"Model / peer", color:.purple),
    .init(id:"battery", name:"Watch battery", icon:"battery.75percent", family:"Connections", unit:"%", explanation:"Battery level from the connected Watch, plus its charging state. Not the Mac's battery.", access:"Live", color:.green),
    .init(id:"network", name:"Watch connection", icon:"network", family:"Connections", unit:"", explanation:"Direct Bluetooth or local HTTP transport. A short code pairs your Watch and Mac; no cloud account or server.", access:"Status", color:.mint),
    .init(id:"ppg", name:"Raw optical pulse / PPG", icon:"heart.circle", family:"Restricted", unit:"", explanation:"SensorKit PPG requires an approved research study and entitlement. Not available to this ordinary app.", access:"Restricted", color:.gray),
    .init(id:"light", name:"Ambient light", icon:"sun.max", family:"Restricted", unit:"", explanation:"No ordinary public live light-sensor feed for this playground. Some research records may be available through SensorKit.", access:"Restricted", color:.gray),
    .init(id:"nfc", name:"NFC / Secure Element", icon:"wave.3.right", family:"Restricted", unit:"", explanation:"No general raw NFC reader, card-emulation, Apple Pay key or Secure Element access for this Watch app.", access:"Restricted", color:.gray),
    .init(id:"rawradio", name:"Raw radios / firmware", icon:"cpu", family:"Restricted", unit:"", explanation:"No public raw RF samples, chip registers, firmware access or unrestricted system-wide interception.", access:"Restricted", color:.gray)
]
struct Tile: Identifiable, Codable, Equatable {
    var id = UUID()
    var capability: String
    var x: Double, y: Double
    var gain = 1.0, smoothing = 0.25, deadzone = 0.0
    var inverted = false
    var output = "Visual"
    var axis = 0
    var bias = 0.0
    var wide = false
    var note = ""
    var settings:CardSettings?
    var presetID:String?
    var width:Double { wide ? 652:332 }
    var height:Double {
        if capability=="performance" { return 462 }
        if capability=="orientation",settings?.response != true { return 410 }
        if ["heart","hrv","oxygen","temperature"].contains(capability) { return 264 }
        if catalog.first(where:{$0.id==capability})?.stream != true { return ["audio","haptic","display","network"].contains(capability) ? 306:240 }
        return settings?.response==true ? 690:(["location","acceleration","rotation","pressure","altitude","steps"].contains(capability) ? 422:382)
    }
}
struct Workspace: Codable { var name: String; var tiles: [Tile] }
struct Sample { var values: [Double]; var date: Date; var sourceDate: Date?; var receivedAt=Date() }

@MainActor final class FeedClock: ObservableObject { var frame:UInt64=0 }

@MainActor final class Studio: ObservableObject {
    let feedClock=FeedClock()
    var watchDiagnostics:[String:Double]=[:]
    var watchDiagnosticsReceived=Date.distantPast
    var watchDiagnosticFieldDates:[String:Date]=[:]
    var acknowledgedOutputs:[String:Int]=[:]
    private var lastOutputEvent:[Double]?
    var macToneTestPassed=false
    @Published var outputMessages:[String:String]=[:]
    var diagnosticReceiptCount=0
    var signalObservations:[String:(count:Int,changes:Int,last:[Double])]=[:]
    private let signalAuditEnabled=ProcessInfo.processInfo.arguments.contains("--signal-audit")
    var receiveCadence=CadenceWindow()
    var redrawCadence=CadenceWindow()
    var referenceDownZ:Double?
    var referenceInverseDownZ:Double?
    var macWindowVisible:Bool { NSApp?.windows.contains(where:{$0.isVisible && $0.occlusionState.contains(.visible)}) ?? false }
    var sequenceGaps=0
    private var transportLags:[(Double,Double)]=[]
    var transportToMainLagMs:Double { let now=ProcessInfo.processInfo.systemUptime;return transportLags.filter{now-$0.0<2}.map{$0.1}.max() ?? 0 }
    func recordTransportLag(_ milliseconds:Double) {
        let now=ProcessInfo.processInfo.systemUptime;transportLags.append((now,milliseconds));transportLags.removeAll{now-$0.0>=2}
    }
    var ingressRate:Double?
    var ingressGap:Double?
    var transportSpacingError:Double?
    var macResources=RuntimeResources(cpuPercent:nil,residentMB:nil,thermal:0,lowPower:false)
    private let macResourceSampler=ResourceSampler()
    @Published var performanceEpoch=0
    @Published var neutralPose=PoseQuaternion.identity
    private var lastPerformanceSample=0.0
    var currentPose:PoseQuaternion {
        if let values=samples["quaternion"]?.values,let q=PoseQuaternion(values) { return q }
        let values=samples["orientation"]?.values ?? [0,0,0]
        return values.count>=3 ? .euler(values[0],values[1],values[2]):.identity
    }
    private var viewYaw:Double?
    var physicalDisplayPose:PoseQuaternion { .euler(0,0,-(viewYaw ?? currentPose.euler[2])) * currentPose }
    func alignPoseView() { viewYaw=currentPose.euler[2];feedClock.objectWillChange.send() }
    private(set) var displayHeading:Double?
    private var headingDisplayTime:Date?
    func setNeutralPose() { neutralPose=currentPose.inverse;clearPoseReferences() }
    func resetNeutralPose() { neutralPose = .identity;clearPoseReferences() }
    private func clearPoseReferences() {for i in tiles.indices where tiles[i].capability=="orientation" {tiles[i].settings?.reference=nil;smoothed[tiles[i].id]=nil};persist()}
    func resetCardResponse(_ id:UUID) {smoothed[id]=nil;previousResponseRaw[id]=nil;previousCrownSource[id]=nil}
    func updateWatchDiagnostics(_ values:[String:Double]) {
        diagnosticReceiptCount += 1
        let valid=values.filter{$0.value.isFinite}
        if let session=valid["session"],let old=watchDiagnostics["session"],session != old { viewYaw=nil;displayHeading=nil;headingDisplayTime=nil;watchDiagnostics=[:];watchDiagnosticFieldDates=[:];lastOutputEvent=nil;acknowledgedOutputs=[:] }
        watchDiagnostics.merge(valid){_,new in new};watchDiagnosticsReceived=Date()
        for key in valid.keys { watchDiagnosticFieldDates[key]=watchDiagnosticsReceived }
    }
    @Published var tiles: [Tile] = []
    var samples: [String: Sample] = [:]
    var histories: [String: [Double]] = [:]
    var cardHistories:[String:CardHistory]=[:]
    @Published var activeCardID:UUID?
    @Published var canvasJump:CanvasJump?
    var draggingCardID:UUID?
    var frozenAt:Date?
    @Published var archivedPresetNames:[String]=[]
    private var responseTick=ProcessInfo.processInfo.systemUptime
    private var eventCounters:[UUID:Double]=[:]
    private var pulseUntil:[UUID:Double]=[:]
    private var toggleState:[UUID:Bool]=[:]
    private var previousResponseRaw:[UUID:Double]=[:]
    private var previousCrownSource:[UUID:Date]=[:]
    var smoothed: [UUID: Double] = [:]
    @Published var statuses: [String: String] = [:]
    @Published var demo = true
    @Published var paused = false { didSet { frozenAt=paused ? Date():nil } }
    @Published var connected = false
    @Published var usbBridge = false
    @Published var bluetoothMode = false
    @Published var bluetoothRTT = ""
    @Published var bluetoothRate = 0.0
    @Published var controllerRate=50
    @Published var httpRate=0.0
    private var bluetoothLink:BluetoothLink?
    @Published var message = "Demo • simulated motion. Connect your Watch for real feeds."
    @Published var pairingCode = String(Int.random(in: 100000...999999))
    @Published var workspaceName = "Motion garden"
    @Published var savedNames: [String] = []
    @Published var recording = false
    @Published var beats = 0
    @Published var tempo = 90.0
    @Published var metronome = false
    @Published var snap = true
    @Published var streamAge = ""
    @Published var note = ""
    private var bridgeGeneration=UUID()
    private var bridgeTask: Task<Void,Never>?
    private var listener: NWListener?
    private var clients: [UUID: NWConnection] = [:]
    private var buffers: [UUID: Data] = [:]
    private var clientActivity:[UUID:Date]=[:]
    private var sessions: [String: Date] = [:]
    private var sessionSequences:[String:Int]=[:]
    private var httpInputWindow=ProcessInfo.processInfo.systemUptime
    private var httpAccepted=0
    private var httpRejected=0
    private var httpUnique=0
    private var lastHTTPSource:Double?
    private var commands: [String] = []
    private var timer: Timer?
    private var phase = 0.0
    private var lastOutput: [UUID: Date] = [:]
    private var outputHigh: [UUID: Bool] = [:]
    private var lastTick = Date.distantPast
    private var lastPeak = Date.distantPast
    private var lastPacket = Date.distantPast
    private var peakHigh = false
    private var recordRows: [String] = []
    private var tone: AVAudioPlayer?
    private var cardOutputPlayer:AVAudioPlayer?
    private var saveURL: URL {
        let d = ProcessInfo.processInfo.environment["WATCHPLAYGROUND_WORKSPACE_DIRECTORY"].map{URL(fileURLWithPath:$0)} ?? FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("WatchPlayground")
        try? FileManager.default.createDirectory(at:d,withIntermediateDirectories:true)
        return d.appendingPathComponent("workspaces.json")
    }
    init(startNetworking: Bool = true) {
        if let code=ProcessInfo.processInfo.environment["WATCHPLAYGROUND_PAIR_CODE"],code.count==6 { pairingCode=code }
        if let data = UserDefaults.standard.data(forKey:"lastWorkspace"), let w = try? JSONDecoder().decode(Workspace.self,from:data) { tiles = w.tiles; workspaceName = w.name }
        else { preset("Motion garden") }
        if !ProcessInfo.processInfo.arguments.contains("--self-test") {
            let old=UserDefaults.standard.data(forKey:"lastWorkspace")
            if tiles.contains(where:{$0.settings==nil}) {
                if let old { UserDefaults.standard.set(old,forKey:"beforeCardRedesign") }
                for i in tiles.indices { tiles[i].settings = .defaults(tiles[i].capability);if tiles[i].capability=="orientation" { tiles[i].axis=min(2,tiles[i].axis) } }
                note="Card settings upgraded; your previous workspace is backed up."
            }
        }
        refreshSaved()
        if ProcessInfo.processInfo.arguments.contains("--diagnostics-layout") {
            let snapshot="Before diagnostics \(Date().formatted(.dateTime.year().month().day().hour().minute().second()))"
            workspaceName=snapshot;save();preset("Diagnostics");note="Previous layout saved in the workspace menu as \(snapshot)."
        }
        if startNetworking { timer = Timer.scheduledTimer(withTimeInterval:1/30,repeats:true) { [weak self] _ in Task { @MainActor in self?.tick() } } }
        prepareTone()
        if !startNetworking { return }
        startServer()
        if ProcessInfo.processInfo.arguments.contains("--usb-bridge") { startUSBBridge() }
        if ProcessInfo.processInfo.arguments.contains("--bluetooth") { startBluetooth() }
    }
    func add(_ c: Capability) {
        var tile=Tile(capability:c.id,x:28,y:28);tile.settings = .defaults(c.id)
        var found=false
        for row in 0..<100 where !found {
            for column in 0..<3 {
                let x=Double(column)*356+28,y=Double(row)*448+28
                let occupied=tiles.contains { x<$0.x+$0.width+12 && x+tile.width+12>$0.x && y<$0.y+$0.height+12 && y+tile.height+12>$0.y }
                if !occupied {tile.x=x;tile.y=y;found=true;break}
            }
        }
        tiles.append(tile)
        persist();focusCard(tile.id)
    }
    func preset(_ name:String) {
        if !tiles.isEmpty,!ProcessInfo.processInfo.arguments.contains("--self-test") { saveSnapshot() }
        let kit=CardKit.builtins.first{$0.name==name} ?? CardKit.builtins[0]
        tiles=kit.capabilities.enumerated().map { index,id in
            var tile=Tile(capability:id,x:Double(index%3)*356+28,y:Double(index/3)*408+28)
            tile.settings = .defaults(id);return tile
        }
        workspaceName=name;smoothed=[:];organize();persist()
    }
    private func saveSnapshot() {
        guard !ProcessInfo.processInfo.arguments.contains("--self-test") else { return }
        var all=readSaved();let name="Before replacing · \(workspaceName) · \(Int(Date().timeIntervalSince1970))"
        all[name]=Workspace(name:name,tiles:tiles);try? JSONEncoder().encode(all).write(to:saveURL,options:.atomic);refreshSaved()
    }
    func addKit(_ kit:CardKit) {
        guard !tiles.contains(where:{$0.presetID==kit.id}) else { note="This preset group is already on the canvas.";return }
        addGroup(kit.capabilities.map { id in var tile=Tile(capability:id,x:0,y:0);tile.settings = .defaults(id);return tile },id:kit.id)
        note="Added \(kit.name). Remove group leaves your other cards intact."
    }
    func addSavedPreset(_ name:String) {
        guard let saved=readSaved()[name] else { return };let group="saved:"+name
        guard !tiles.contains(where:{$0.presetID==group}) else { return }
        addGroup(saved.tiles,id:group)
    }
    func focusCard(_ id:UUID) {if let tile=tiles.first(where:{$0.id==id}) {activeCardID=id;canvasJump=CanvasJump(point:CGPoint(x:tile.x,y:tile.y))}}
    private func addGroup(_ group:[Tile],id:String) {
        let top=(tiles.map{$0.y+$0.height}.max() ?? -12)+40
        var rowY=top,rowHeight=0.0
        for (index,var tile) in group.enumerated() {
            if index%3==0 && index>0 { rowY += rowHeight+24;rowHeight=0 }
            tile.id=UUID();tile.presetID=id;tile.wide=false;tile.settings=tile.settings ?? .defaults(tile.capability)
            tile.x=Double(index%3)*356+28;tile.y=rowY;rowHeight=max(rowHeight,tile.height);tiles.append(tile)
        };persist();if let first=tiles.first(where:{$0.presetID==id}) {focusCard(first.id)}
    }
    func removeGroup(_ id:String) { tiles.removeAll{$0.presetID==id};persist();note="Preset group removed. Other cards kept." }
    private var archiveURL:URL { saveURL.deletingLastPathComponent().appendingPathComponent("removed-presets.json") }
    private func readArchive()->[String:Workspace] { guard let data=try? Data(contentsOf:archiveURL) else { return [:] };return (try? JSONDecoder().decode([String:Workspace].self,from:data)) ?? [:] }
    func removeSavedPreset(_ name:String) {
        var all=readSaved(),archive=readArchive();guard let removed=all.removeValue(forKey:name) else { return };var key=name;var suffix=2;while archive[key] != nil {key="\(name) (\(suffix))";suffix += 1};archive[key]=removed
        do { try JSONEncoder().encode(archive).write(to:archiveURL,options:.atomic);try JSONEncoder().encode(all).write(to:saveURL,options:.atomic);refreshSaved();note="Preset moved to Removed presets; it can be restored." } catch { note=error.localizedDescription }
    }
    func restoreSavedPreset(_ name:String) {
        var archive=readArchive(),all=readSaved();guard var item=archive.removeValue(forKey:name) else { return }
        var restored=item.name;var suffix=2;while all[restored] != nil {restored="Restored \(item.name) (\(suffix))";suffix += 1};item.name=restored;all[restored]=item
        do { try JSONEncoder().encode(all).write(to:saveURL,options:.atomic);try JSONEncoder().encode(archive).write(to:archiveURL,options:.atomic);refreshSaved() } catch { note=error.localizedDescription }
    }
    func persist() { guard !ProcessInfo.processInfo.arguments.contains("--self-test") else { return }; if let d = try? JSONEncoder().encode(Workspace(name:workspaceName,tiles:tiles)) { UserDefaults.standard.set(d,forKey:"lastWorkspace") } }
    func refreshSaved() { savedNames = readSaved().keys.sorted();archivedPresetNames=readArchive().keys.sorted() }
    func readSaved() -> [String: Workspace] { guard let d = try? Data(contentsOf:saveURL), let result = try? JSONDecoder().decode([String: Workspace].self,from:d) else { return [:] }; return result }
    func save() {
        var all = readSaved(); all[workspaceName] = Workspace(name:workspaceName,tiles:tiles)
        do { try JSONEncoder().encode(all).write(to:saveURL,options:.atomic); refreshSaved(); persist(); note = "Workspace saved." } catch { note = error.localizedDescription }
    }
    func load(_ name: String) { if let w = readSaved()[name] { saveSnapshot();tiles = w.tiles.map { var tile=$0;tile.settings=tile.settings ?? .defaults(tile.capability);return tile }; workspaceName = w.name; smoothed = [:]; persist() } }
    func backupAndArrange() {saveSnapshot();organize();note="Previous layout saved in the workspace menu. Cards arranged to fit their new sizes."}
    func organize() {
        var y=28.0,rowHeight=0.0
        for i in tiles.indices {
            if i%3==0 && i>0 { y += rowHeight+24;rowHeight=0 }
            tiles[i].wide=false;tiles[i].x=Double(i%3)*356+28;tiles[i].y=y;rowHeight=max(rowHeight,tiles[i].height)
        };persist();if let first=tiles.first {focusCard(first.id)}
    }
    func move(_ id:UUID, x:Double, y:Double, bypassSnap:Bool=false) {
        guard let i = tiles.firstIndex(where:{$0.id==id}) else { return }
        var px = max(12,x), py = max(12,y)
        if snap && !bypassSnap {
            for t in tiles where t.id != id {
                let width = t.width
                for edge in [t.x, t.x+width+20, t.x-tiles[i].width-20] where abs(px-edge)<22 { px=edge }
                for edge in [t.y,t.y+t.height+24,t.y-tiles[i].height-24] where abs(py-edge)<22 { py=edge }
            }
            px = (max(12,px)/4).rounded()*4; py = (max(12,py)/4).rounded()*4
        }
        tiles[i].x=px; tiles[i].y=py; persist()
    }
    func setDemo(_ value:Bool) { demo=value; samples=[:]; histories=[:];cardHistories=[:];eventCounters=[:];pulseUntil=[:];toggleState=[:]; smoothed=[:]; peakHigh=false; lastPeak = .distantPast; tempo=90; message = value ? "Demo • simulated feeds. These are not your Watch readings." : connected ? "Watch connected • waiting for fresh samples" : "Waiting for Watch • open companion and pair" }
    func capabilityState(_ capability:Capability)->String {
        let id=capability.id
        if capability.stream || capability.access=="Historical" {
            if demo { return capability.stream ? "Simulated":"No simulated record" }
            if let status=statuses[id],!status.isEmpty { return status }
            if let reading=sample(id) {
                if ["crown","touch","steps"].contains(id),Date().timeIntervalSince(reading.date)>=3 { return id=="steps" ? "Session count held":"Ready · last input held" }
                return capability.access=="Historical" ? "Saved record received":"Receiving"
            }
            if samples[id] != nil { return "Stale · last value retained" }
            return "Waiting · "+capability.access.lowercased()
        }
        switch id {
        case "performance":return Date().timeIntervalSince(watchDiagnosticsReceived)<4 ? "Diagnostics receiving":"Waiting for diagnostics"
        case "network":return connected ? "Connected":"Disconnected"
        case "audio":return macToneTestPassed ? "Mac playback started":"Output · Mac test"
        case "haptic","display":return (acknowledgedOutputs[id] ?? 0)>0 ? "Watch command acknowledged":"Output · Watch test"
        case "doubletap":return "Invokes Touch action"
        case "action":return "Ultra only · not enabled"
        default:return capability.access=="Restricted" ? "Unavailable to this app":"Not implemented"
        }
    }
    func sample(_ id:String)->Sample? {
        guard let sample=samples[id] else{return nil}
        let lifetimes:[String:Double] = ["altitude":15,"pressure":15,"heading":10,"location":10]
        let ttl:Double=lifetimes[id] ?? 3
        if demo || paused || Date().timeIntervalSince(sample.date)<ttl || (connected && ["crown","touch","steps"].contains(id)) || ["heart","hrv","oxygen","temperature"].contains(id) {return sample}
        return nil
    }
    func transformed(_ tile:Tile) -> Double { smoothed[tile.id] ?? 0 }
    func ingest(_ id:String, _ values:[Double], source:Date? = nil) {
        guard !values.isEmpty, values.allSatisfy({$0.isFinite}) else { return }
        if id=="lastOutput",let code=values.first,!demo,values.count>=2,values != lastOutputEvent {
            lastOutputEvent=values
            if code>=1 && code<=4 && code.rounded()==code,let target=[1:"haptic",2:"display",3:"display",4:"display"][Int(code)] { acknowledgedOutputs[target,default:0] += 1 }
        }
        if id=="orientation" && !demo { receiveCadence.record() }
        if signalAuditEnabled && !demo {
            let previous=signalObservations[id]
            signalObservations[id]=(count:(previous?.count ?? 0)+1,changes:(previous?.changes ?? 0)+(previous != nil && previous?.last != values ? 1:0),last:values)
        }
        if id=="quaternion",viewYaw==nil,let q=PoseQuaternion(values) {viewYaw=q.euler[2]}
        if id=="heading" {
            let time=source ?? Date()
            if headingDisplayTime != time {
                let dt=headingDisplayTime.map{max(0,time.timeIntervalSince($0))} ?? 1
                let old=displayHeading ?? values[0]
                displayHeading=(old+CardMath.wrap(values[0]-old)*(1-exp(-dt/0.18))+360).truncatingRemainder(dividingBy:360)
                headingDisplayTime=time
            }
        }
        samples[id] = Sample(values:values,date:source ?? Date(),sourceDate:source)
        let history=cardHistories[id] ?? CardHistory();cardHistories[id]=history
        history.append(TimedReading(time:(source ?? Date()).timeIntervalSince1970,values:values))
        var h=histories[id,default:[]]; h.append(values[0]); histories[id] = Array(h.suffix(160))
        for (axis,value) in values.enumerated() {
            let key="\(id)#\(axis)"; var axisHistory=histories[key,default:[]]; axisHistory.append(value); histories[key]=Array(axisHistory.suffix(160))
        }
        if values.count==3 { let key="\(id)#3"; var h=histories[key,default:[]]; h.append(sqrt(values.reduce(0){$0+$1*$1})); histories[key]=Array(h.suffix(160)) }
        if recording && recordRows.count<200000 { recordRows.append("\(Date().timeIntervalSince1970),\(demo ? "demo":usbBridge ? "usb-watch":"watch"),\(id),\(values.map(String.init(describing:)).joined(separator:";"))") }
    }
    func tick() {
        let uptime=ProcessInfo.processInfo.systemUptime
        if uptime-lastPerformanceSample>=1 { macResources=macResourceSampler.sample(now:uptime)
            if let snapshot=bluetoothLink?.ingress.snapshot() { ingressRate=snapshot.0;ingressGap=snapshot.1 } else { ingressRate=nil;ingressGap=nil }
            lastPerformanceSample=uptime;performanceEpoch &+= 1
            if signalAuditEnabled,let path=ProcessInfo.processInfo.environment["WATCHPLAYGROUND_AUDIT_PATH"] {
                let rows:[[String:Any]]=catalog.map { capability in
                    let observation=signalObservations[capability.id]
                    var row:[String:Any]=["id":capability.id,"name":capability.name,"access":capability.access,"receipts":observation?.count ?? 0,"valueChanges":observation?.changes ?? 0,"status":statuses[capability.id] ?? ""]
                    if capability.id=="performance" { row["receipts"]=diagnosticReceiptCount;row["telemetryAgeSeconds"]=max(0,Date().timeIntervalSince(watchDiagnosticsReceived)) }
                    if ["haptic","display"].contains(capability.id) { row["watchCommandAcknowledgements"]=acknowledgedOutputs[capability.id] ?? 0 }
                    if capability.id=="audio" { row["macPlaybackStarted"]=macToneTestPassed }
                    if capability.id=="location",let quality=samples["locationQuality"] {row["quality"]=quality.values}
                    if capability.id=="heading",let quality=samples["headingQuality"] {row["quality"]=quality.values}
                    if capability.id=="network" { row["state"]=connected ? "connected":"disconnected" }
                    if let sample=samples[capability.id] { row["ageSeconds"]=max(0,Date().timeIntervalSince(sample.receivedAt)) }
                    if ["touch","crown"].contains(capability.id),let value=observation?.last { row["inputValue"]=value }
                    return row
                }
                if let data=try? JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys]) { try? data.write(to:URL(fileURLWithPath:path),options:.atomic) }
            }
            if ProcessInfo.processInfo.arguments.contains("--benchmark") {
                let values=sample("gravity")?.values ?? []
                let gravity=values.count>=3 ? Vector3(x:values[0],y:values[1],z:values[2]):.zero
                print("PIPE handoff=\(watchDiagnostics["captureHandoff"] ?? -1) coalesced=\(watchDiagnostics["captureCoalesced"] ?? -1) blocked=\(watchDiagnostics["bleBlocked"] ?? -1) ready=\(watchDiagnostics["bleReady"] ?? -1) age=\(Date().timeIntervalSince(watchDiagnosticsReceived))")
                print("PERF refDownZ=\(referenceDownZ ?? 0) refInverseZ=\(referenceInverseDownZ ?? 0) capture=\(watchDiagnostics["captureHz"] ?? -1) submitted=\(watchDiagnostics["submitHz"] ?? -1) WatchCPU=\(watchDiagnostics["cpu"] ?? -1) memory=\(watchDiagnostics["memory"] ?? -1) ingress=\(ingressRate ?? -1) processed=\(receiveCadence.rate()) UI=\(redrawCadence.rate()) mainLag=\(transportToMainLagMs) crownLeft=\(watchDiagnostics["crownLeft"] ?? -1) q=\([currentPose.x,currentPose.y,currentPose.z,currentPose.w]) gravity=\([gravity.x,gravity.y,gravity.z]) diagAge=\(Date().timeIntervalSince(watchDiagnosticsReceived)) active=\(watchDiagnostics["active"] ?? -1) dimmed=\(watchDiagnostics["dimmed"] ?? -1) downZ=\(currentPose.rotate(gravity).z) inverseDownZ=\(currentPose.inverse.rotate(gravity).z)");fflush(stdout)
            } }
        if draggingCardID==nil && !ProcessInfo.processInfo.arguments.contains("--no-render") && (demo || connected || tiles.contains(where:{$0.capability=="performance"})) { feedClock.objectWillChange.send();feedClock.frame &+= 1 }
        let responseDT=max(0,uptime-responseTick);responseTick=uptime
        if !paused {
            if demo {
                phase += 1/30
                let t=phase
                ingest("orientation",[sin(t*0.8)*1.2,cos(t*0.6)*0.7,sin(t*0.4)])
                ingest("acceleration",[sin(t*2.2)*0.35,cos(t*1.4)*0.2,-0.8+sin(t)*0.15])
                ingest("rotation",[cos(t*0.8),sin(t*0.6)*0.4,cos(t*0.4)*0.5])
                ingest("gravity",[sin(t*0.8)*0.5,cos(t*0.6)*0.4,-0.7])
                let e=pow(max(0,sin(t*Double.pi*3)),5)*0.8
                ingest("intensity",[e]); ingest("stillness",[max(0,1-e*2)])
                ingest("crown",[sin(t*0.3)*2]); ingest("touch",[floor(t/3)])
                ingest("microphone",[-36+sin(t*2)*12]); ingest("altitude",[sin(t*0.1)*4]); ingest("pressure",[101.3+sin(t*0.1)*0.03]); ingest("heading",[(t*12).truncatingRemainder(dividingBy:360)])
                ingest("battery",[76]); ingest("steps",[floor(t*1.5),1.5]); ingest("location",[0,0,0])
            }
            if let detected=sample("rhythm")?.values.first, !demo, tempo != detected { tempo=detected }
            if (demo || sample("rhythm")==nil), let energy=sample("intensity")?.values.first {
                let threshold=tiles.first(where:{$0.capability=="rhythm"}).map { max(0.06,0.22/$0.gain) } ?? 0.22
                if energy>threshold && !peakHigh {
                    let now=Date(), interval=now.timeIntervalSince(lastPeak)
                    if interval>0.3 {
                        if interval<2 { tempo=0.65*tempo+0.35*(60/interval); ingest("rhythm",[tempo]); beats += 1 }
                        lastPeak=now
                    }
                    peakHigh=true
                } else if energy<threshold*0.55 { peakHigh=false }
            }
            for tile in tiles {
                guard let sample=sample(tile.capability) else { continue }
                if let config=tile.settings {
                    updateCardResponse(tile,sample:sample,config:config,now:uptime,dt:responseDT)
                    continue
                }
                let raw = tile.axis==3 && sample.values.count==3 ? sqrt(sample.values.reduce(0){$0+$1*$1}) : sample.values[min(tile.axis,sample.values.count-1)]
                var v=(raw-tile.bias)*tile.gain*(tile.inverted ? -1:1)
                if abs(v)<tile.deadzone { v=0 }
                let old=smoothed[tile.id] ?? v
                smoothed[tile.id] = old+(v-old)*(1-tile.smoothing)
                let adjusted = smoothed[tile.id] ?? 0
                if tile.output == "Tempo" {
                    tempo = tile.capability == "rhythm" ? max(30,min(240,adjusted)) : 40+min(1,abs(adjusted))*160
                }
                let high = adjusted > 0.5
                if high && !(outputHigh[tile.id] ?? false) && Date().timeIntervalSince(lastOutput[tile.id] ?? .distantPast)>1 {
                    if tile.output == "Sound trigger" { playTone(); lastOutput[tile.id]=Date() }
                    if tile.output == "Watch click" && connected { command("haptic"); lastOutput[tile.id]=Date() }
                }
                outputHigh[tile.id] = high
            }
        }
        if metronome && Date().timeIntervalSince(lastTick)>60/max(30,tempo) { lastTick=Date(); beats += 1; tone?.currentTime=0; tone?.play() }
        if connected && Date().timeIntervalSince(lastPacket)>4 { streamAge="No fresh packets"; connected=false; message=usbBridge ? "USB feed paused • keep Playground open on Watch":bluetoothMode ? "Bluetooth feed paused • keep Playground active on Watch":"Watch disconnected • reconnect from the companion" } else if !streamAge.isEmpty { streamAge="" }
    }
    func measurement(_ tile:Tile,values:[Double]?=nil)->Double {
        let values=values ?? sample(tile.capability)?.values ?? []
        let config=tile.settings ?? .defaults(tile.capability)
        var result=CardMath.component(values,axis:tile.axis)
        switch tile.capability {
        case "orientation":
            if values.count>=3 { let q=neutralPose*PoseQuaternion.euler(values[0],values[1],values[2]);result=q.euler[max(0,min(2,tile.axis))] }
            if config.units != "Radians" { result *= 180/Double.pi }
        case "rotation":if config.units != "Radians/s" { result *= 180/Double.pi }
        case "gravity":if config.mode=="Tilt",values.count>=3 { result=Vector3(x:values[0],y:values[1],z:values[2]).faceUpTiltDegrees }
        case "steps":result=config.mode=="Count" ? (values.first ?? 0):((values.count>1 ? values[1]:0)*60)
        case "temperature":if config.units=="°F" { result=result*9/5+32 }
        case "location":if config.units=="km/h" { result *= 3.6 };if config.units=="mph" { result *= 2.236936 }
        case "pressure":if config.units=="hPa" { result *= 10 }
        case "altitude":if config.units=="Feet" { result *= 3.28084 }
        case "touch":result=max(0,result-(config.reference ?? 0))
        case "stillness":
            let points=cardHistories["intensity"]?.points(since:(frozenAt ?? Date()).timeIntervalSince1970-config.window) ?? []
            if points.count>=2 { let rms=sqrt(points.reduce(0){$0+pow($1.values.first ?? 0,2)}/Double(points.count));result=max(0,min(1,1-rms/max(0.001,config.tolerance))) }
        default:break
        }
        return result
    }
    func measurementUnit(_ tile:Tile)->String {
        let c=tile.settings ?? .defaults(tile.capability)
        switch tile.capability {
        case "orientation":return c.units=="Radians" ? "rad":"°"
        case "rotation":return c.units=="Radians/s" ? "rad/s":"°/s"
        case "gravity":return c.mode=="Tilt" ? "°":"g"
        case "steps":return c.mode=="Count" ? "steps":"steps/min"
        case "temperature":return c.units=="°F" ? "°F":"°C"
        case "location":return ["km/h","mph"].contains(c.units) ? c.units:"m/s"
        case "pressure":return c.units=="hPa" ? "hPa":"kPa"
        case "altitude":return c.units=="Feet" ? "ft":"m"
        default:return catalog.first{$0.id==tile.capability}?.unit ?? ""
        }
    }
    func setCardReference(_ id:UUID) {
        guard let index=tiles.firstIndex(where:{$0.id==id}),let sample=sample(tiles[index].capability) else { return }
        var config=tiles[index].settings ?? .defaults(tiles[index].capability)
        config.reference=measurement(tiles[index],values:sample.values)
        if tiles[index].capability=="touch" { config.reference=sample.values.first }
        tiles[index].settings=config;smoothed[id]=nil;persist()
    }
    func chooseRoute(_ id:UUID,_ route:String) {
        guard let index=tiles.firstIndex(where:{$0.id==id}) else { return }
        if route=="Tempo" {
            for i in tiles.indices where tiles[i].id != id && tiles[i].output=="Tempo" { tiles[i].output="Visual" }
        }
        tiles[index].output=route;persist()
    }
    private func updateCardResponse(_ tile:Tile,sample:Sample,config:CardSettings,now:Double,dt:Double) {
        let id=tile.id,kind=tile.capability
        let previousCounter=eventCounters[id];if ["touch","steps"].contains(kind) { eventCounters[id]=sample.values.first ?? 0 }
        guard config.response,catalog.first(where:{$0.id==kind})?.stream==true else { smoothed[id]=0;outputHigh[id]=false;return }
        var raw=measurement(tile),event=false
        if kind=="touch" || (kind=="steps" && config.mode=="Count") {
            let count=sample.values.first ?? 0,n=Double(max(1,config.every))
            event=previousCounter.map{count>$0 && floor(count/n)>floor($0/n)} ?? false
            if event { pulseUntil[id]=now+config.pulseMS/1000;toggleState[id] = !(toggleState[id] ?? false) }
            raw=config.eventMode=="Toggle" ? ((toggleState[id] ?? false) ? 1:0):(now<(pulseUntil[id] ?? 0) ? 1:0)
        } else if kind=="heading" { raw=CardMath.wrap(raw-(config.reference ?? 0)) }
        else { raw -= config.reference ?? 0 }
        if kind=="crown",config.mode=="Delta" {
            let previous=previousResponseRaw[id] ?? raw;previousResponseRaw[id]=raw
            let isNew=previousCrownSource[id] != sample.date;previousCrownSource[id]=sample.date
            raw=isNew ? raw-previous:0
        }
        if abs(raw)<config.deadband { raw=0 }
        let isEvent=kind=="touch" || (kind=="steps" && config.mode=="Count")
        let target=isEvent ? raw:CardMath.normalize(raw,lower:config.lower,upper:config.upper,curve:config.curve,inverted:tile.inverted)
        let old=smoothed[id] ?? target
        let next:Double
        if kind=="heading" && config.smoothingMS>0 {
            // Smooth the circular measurement before mapping across a sector, never across 359→0.
            let previous=previousResponseRaw[id] ?? raw
            let angle=previous+CardMath.wrap(raw-previous)*(1-exp(-dt/(config.smoothingMS/1000)))
            previousResponseRaw[id]=angle;next=CardMath.normalize(CardMath.wrap(angle),lower:config.lower,upper:config.upper,curve:config.curve,inverted:tile.inverted)
        } else { next=CardMath.smooth(old,toward:target,milliseconds:isEvent ? 0:config.smoothingMS,dt:dt) }
        smoothed[id]=next
        if tile.output=="Tempo" { tempo=max(30,min(240,config.outLow+next*(config.outHigh-config.outLow))) }
        let wasHigh=outputHigh[id] ?? false
        let high=isEvent ? event:(kind=="battery" ? raw<=(wasHigh ? config.threshold+config.hysteresis:config.threshold):raw>=(wasHigh ? config.threshold-config.hysteresis:config.threshold))
        if high && (!wasHigh || isEvent) && Date().timeIntervalSince(lastOutput[id] ?? .distantPast)>=config.cooldownMS/1000 {
            if tile.output=="Sound trigger" { playTone() }
            if tile.output=="Watch click",connected { command("haptic") }
            lastOutput[id]=Date()
        }
        outputHigh[id]=high
    }
    private var outputPlayer:AVAudioPlayer? {
        get { cardOutputPlayer }
        set { cardOutputPlayer=newValue }
    }
    func testTone(_ settings:CardSettings) {
        outputPlayer=try? AVAudioPlayer(data:CardTone.wave(frequency:settings.pitch,duration:settings.duration))
        outputPlayer?.volume=Float(max(0,min(1,settings.volume)));macToneTestPassed=outputPlayer?.play()==true
        note=macToneTestPassed ? "Mac test tone started.":"Mac tone could not start.";outputMessages["audio"]=note
    }
    func stopTestTone() { outputPlayer?.stop();outputMessages["audio"]="Mac test tone stopped." }

    func startRecording() { recordRows=["timestamp,source,capability,values"]; recording=true; note="Recording locally. Stop & export when ready." }
    func exportRecording() {
        recording=false
        let panel=NSSavePanel(); panel.nameFieldStringValue="Watch-playground.csv"; panel.allowedContentTypes=[.commaSeparatedText]
        if panel.runModal() == .OK, let url=panel.url { do { try recordRows.joined(separator:"\n").write(to:url,atomically:true,encoding:.utf8); note="Recording exported." } catch { note=error.localizedDescription } }
    }
    func prepareTone() {
        tone=try? AVAudioPlayer(data:CardTone.wave(frequency:880,duration:0.045));tone?.prepareToPlay()
    }
    func playTone() { tone?.currentTime=0;macToneTestPassed=tone?.play()==true }
    func startServer() {
        do {
            listener=try NWListener(using:.tcp,on:8765)
            listener?.newConnectionHandler={ [weak self] connection in Task { @MainActor in self?.accept(connection) } }
            listener?.stateUpdateHandler={ [weak self] state in if case .failed(let e)=state { Task { @MainActor in self?.message="Watch listener: \(e.localizedDescription)" } } }
            listener?.start(queue:.main)
        } catch { message="Could not open Watch port: \(error.localizedDescription)" }
    }
    func accept(_ c:NWConnection) {
        let id=UUID(); clients[id]=c; buffers[id]=Data(); clientActivity[id]=Date(); c.start(queue:.main); receive(id); expireIdleClient(id)
    }
    func expireIdleClient(_ id:UUID) {
        DispatchQueue.main.asyncAfter(deadline:.now()+15) { [weak self] in
            guard let self,let date=self.clientActivity[id] else { return }
            if Date().timeIntervalSince(date)>=15 { self.disconnect(id) } else { self.expireIdleClient(id) }
        }
    }
    func disconnect(_ id:UUID) { clients[id]?.cancel(); clients.removeValue(forKey:id); buffers.removeValue(forKey:id); clientActivity.removeValue(forKey:id) }
    func consumeRequest(_ id:UUID)->Bool {
        guard let buffer=buffers[id] else { return true }
        guard buffer.count<=65536 else { disconnect(id); return true }
        guard let range=buffer.range(of:Data("\r\n\r\n".utf8)),let head=String(data:buffer[..<range.lowerBound],encoding:.utf8) else { return false }
        let lines=head.components(separatedBy:"\r\n")
        let lengthLine=lines.first{$0.lowercased().hasPrefix("content-length:")}
        guard lines.first?.hasPrefix("POST /feed HTTP/")==true,let lengthLine,let length=Int(lengthLine.split(separator:":",maxSplits:1)[1].trimmingCharacters(in:.whitespaces)),length>=0,length<=60000 else { respond(id,["error":"Invalid request"],status:400); return true }
        guard buffer.count-range.upperBound>=length else { return false }
        let end=range.upperBound+length
        let body=Data(buffer[range.upperBound..<end]); buffers[id]=Data(buffer[end...]); clientActivity[id]=Date()
        handleHTTP(body,id:id); return true
    }
    func receive(_ id:UUID) {
        if consumeRequest(id) { return }
        clients[id]?.receive(minimumIncompleteLength:1,maximumLength:16384) { [weak self] data,_,done,error in
            Task { @MainActor in
                guard let self,self.clients[id] != nil else { return }
                if let data,!data.isEmpty { self.buffers[id,default:Data()].append(data); self.clientActivity[id]=Date() }
                if self.consumeRequest(id) { return }
                if done || error != nil { self.disconnect(id) } else { self.receive(id) }
            }
        }
    }
    func respond(_ id:UUID,_ obj:[String:Any],status:Int=200) {
        guard let body=try? JSONSerialization.data(withJSONObject:obj) else { disconnect(id); return }
        let keepAlive=status==200
        let header="HTTP/1.1 \(status) \(status==200 ? "OK":"Error")\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: \(keepAlive ? "keep-alive":"close")\r\nCache-Control: no-store\r\n\r\n"
        clients[id]?.send(content:Data(header.utf8)+body,completion:.contentProcessed { [weak self] error in Task { @MainActor in
            guard let self else { return }
            if keepAlive && error==nil { self.receive(id) } else { self.disconnect(id) }
        } })
    }
    func recordHTTP(accepted:Bool,object:[String:Any]) {
        if accepted {
            httpAccepted += 1
            if let source=(object["dates"] as? [String:Double])?["orientation"],source != lastHTTPSource { httpUnique += 1; lastHTTPSource=source }
        } else { httpRejected += 1 }
        let elapsed=ProcessInfo.processInfo.systemUptime-httpInputWindow
        if elapsed>=1 {
            httpRate=Double(httpUnique)/elapsed
            if ProcessInfo.processInfo.arguments.contains("--benchmark") { print("HTTP INPUT accepted=\(Double(httpAccepted)/elapsed) unique=\(Double(httpUnique)/elapsed) reordered=\(httpRejected)"); fflush(stdout) }
            httpAccepted=0; httpRejected=0; httpUnique=0; httpInputWindow=ProcessInfo.processInfo.systemUptime
        }
    }
    func handleHTTP(_ data:Data,id:UUID) {
        guard let obj=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] else { respond(id,["error":"Invalid JSON"],status:400); return }
        if let code=obj["pair"] as? String {
            guard code==pairingCode else { respond(id,["error":"Incorrect pairing code"],status:403); return }
            sessions=sessions.filter{Date().timeIntervalSince($0.value)<300}
            sessionSequences=sessionSequences.filter{sessions[$0.key] != nil}
            guard sessions.count<8 else { respond(id,["error":"Restart Mac app to pair again"],status:429); return }
            let token=UUID().uuidString; sessions[token]=Date(); lastPacket=Date(); if !connected { connected=true }; setDemo(false)
            respond(id,["paired":true,"session":token]); return
        }
        guard let token=obj["session"] as? String,let date=sessions[token],Date().timeIntervalSince(date)<300 else { respond(id,["error":"Pair again"],status:403); return }
        if let sequence=obj["sequence"] as? Int {
            guard sequence>(sessionSequences[token] ?? -1) else { recordHTTP(accepted:false,object:obj); respond(id,["ok":true,"commands":[]]); return }
            sessionSequences[token]=sequence
        }
        if !bluetoothMode && !usbBridge && message != "Live Watch feeds • local HTTP" { message="Live Watch feeds • local HTTP" }
        if let diagnostics=obj["diagnostics"] as? [String:Double] { updateWatchDiagnostics(diagnostics) }
        recordHTTP(accepted:true,object:obj)
        sessions[token]=Date(); lastPacket=Date(); if !connected { connected=true }
        if let status=obj["status"] as? [String:String] {
            for (key,value) in status where catalog.contains(where:{$0.id==key}) {
                if value.isEmpty { statuses.removeValue(forKey:key) }
                else { statuses[key]=value;samples.removeValue(forKey:key) }
            }
        }
        if !demo,!paused,let values=obj["values"] as? [String:[Double]] {
            let dates=obj["dates"] as? [String:Double] ?? [:]
            for (key,value) in values where key=="quaternion" || key=="lastOutput" || catalog.contains(where:{$0.id==key}) { ingest(key,value,source:dates[key].map{Date(timeIntervalSince1970:$0)}) }
        }
        let pending=commands; commands=[]; respond(id,["ok":true,"commands":pending])
    }
    private func outputKey(_ name:String)->String {name=="haptic" ? "haptic":["mint","violet","reset"].contains(name) ? "display":"audit"}
    func recordCommandResult(_ name:String,accepted:Bool,detail:String?=nil) {
        let message=detail ?? (accepted ? "Watch executed \(name). Physical result needs confirmation.":"Watch rejected \(name).")
        outputMessages[outputKey(name)]=message;note=message
    }
    func command(_ name:String) {
        outputMessages[outputKey(name)]=connected ? "Sending \(name)…":"Connect the Watch to test this output."
        if bluetoothMode && connected {bluetoothLink?.command(name);note="Sent \(name) over Bluetooth.";return}
        if connected {commands=Array((commands+[name]).suffix(32));note="Sent \(name) to Watch."}
        else {note="Connect your Watch to try this output."}
    }
    func startBluetooth() {
        stopUSBBridge(); bluetoothLink?.stop(); bluetoothLink=nil
        bluetoothMode=true; setDemo(false)
        bluetoothLink=BluetoothLink(studio:self)
    }
    func applyControllerRate() { bluetoothLink?.setRate(controllerRate) }
    func stopBluetooth() { bluetoothLink?.stop(); bluetoothLink=nil; bluetoothMode=false; connected=false; bluetoothRTT=""; bluetoothRate=0; message="Direct Bluetooth stopped" }
    func touchBluetoothPacket() {
        lastPacket=Date(); if !connected { connected=true }
        if message != "Direct Bluetooth • real Watch feeds" { message="Direct Bluetooth • real Watch feeds" }
    }
    func startUSBBridge() {
        if bluetoothMode { stopBluetooth() }
        guard bridgeTask==nil else { return }
        bridgeGeneration=UUID(); let generation=bridgeGeneration
        usbBridge=true; setDemo(false); message="Finding your physical Watch via Apple development tools…"
        bridgeTask=Task { [weak self] in
            guard let self else { return }
            let folder=FileManager.default.temporaryDirectory.appendingPathComponent("WatchPlaygroundUSB-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
            defer { try? FileManager.default.removeItem(at:folder); if self.bridgeGeneration==generation { self.bridgeTask=nil } }
            let listFile=folder.appendingPathComponent("devices.json")
            let listed=await BridgeTools.run(["list","devices","--json-output",listFile.path,"--timeout","15"])
            guard !Task.isCancelled,self.bridgeGeneration==generation else { return }
            guard listed.0==0,let data=try? Data(contentsOf:listFile),let object=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],let result=object["result"] as? [String:Any],let devices=result["devices"] as? [[String:Any]],let watch=devices.first(where:{ d in
                let h=d["hardwareProperties"] as? [String:Any]; return h?["platform"] as? String == "watchOS" && h?["reality"] as? String == "physical"
            }),let id=watch["identifier"] as? String else { self.message="No physical Watch found. Keep iPhone plugged in and Watch unlocked."; self.usbBridge=false; self.bridgeTask=nil; return }
            guard !Task.isCancelled,self.bridgeGeneration==generation else { return }
            _=await BridgeTools.run(["device","info","ddiServices","--device",id,"--timeout","20"])
            guard !Task.isCancelled,self.bridgeGeneration==generation else { return }
            let launch=await BridgeTools.run(["device","process","launch","--terminate-existing","--device",id,"--timeout","20","com.example.watchplayground.companion","--usb-bridge"])
            guard !Task.isCancelled,self.bridgeGeneration==generation else { return }
            guard launch.0==0 else { self.message="Could not open Watch companion. Unlock Watch and try USB bridge again."; self.usbBridge=false; self.bridgeTask=nil; return }
            self.message="USB bridge starting • keep Playground open on Watch"
            let snapshot=folder.appendingPathComponent("live-feed.json")
            let commandFile=folder.appendingPathComponent("bridge-command.json")
            var lastCapture=0.0
            while !Task.isCancelled && self.bridgeGeneration==generation {
                let response=await BridgeTools.run(["device","copy","from","--device",id,"--source","Documents/live-feed.json","--domain-type","appDataContainer","--domain-identifier","com.example.watchplayground.companion","--destination",snapshot.path,"--timeout","8"])
                guard !Task.isCancelled,self.bridgeGeneration==generation else { break }
                if response.0 != 0 && lastCapture==0 { self.note="Waiting for Watch snapshot. Keep its Playground app open and allow Motion & Fitness." }
                if response.0==0,let data=try? Data(contentsOf:snapshot),let obj=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],let captured=obj["captured"] as? Double,captured>lastCapture,let values=obj["values"] as? [String:[Double]] {
                    lastCapture=captured
                    if Date().timeIntervalSince1970-captured<5 {
                        self.connected=true; self.lastPacket=Date(); self.message="Real Watch feeds • USB bridge via connected iPhone"
                        if let diagnostics=obj["diagnostics"] as? [String:Double] { self.updateWatchDiagnostics(diagnostics) }
                        if let status=obj["status"] as? [String:String] { self.statuses.merge(status){_,new in new} }
                        let dates=obj["dates"] as? [String:Double] ?? [:]
                        if !self.paused && !self.demo { for (key,value) in values { self.ingest(key,value,source:dates[key].map{Date(timeIntervalSince1970:$0)}) } }
                    }
                }
                if !self.commands.isEmpty {
                    let pending=self.commands; self.commands=[]
                    if let data=try? JSONSerialization.data(withJSONObject:["id":UUID().uuidString,"commands":pending]) {
                        try? data.write(to:commandFile,options:.atomic)
                        _=await BridgeTools.run(["device","copy","to","--device",id,"--source",commandFile.path,"--domain-type","appDataContainer","--domain-identifier","com.example.watchplayground.companion","--destination","Documents/bridge-command.json","--timeout","8"])
                    }
                }
                try? await Task.sleep(for:.milliseconds(250))
            }
        }
    }
    func stopUSBBridge() {
        bridgeGeneration=UUID(); bridgeTask?.cancel(); bridgeTask=nil; usbBridge=false; connected=false; message="USB bridge stopped"
    }
    var macAddress:String {
        // Resolve the active Wi-Fi interface without exposing unrelated interface details.
        var address: String = ""
        var list: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&list)==0, let first=list {
            defer { freeifaddrs(list) }
            var cursor: UnsafeMutablePointer<ifaddrs>?=first
            while let p=cursor {
                if String(cString:p.pointee.ifa_name)=="en0", let a=p.pointee.ifa_addr, a.pointee.sa_family==UInt8(AF_INET) {
                    var host=[CChar](repeating:0,count:Int(NI_MAXHOST)); getnameinfo(a,socklen_t(a.pointee.sa_len),&host,socklen_t(host.count),nil,0,NI_NUMERICHOST); address=String(cString:host)
                }
                cursor=p.pointee.ifa_next
            }
        }
        return address.isEmpty ? "Check Wi-Fi settings for Mac IP" : address
    }
}

// Xcode's supported device file-transfer service is an optional local fallback.
// Processes run off the UI thread and have bounded lifetimes.
enum BridgeTools {
    static func run(_ arguments:[String]) async -> (Int32,String) {
        await Task.detached {
            let process=Process(); process.executableURL=URL(fileURLWithPath:"/usr/bin/xcrun")
            process.arguments=["devicectl"]+arguments
            var env=ProcessInfo.processInfo.environment; env["DEVELOPER_DIR"]="/Applications/Xcode.app/Contents/Developer"; process.environment=env
            let pipe=Pipe(); process.standardOutput=pipe; process.standardError=pipe
            do {
                try process.run()
                let watchdog=DispatchWorkItem { if process.isRunning { process.terminate() } }
                DispatchQueue.global().asyncAfter(deadline:.now()+25,execute:watchdog)
                let data=pipe.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit(); watchdog.cancel()
                return (process.terminationStatus,String(data:data,encoding:.utf8) ?? "")
            } catch { return (Int32(-1),error.localizedDescription) }
        }.value
    }
}
