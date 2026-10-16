import Foundation

struct FeedDefinition: Identifiable {
    let channel: UInt8
    let id: String
    let name: String
    let unit: String
    let saved: Bool
    init(_ channel: UInt8, _ id: String, _ name: String, _ unit: String = "", saved: Bool = false) {
        self.channel=channel; self.id=id; self.name=name; self.unit=unit; self.saved=saved
    }
    static let all: [FeedDefinition] = [
        .init(1,"orientation","Wrist orientation","rad"), .init(2,"acceleration","Acceleration","g"),
        .init(3,"rotation","Rotation speed","rad/s"), .init(4,"gravity","Gravity","g"),
        .init(5,"intensity","Movement energy","g"), .init(6,"stillness","Stillness"),
        .init(7,"crown","Digital Crown","control"), .init(8,"touch","Touch","taps"),
        .init(9,"battery","Battery","%"), .init(10,"microphone","Microphone level","dBFS"),
        .init(11,"altitude","Relative altitude","m"), .init(12,"pressure","Air pressure","kPa"),
        .init(13,"heading","Compass","°"), .init(14,"steps","Steps / cadence","steps"),
        .init(15,"heart","Heart rate","bpm",saved:true), .init(16,"hrv","Heart variability","ms",saved:true),
        .init(17,"oxygen","Blood oxygen","%",saved:true), .init(18,"temperature","Sleeping wrist temperature","°C",saved:true),
        .init(19,"rhythm","Gesture rhythm","bpm"), .init(20,"location","Location / speed","m/s"),
        .init(22,"locationQuality","Location quality","m"), .init(23,"headingQuality","Compass accuracy","°")
    ]
}
struct FeedReading {
    var values: [Double] = []
    var sourceTime: Double = 0
    var revision: UInt64 = 0
    var state: UInt8 = 0
    var detail: String = "Waiting for a reading"
}
struct MotionFrame {
    let nativeTime: Double
    let sourceTime: Double
    let quaternion: [Double]
    let orientation: [Double]
    let rotation: [Double]
    let gravity: [Double]
    let acceleration: [Double]
    let energy: Double
}
struct CaptureSnapshot {
    var readings: [String: FeedReading] = [:]
    var motion: MotionFrame?
    var captured: UInt64 = 0
    var captureHz: Double = 0
    var captureGap: Double = 0
    var active = true
    var dimmed = false
    var running = false
}
// No actor hops or view invalidations on the capture path. Storage is bounded by known feeds.
final class SampleStore {
    private let lock=NSLock()
    private var snapshot=CaptureSnapshot()
    private var cadence=CadenceWindow()
    private var revision: UInt64=0
    private let valid=Set(FeedDefinition.all.map(\.id)+["lastOutput"])
    func start() {
        lock.lock(); defer { lock.unlock() }
        snapshot=CaptureSnapshot(); snapshot.running=true; cadence=CadenceWindow(); revision=0
    }
    func stop() { lock.lock(); snapshot.running=false; lock.unlock() }
    func runtime(active: Bool, dimmed: Bool) {
        lock.lock(); snapshot.active=active; snapshot.dimmed=dimmed; lock.unlock()
    }
    func put(_ id: String, _ values: [Double], at time: Double = Date().timeIntervalSince1970, detail: String = "Receiving") {
        guard valid.contains(id), !values.isEmpty, values.count<=3, values.allSatisfy(\.isFinite), time.isFinite else { return }
        lock.lock(); defer { lock.unlock() }
        guard snapshot.running else { return }
        write(id,values,time,detail)
    }
    private func write(_ id: String,_ values:[Double],_ time:Double,_ detail:String) {
        if let prior=snapshot.readings[id], time<prior.sourceTime { return }
        revision &+= 1
        snapshot.readings[id]=FeedReading(values:values,sourceTime:time,revision:revision,state:0,detail:detail)
    }
    func status(_ id:String,_ code:UInt8,_ detail:String) {
        guard valid.contains(id) else { return }
        lock.lock(); defer { lock.unlock() }
        guard snapshot.running else { return }
        revision &+= 1
        var reading=snapshot.readings[id] ?? FeedReading()
        reading.state=code; reading.detail=detail; reading.revision=revision
        if code != 0 && code != 10 && code != 11 { reading.values=[] }
        snapshot.readings[id]=reading
    }
    func motion(_ frame:MotionFrame) {
        lock.lock(); defer { lock.unlock() }
        guard snapshot.running, frame.nativeTime.isFinite, snapshot.motion.map({frame.nativeTime>$0.nativeTime}) ?? true else { return }
        snapshot.motion=frame; snapshot.captured &+= 1; cadence.record(frame.nativeTime,allowDuplicate:false)
        for (id,value) in [("orientation",frame.orientation),("acceleration",frame.acceleration),("rotation",frame.rotation),("gravity",frame.gravity),("intensity",[frame.energy]),("stillness",[max(0,1-frame.energy*2)])] {
            write(id,value,frame.sourceTime,"Receiving")
        }
    }
    func read(now:Double=ProcessInfo.processInfo.systemUptime)->CaptureSnapshot {
        lock.lock(); defer { lock.unlock() }
        var result=snapshot; result.captureHz=cadence.rate(now:now); result.captureGap=cadence.gap(now:now)
        return result
    }
}
struct RetrySchedule {
    private(set) var attempts=0
    mutating func nextDelay()->Double { let delay=min(8,pow(2,Double(min(attempts,4)))*0.5); attempts += 1; return delay }
    mutating func reset() { attempts=0 }
}
struct CommandLedger {
    private var completed:[UInt32]=[]
    mutating func accept(_ id:UInt32)->Bool {
        guard !completed.contains(id) else { return false }
        completed.append(id);completed=Array(completed.suffix(64));return true
    }
}
struct LinkSnapshot {
    var phase="Idle"
    var detail="Choose a Mac to start"
    var live=false
    var submitHz=0.0
    var submitted:UInt64=0
    var contactAge=Double.infinity
    var blockedSeconds=0.0
    var readyEvents=0.0
    var reconnects=0
    var mtu=20
    var lastError=""
}
// Immutable snapshots bridge the serial transport worker and the UI.
final class LinkMonitor {
    private let lock=NSLock()
    private var value=LinkSnapshot()
    func update(_ action:(inout LinkSnapshot)->Void) { lock.lock();action(&value);lock.unlock() }
    func read()->LinkSnapshot { lock.lock();defer{lock.unlock()};return value }
}
