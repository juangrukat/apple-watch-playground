import Foundation

struct CanvasJump { let id=UUID();let point:CGPoint }

struct CardSettings:Codable,Equatable {
    var version=1
    var response=false
    var hideValue=false
    var showCoordinates=false
    var lower=0.0,upper=1.0
    var smoothingMS=60.0
    var deadband=0.0
    var threshold=0.5
    var tolerance=0.1
    var hysteresis=0.05
    var cooldownMS=250.0
    var pulseMS=120.0
    var every=1
    var window=10.0
    var span=1.0
    var eventMode="Pulse"
    var mode="Default"
    var units="Default"
    var curve="Linear"
    var reference:Double?
    var outLow=40.0,outHigh=200.0
    var pitch=660.0,duration=0.5,volume=0.35
    init() {}
    private enum CodingKeys:String,CodingKey { case version,response,hideValue,showCoordinates,lower,upper,smoothingMS,deadband,threshold,tolerance,hysteresis,cooldownMS,pulseMS,every,window,span,eventMode,mode,units,curve,outLow,outHigh,pitch,duration,volume,reference }
    init(from decoder:Decoder) throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        version=try c.decodeIfPresent(Int.self,forKey:.version) ?? 1
        response=try c.decodeIfPresent(Bool.self,forKey:.response) ?? false
        hideValue=try c.decodeIfPresent(Bool.self,forKey:.hideValue) ?? false
        showCoordinates=try c.decodeIfPresent(Bool.self,forKey:.showCoordinates) ?? false
        lower=try c.decodeIfPresent(Double.self,forKey:.lower) ?? 0
        upper=try c.decodeIfPresent(Double.self,forKey:.upper) ?? 1
        smoothingMS=try c.decodeIfPresent(Double.self,forKey:.smoothingMS) ?? 60
        deadband=try c.decodeIfPresent(Double.self,forKey:.deadband) ?? 0
        threshold=try c.decodeIfPresent(Double.self,forKey:.threshold) ?? 0.5
        tolerance=try c.decodeIfPresent(Double.self,forKey:.tolerance) ?? 0.1
        hysteresis=try c.decodeIfPresent(Double.self,forKey:.hysteresis) ?? 0.05
        cooldownMS=try c.decodeIfPresent(Double.self,forKey:.cooldownMS) ?? 250
        pulseMS=try c.decodeIfPresent(Double.self,forKey:.pulseMS) ?? 120
        every=try c.decodeIfPresent(Int.self,forKey:.every) ?? 1
        window=try c.decodeIfPresent(Double.self,forKey:.window) ?? 10
        span=try c.decodeIfPresent(Double.self,forKey:.span) ?? 1
        eventMode=try c.decodeIfPresent(String.self,forKey:.eventMode) ?? "Pulse"
        mode=try c.decodeIfPresent(String.self,forKey:.mode) ?? "Default"
        units=try c.decodeIfPresent(String.self,forKey:.units) ?? "Default"
        curve=try c.decodeIfPresent(String.self,forKey:.curve) ?? "Linear"
        outLow=try c.decodeIfPresent(Double.self,forKey:.outLow) ?? 40
        outHigh=try c.decodeIfPresent(Double.self,forKey:.outHigh) ?? 200
        pitch=try c.decodeIfPresent(Double.self,forKey:.pitch) ?? 660
        duration=try c.decodeIfPresent(Double.self,forKey:.duration) ?? 0.5
        volume=try c.decodeIfPresent(Double.self,forKey:.volume) ?? 0.35
        reference=try c.decodeIfPresent(Double.self,forKey:.reference)
    }
    mutating func changeMode(for id:String,to mode:String) {
        self.mode=mode
        if id=="gravity" {lower=mode=="Tilt" ? 0:-1;upper=mode=="Tilt" ? 90:1;span=mode=="Tilt" ? 180:2;deadband=mode=="Tilt" ? 2:0.02;reference=nil}
    }
    mutating func convertUnits(for id:String,to units:String) {
        func scale(_ unit:String)->Double {
            switch id {
            case "orientation":return unit=="Radians" ? 1:180/Double.pi
            case "rotation":return unit=="Radians/s" ? 1:180/Double.pi
            case "altitude":return unit=="Feet" ? 3.28084:1
            case "pressure":return unit=="hPa" ? 10:1
            case "location":return unit=="km/h" ? 3.6:unit=="mph" ? 2.236936:1
            default:return 1
            }
        }
        let ratio=scale(units)/scale(self.units)
        lower *= ratio;upper *= ratio;span *= ratio;deadband *= ratio;threshold *= ratio;hysteresis *= ratio
        if let value=reference { reference=value*ratio }
        self.units=units
    }
    static func defaults(_ id:String)->Self {
        var s=Self()
        switch id {
        case "orientation":s.lower = -30;s.upper=30;s.span=90;s.deadband=2;s.units="Degrees"
        case "acceleration":s.lower = -1;s.upper=1;s.span=2;s.deadband=0.02
        case "rotation":s.lower = -180;s.upper=180;s.span=360;s.units="Degrees/s";s.deadband=3
        case "gravity":s.lower=0;s.upper=90;s.span=1;s.mode="Tilt";s.deadband=2
        case "intensity":s.upper=0.8;s.span=1;s.threshold=0.22
        case "stillness":s.mode="Windowed";s.window=1;s.threshold=0.8;s.upper=1;s.span=1
        case "rhythm":s.lower=40;s.upper=200;s.span=240;s.smoothingMS=0
        case "crown":s.lower = -2;s.upper=2;s.span=4;s.smoothingMS=0;s.mode="Position"
        case "touch":s.mode="Pulse";s.smoothingMS=0;s.span=1
        case "microphone":s.lower = -60;s.upper = -15;s.span=80;s.threshold = -40;s.smoothingMS=60
        case "altitude":s.lower = -5;s.upper=5;s.span=10;s.window=30;s.smoothingMS=300
        case "pressure":s.lower = -0.1;s.upper=0.1;s.span=0.2;s.window=60;s.smoothingMS=1000
        case "heading":s.lower = -90;s.upper=90;s.span=180;s.deadband=3;s.smoothingMS=100
        case "location":s.upper=3;s.span=5;s.smoothingMS=200
        case "steps":s.mode="Count";s.upper=180;s.span=200;s.smoothingMS=200
        case "battery":s.lower=0;s.upper=100;s.span=100;s.threshold=20;s.smoothingMS=0
        default:break
        }
        return s
    }
}
struct TimedReading {
    let time:Double
    let values:[Double]
}
// Reference storage avoids copying a large array for every incoming packet.
final class CardHistory {
    private var ring:[TimedReading]=[]
    private var head=0
    private let capacity=4096
    private var last:TimedReading?
    func append(_ point:TimedReading) {
        guard point.time.isFinite else { return }
        if let last {
            guard point.time>=last.time else { return }
            if point.time==last.time && point.values==last.values { return }
        }
        last=point
        if ring.count<capacity { ring.append(point) } else { ring[head]=point;head=(head+1)%capacity }
    }
    func points(since:Double)->[TimedReading] {
        let ordered=head==0 ? ring:Array(ring[head...])+Array(ring[..<head])
        return ordered.filter{$0.time>=since}
    }
    var count:Int { ring.count }
}
enum CardMath {
    static func wrap(_ degrees:Double)->Double { let v=(degrees+180).truncatingRemainder(dividingBy:360);return (v<0 ? v+360:v)-180 }
    static func normalize(_ value:Double,lower:Double,upper:Double,curve:String,inverted:Bool)->Double {
        guard value.isFinite,lower.isFinite,upper.isFinite,upper>lower else { return 0 }
        var n=max(0,min(1,(value-lower)/(upper-lower)))
        if curve=="Gentle" { n=n*n*(3-2*n) };if curve=="Fast" { n=sqrt(n) }
        return inverted ? 1-n:n
    }
    static func smooth(_ current:Double,toward target:Double,milliseconds:Double,dt:Double)->Double {
        guard milliseconds>0 else { return target }
        return current+(target-current)*(1-exp(-max(0,dt)/(milliseconds/1000)))
    }
    static func component(_ values:[Double],axis:Int)->Double {
        guard !values.isEmpty else { return 0 }
        if axis==3,values.count==3 { return sqrt(values.reduce(0){$0+$1*$1}) }
        return values[max(0,min(axis,values.count-1))]
    }
}
struct CardKit:Identifiable {
    let id:String,name:String,detail:String,capabilities:[String]
    static let builtins:[Self]=[
        .init(id:"motion",name:"Motion garden",detail:"Explore pose, acceleration, spin and steadiness.",capabilities:["orientation","acceleration","rotation","gravity","intensity","stillness"]),
        .init(id:"conductor",name:"Conductor",detail:"Movement, tempo preview, Crown and haptic feedback.",capabilities:["orientation","rhythm","intensity","crown","audio","haptic"]),
        .init(id:"controls",name:"Control desk",detail:"Touch, Crown and visible output experiments.",capabilities:["touch","crown","haptic","display","audio"]),
        .init(id:"sound",name:"Sound playground",detail:"Microphone level, sound gates and Mac tone tests.",capabilities:["microphone","audio","intensity"]),
        .init(id:"environment",name:"Body & environment",detail:"Steps, compass, pressure, relative height and battery.",capabilities:["steps","heading","altitude","pressure","location","battery"]),
        .init(id:"records",name:"Saved Health",detail:"Dated records, with explicit availability and privacy controls.",capabilities:["heart","hrv","oxygen","temperature"]),
        .init(id:"diagnostics",name:"Diagnostics",detail:"Pipeline timing, connection, Watch load and pose.",capabilities:["performance","network","battery","orientation"])
    ]
}

enum CardTone {
    static func wave(frequency:Double,duration:Double)->Data {
        let rate=22050,count=Int(Double(rate)*max(0.02,min(2,duration))),hz=max(80,min(3000,frequency))
        func le<T:FixedWidthInteger>(_ value:T)->Data { var value=value.littleEndian;return withUnsafeBytes(of:&value){Data($0)} }
        var pcm=Data()
        for i in 0..<count { let edge=min(1,min(Double(i)/110,Double(count-i)/220));pcm.append(le(Int16(sin(Double(i)*2*Double.pi*hz/Double(rate))*edge*0.45*32767))) }
        var wav=Data("RIFF".utf8);wav.append(le(UInt32(36+pcm.count)));wav.append(Data("WAVEfmt ".utf8));wav.append(le(UInt32(16)));wav.append(le(UInt16(1)));wav.append(le(UInt16(1)));wav.append(le(UInt32(rate)));wav.append(le(UInt32(rate*2)));wav.append(le(UInt16(2)));wav.append(le(UInt16(16)));wav.append(Data("data".utf8));wav.append(le(UInt32(pcm.count)));wav.append(pcm);return wav
    }
}
