import SwiftUI

struct PlotPoint { let time:Double,value:Double }
struct TimePlot:View {
    let series:[[PlotPoint]],colors:[Color]
    let lower:Double,upper:Double,window:Double,unit:String
    let now:Double
    var body:some View {
        VStack(spacing:3) {
            HStack {Text(String(format:"%.2f",upper)+" "+unit);Spacer();Text("SOURCE · fixed span")}.font(.system(size:8,design:.monospaced)).foregroundStyle(.secondary)
            Canvas { context,size in
                let start=now-window,range=max(0.00001,upper-lower)
                for fraction in [0.0,0.5,1.0] {var grid=Path();grid.move(to:CGPoint(x:0,y:size.height*fraction));grid.addLine(to:CGPoint(x:size.width,y:size.height*fraction));context.stroke(grid,with:.color(.white.opacity(0.08)),lineWidth:1)}
                for (index,points) in series.enumerated() {
                    var path=Path(),previous:Double?
                    let intervals=zip(points,points.dropFirst()).map{$1.time-$0.time}.filter{$0>0}.sorted()
                    let typical=intervals.isEmpty ? 0.1:intervals[intervals.count/2]
                    let gapLimit=max(0.5,typical*4)
                    let strideCount=max(1,points.count/400)
                    for i in stride(from:0,to:points.count,by:strideCount) {
                        let p=points[i],x=(p.time-start)/window*size.width,y=(1-(p.value-lower)/range)*size.height
                        let point=CGPoint(x:x,y:max(0,min(size.height,y)))
                        if let previous,p.time-previous<gapLimit {path.addLine(to:point)}else{path.move(to:point)}
                        previous=p.time
                    }
                    context.stroke(path,with:.color(colors[index%colors.count]),style:StrokeStyle(lineWidth:1.7,dash:index==1 ? [4,2]:index==2 ? [1,2]:[]))
                    if let last=points.last {let point=CGPoint(x:(last.time-start)/window*size.width,y:max(0,min(size.height,(1-(last.value-lower)/range)*size.height)));context.fill(Path(ellipseIn:CGRect(x:point.x-2,y:point.y-2,width:4,height:4)),with:.color(colors[index%colors.count]))}
                }
            }.clipped()
            HStack {Text(String(format:"%.2f",lower)+" "+unit);Spacer();Text("−\(Int(window))s → now")}.font(.system(size:8,design:.monospaced)).foregroundStyle(.secondary)
        }.padding(9).background(.black.opacity(0.16),in:RoundedRectangle(cornerRadius:11))
    }
}
struct LevelInstrument:View {
    let value:Double,color:Color
    var body:some View {
        GeometryReader { geo in
            ZStack(alignment:.leading) {RoundedRectangle(cornerRadius:5).fill(.white.opacity(0.06));RoundedRectangle(cornerRadius:5).fill(color.gradient).frame(width:max(0,min(1,value))*geo.size.width)}
        }.frame(height:20)
    }
}
struct CompassInstrument:View {
    let angle:Double,reference:Double?,color:Color
    var body:some View {
        Canvas { ctx,size in
            let center=CGPoint(x:size.width/2,y:size.height/2),radius=min(size.width,size.height)*0.40
            ctx.stroke(Path(ellipseIn:CGRect(x:center.x-radius,y:center.y-radius,width:radius*2,height:radius*2)),with:.color(.white.opacity(0.15)),lineWidth:1)
            for (label,degrees) in [("N",0.0),("E",90.0),("S",180.0),("W",270.0)] {let a=(degrees-90)*Double.pi/180;ctx.draw(Text(label).font(.system(size:9,weight:.medium)).foregroundColor(.secondary),at:CGPoint(x:center.x+cos(a)*(radius+10),y:center.y+sin(a)*(radius+10)))}
            let a=(angle-90)*Double.pi/180,end=CGPoint(x:center.x+cos(a)*radius*0.85,y:center.y+sin(a)*radius*0.85)
            var needle=Path();needle.move(to:center);needle.addLine(to:end);ctx.stroke(needle,with:.color(color),style:StrokeStyle(lineWidth:3,lineCap:.round))
            if let reference {let a=(reference-90)*Double.pi/180;let point=CGPoint(x:center.x+cos(a)*radius,y:center.y+sin(a)*radius);ctx.fill(Path(ellipseIn:CGRect(x:point.x-3,y:point.y-3,width:6,height:6)),with:.color(.white))}
        }.accessibilityLabel("Magnetic heading \(Int(angle)) degrees")
    }
}
struct EncoderInstrument:View {
    let value:Double,span:Double,color:Color
    var body:some View {
        HStack(spacing:16) {
            ZStack {Circle().stroke(.white.opacity(0.08),lineWidth:8);ForEach(0..<20){i in Capsule().fill(color.opacity(i%5==0 ? 0.8:0.25)).frame(width:2,height:i%5==0 ? 8:4).offset(y:-40).rotationEffect(.degrees(Double(i)*18))};Capsule().fill(color).frame(width:3,height:30).offset(y:-16).rotationEffect(.degrees(value/span*270))}.frame(width:90,height:90)
            VStack(alignment:.leading,spacing:7) {Text("ENCODER INPUT").font(.system(size:9,design:.monospaced));Text("Held control value").font(.caption);Text("Control units, not physical turns").font(.system(size:10)).foregroundStyle(.secondary)}
        }.frame(maxWidth:.infinity)
    }
}
struct PoseCardInstrument:View {
    @EnvironmentObject var s:Studio
    let gravity:Bool,color:Color
    private var g:Vector3 {let v=s.samples["gravity"]?.values ?? [];return v.count==3 ? Vector3(x:v[0],y:v[1],z:v[2]):.zero}
    var body:some View {
        VStack(spacing:1) {
            WatchDiagram(pose:s.physicalDisplayPose,gravity:gravity ? g:nil,crownLeft:s.demo ? false:s.watchDiagnostics["crownLeft"].map{$0==1},color:color).frame(height:112)
            HStack {Text(gravity ? String(format:"Physical pose · |g| %.2f g",g.length):"Physical pose · desk view");Spacer();Button("Align view") {s.alignPoseView()}.buttonStyle(.borderless);Text(s.watchDiagnostics["crownLeft"]==1 ? "Crown L":"Crown R")}.font(.system(size:8,design:.monospaced)).foregroundStyle(.secondary)
        }.frame(height:132)
    }
}
struct BatteryInstrument:View {
    let level:Double,state:Double?
    private var label:String {guard let state else{return "Charge state unavailable"};return [1:"Unplugged",2:"Charging",3:"Full"][Int(state)] ?? "Charge state unknown"}
    var body:some View {
        HStack(spacing:18) {
            ZStack(alignment:.bottom) {RoundedRectangle(cornerRadius:12).stroke(.white.opacity(0.2),lineWidth:2);RoundedRectangle(cornerRadius:9).fill(Color.green.opacity(0.7)).frame(height:max(0,min(1,level/100))*70).padding(4);if state==2 {Image(systemName:"bolt.fill").font(.title).foregroundStyle(.white).frame(maxHeight:.infinity)}}.frame(width:55,height:80)
            VStack(alignment:.leading,spacing:7) {Text(label).font(.headline);Text("Actual Watch battery\n0–100 percent").font(.caption2).foregroundStyle(.secondary)}
        }.frame(maxWidth:.infinity)
    }
}
struct LocationInstrument:View {
    let points:[TimedReading],color:Color,window:Double
    var body:some View {
        VStack(spacing:5) {
            Canvas { ctx,size in
                guard let first=points.first,first.values.count>=3 else {
                    ctx.draw(Text("No recent fixes · try near a window or outdoors").font(.system(size:9)).foregroundColor(.secondary),at:CGPoint(x:size.width/2,y:size.height/2));return
                }
                let lat=first.values[1],lon=first.values[2]
                let coords=points.filter{$0.values.count>=3}.map{CGPoint(x:($0.values[2]-lon)*111_320*cos(lat*Double.pi/180),y:($0.values[1]-lat)*111_320)}
                let extent=max(5,coords.map{max(abs($0.x),abs($0.y))}.max() ?? 5)
                var path=Path()
                for (i,p) in coords.enumerated() {let view=CGPoint(x:size.width/2+p.x/extent*size.width*0.4,y:size.height/2-p.y/extent*size.height*0.4);if i==0 || points[i].time-points[i-1].time>max(5,window/8){path.move(to:view)}else{path.addLine(to:view)}}
                ctx.stroke(path,with:.color(color),lineWidth:2)
                if let p=coords.last {let center=CGPoint(x:size.width/2+p.x/extent*size.width*0.4,y:size.height/2-p.y/extent*size.height*0.4);ctx.fill(Path(ellipseIn:CGRect(x:center.x-4,y:center.y-4,width:8,height:8)),with:.color(color))}
                ctx.draw(Text(String(format:"±%.0f m · N ↑",extent)).font(.system(size:8,design:.monospaced)).foregroundColor(.secondary),at:CGPoint(x:size.width/2,y:size.height-7))
            }
            Text("Local displacement · coordinates hidden · no map network requests").font(.system(size:8)).foregroundStyle(.secondary)
        }.padding(7).background(.black.opacity(0.16),in:RoundedRectangle(cornerRadius:11))
    }
}
struct ConnectionInstrument:View {
    @EnvironmentObject var s:Studio
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            HStack {Label("Watch",systemImage:"applewatch");Spacer();Image(systemName:s.connected ? "arrow.right":"ellipsis").foregroundStyle(s.connected ? .mint:.orange);Spacer();Label("Mac",systemImage:"desktopcomputer")}.font(.headline)
            Text(s.bluetoothMode ? "DIRECT BLUETOOTH":s.connected ? "LOCAL HTTP":"DISCONNECTED").font(.system(size:11,weight:.semibold,design:.monospaced)).foregroundStyle(.mint)
            Text(s.bluetoothMode ? String(format:"%.0f Hz received · %d Hz requested",s.bluetoothRate,s.controllerRate):String(format:"%.0f Hz received",s.httpRate)).font(.caption.monospaced())
            Text(s.bluetoothRTT.isEmpty ? "No Bluetooth RTT measurement":s.bluetoothRTT).font(.caption2).foregroundStyle(.secondary)
            Text("Connection contact and individual sensor freshness are different.").font(.system(size:10)).foregroundStyle(.secondary)
        }.padding(12).background(.black.opacity(0.12),in:RoundedRectangle(cornerRadius:12))
    }
}
struct OutputInstrument:View {
    @EnvironmentObject var s:Studio
    @Binding var tile:Tile
    private var config:CardSettings {tile.settings ?? .defaults(tile.capability)}
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            if tile.capability=="audio" {
                Text("MAC SPEAKER · LOCAL OUTPUT").font(.system(size:10,weight:.semibold,design:.monospaced)).foregroundStyle(.green)
                HStack {Text("Pitch");Slider(value:setting(\.pitch),in:100...2000);Text("\(Int(config.pitch)) Hz").monospacedDigit()}.font(.caption2)
                HStack {Text("Duration");Slider(value:setting(\.duration),in:0.05...1.5);Text("\(config.duration,specifier:"%.2f")s").monospacedDigit()}.font(.caption2)
                HStack {Text("Volume");Slider(value:setting(\.volume),in:0...1);Text("\(Int(config.volume*100))%").monospacedDigit()}.font(.caption2)
                HStack {Button("Play Mac tone") {s.testTone(config)};Button("Stop") {s.stopTestTone()}}.buttonStyle(.bordered)
            } else if tile.capability=="haptic" {
                HStack {Image(systemName:"applewatch").font(.system(size:38));VStack(alignment:.leading,spacing:6){Text("Notification haptic").font(.headline);Text("A predefined Watch pattern\nNo arbitrary vibration strength").font(.caption2).foregroundStyle(.secondary)}}
                Button("Test Watch notification") {s.command("haptic")}.buttonStyle(.bordered).disabled(!s.connected)
            } else {
                HStack {RoundedRectangle(cornerRadius:12).fill(tile.note=="violet" ? Color.purple:Color.mint).frame(width:42,height:55).overlay(Image(systemName:"checkmark").foregroundStyle(.black));VStack(alignment:.leading){Text("Watch screen presets").font(.headline);Text("Color stays until cleared.\nPreview shows your request.").font(.caption2).foregroundStyle(.secondary)}}
                HStack {Button("Mint") {tile.note="mint";s.command("mint");s.persist()};Button("Violet") {tile.note="violet";s.command("violet");s.persist()};Button("Clear") {tile.note="";s.command("reset");s.persist()}}.buttonStyle(.bordered).disabled(!s.connected)
            }
            Text(s.outputMessages[tile.capability] ?? "Run a test to check this output.").font(.system(size:10)).foregroundStyle(.secondary).lineLimit(2)
            if tile.capability != "audio" {Text("Execution acknowledgement ≠ physical confirmation").font(.system(size:9)).foregroundStyle(.secondary)}
        }
    }
    private func setting(_ key:WritableKeyPath<CardSettings,Double>)->Binding<Double> {Binding(get:{config[keyPath:key]},set:{var p=config;p[keyPath:key]=$0;tile.settings=p})}
}
