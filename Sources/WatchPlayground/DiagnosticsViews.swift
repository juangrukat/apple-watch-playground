import SwiftUI

struct RenderHeartbeat:View {
    @ObservedObject var clock:FeedClock
    let studio:Studio
    var body:some View {
        Color.clear.frame(width:1,height:1).onChange(of:clock.frame) { _,_ in studio.redrawCadence.record() }
    }
}
struct PerformancePanel:View {
    @EnvironmentObject var s:Studio
    private func value(_ key:String)->Double? { guard !s.demo,Date().timeIntervalSince(s.watchDiagnosticFieldDates[key] ?? .distantPast)<4,let v=s.watchDiagnostics[key],v>=0 else { return nil };return v }
    private func text(_ value:Double?,_ suffix:String="")->String { value.map{String(format:"%.0f",$0)+suffix} ?? "—" }
    private var runtimeLabel:String {
        guard let active=value("active"),let dimmed=value("dimmed") else { return "NO TELEMETRY" }
        if active != 1 { return "INACTIVE" }
        return dimmed==1 ? "DIMMED":"ACTIVE"
    }
    private var age:Double { Date().timeIntervalSince(s.watchDiagnosticsReceived) }
    private var timingLabel:String {
        let main=text(s.bluetoothMode ? s.transportToMainLagMs:nil," ms")
        let freshness=age<1000 ? String(format:"%.1fs ago",age):"unavailable"
        return "Main peak \(main) · capture handoff \(text(value("captureHandoff")," ms")) · telemetry \(freshness)"
    }
    private var backpressureLabel:String {
        let coalesced=text(value("captureCoalesced")),blocked=text(value("bleBlocked"),"s"),ready=text(value("bleReady"))
        return "Coalesced \(coalesced) · BLE blocked \(blocked) · ready \(ready) · gaps \(s.sequenceGaps)"
    }
    var body:some View {
        VStack(alignment:.leading,spacing:6) {
            HStack { Label("WATCH APP",systemImage:"applewatch").font(.system(size:9,weight:.bold));Spacer();Text(runtimeLabel).font(.system(size:8,weight:.semibold)).foregroundStyle(value("active")==1 && value("dimmed")==0 ? .mint:.orange) }
            HStack(alignment:.firstTextBaseline) { Text(text(value("cpu"),"%")).font(.system(size:24,weight:.light,design:.rounded));Text("CPU · one-core equivalent").font(.system(size:9)).foregroundStyle(.secondary);Spacer();Text(text(value("memory")," MB")).font(.caption.monospaced()).help("Resident memory used by this app. A whole-Watch memory budget is not exposed here.") }
            GeometryReader { geo in ZStack(alignment:.leading) { Capsule().fill(.white.opacity(0.07));Capsule().fill(Color.mint).frame(width:geo.size.width*min(1,(value("cpu") ?? 0)/100)) } }.frame(height:4).help("Bar spans 0–100% of one core; the numeric reading can exceed 100%. This is not whole-Watch headroom.")
            HStack { Text("Thermal: "+(value("thermal").map{["Nominal","Fair","Serious","Critical"][min(3,Int($0))]} ?? "—"));Spacer();Text(value("lowPower")==1 ? "LOW POWER":"Power: "+(value("lowPower") != nil ? "normal":"—")) }.font(.system(size:9)).foregroundStyle(.secondary)
            HStack {
                Text("Battery "+(s.sample("battery")?.values.first.map{String(format:"%.0f%%",$0)} ?? "—")).foregroundStyle(.secondary)
                Spacer()
                Button("Start all Watch feeds") { s.command("audit-all") }.buttonStyle(.borderless).foregroundStyle(.mint).disabled(!s.connected).help("Enable implemented optional feeds; review any permission prompts on Watch")
            }.font(.system(size:8))
            Divider()
            row("Core Motion delivered",rate:value("captureHz"),gap:value("captureGap"),color:.mint)
            row("Watch submitted",rate:value("submitHz"),gap:nil,color:.cyan)
            if s.bluetoothMode { row("Bluetooth callback",rate:s.ingressRate,gap:s.ingressGap,color:.cyan) }
            row("Mac processed",rate:s.demo ? nil:s.receiveCadence.rate(),gap:s.demo ? nil:s.receiveCadence.gap(),color:.blue)
            row(s.macWindowVisible ? "View heartbeat":"View (occluded)",rate:s.redrawCadence.rate(),gap:s.redrawCadence.gap(),color:.purple)
            Divider()
            HStack { Text("Mac app "+text(s.macResources.cpuPercent,"% CPU"));Spacer();Text(text(s.macResources.residentMB," MB")) }.font(.system(size:9,design:.monospaced))
            Text(backpressureLabel).font(.system(size:8)).foregroundStyle(.secondary)
            Text(timingLabel).font(.system(size:8)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            Text("Rates use separate 1-second windows. View heartbeat measures UI commits, not physical screen FPS.").font(.system(size:8)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
        }.padding(10).background(.black.opacity(0.16),in:RoundedRectangle(cornerRadius:10)).frame(height:294)
    }
    private func row(_ name:String,rate:Double?,gap:Double?,color:Color)->some View {
        HStack { Circle().fill(color).frame(width:5,height:5);Text(name).frame(maxWidth:.infinity,alignment:.leading);Text(text(rate," Hz")).monospacedDigit();Text(gap.map{($0>=1000 ? String(format:"gap %.1fs",$0/1000):String(format:"gap %.0f ms",$0))} ?? "").foregroundStyle(.secondary).frame(width:73,alignment:.trailing) }.font(.system(size:10))
    }
}
struct WatchPosePanel:View {
    @EnvironmentObject var s:Studio
    let gravity:Bool
    let color:Color
    private var crownLeft:Bool? { s.demo ? false:s.watchDiagnostics["crownLeft"].map{$0==1} }
    private var wristLabel:String { s.demo ? "Demo Watch":s.watchDiagnostics["wristRight"].map{$0==1 ? "R wrist":"L wrist"} ?? "Wrist unknown" }
    private var g:Vector3 { let v=s.samples["gravity"]?.values ?? [0,0,-1];return v.count>=3 ? Vector3(x:v[0],y:v[1],z:v[2]):Vector3(x:0,y:0,z:-1) }
    var body:some View {
        VStack(spacing:1) {
            WatchDiagram(pose:gravity ? .identity:s.neutralPose*s.currentPose,gravity:gravity ? g:nil,crownLeft:crownLeft,color:color).frame(height:78)
            HStack(spacing:5) {
                if gravity { Text(String(format:"Tilt %.0f° · %.2f g",g.faceUpTiltDegrees,g.length)).font(.system(size:9,design:.monospaced)) }
                else { Button("Set neutral") { s.setNeutralPose() }.buttonStyle(.borderless).font(.system(size:9)).foregroundStyle(color);Button("Reset") { s.neutralPose = .identity }.buttonStyle(.borderless).font(.system(size:8)).foregroundStyle(.secondary) }
                Spacer(minLength:2)
                Text(wristLabel+" · "+(crownLeft.map{$0 ? "crown L":"crown R"} ?? "crown ?")).font(.system(size:8)).foregroundStyle(.secondary)
            }.padding(.horizontal,6)
        }.frame(height:100)
    }
}
struct WatchDiagram:View {
    let pose:PoseQuaternion
    let gravity:Vector3?
    let crownLeft:Bool?
    let color:Color
    var body:some View {
        Canvas { context,size in
            let camera=PoseQuaternion.euler(-0.65,0,0)
            let rotation=camera*pose
            let scale=min(size.height*0.32,size.width*0.15)
            let center=CGPoint(x:size.width*0.36,y:size.height*0.5)
            func point(_ v:Vector3,origin:CGPoint?=nil)->CGPoint {
                let p=rotation.rotate(v);let perspective=1/(1-p.z*0.11);let o=origin ?? center
                return CGPoint(x:o.x+p.x*scale*perspective,y:o.y-p.y*scale*perspective)
            }
            func path(_ vertices:[Vector3])->Path { var p=Path();for (i,v) in vertices.enumerated(){let a=point(v);if i==0{p.move(to:a)}else{p.addLine(to:a)}};p.closeSubpath();return p }
            func polygon(_ vertices:[Vector3],fill:Color,stroke:Color) {let p=path(vertices);context.fill(p,with:.color(fill));context.stroke(p,with:.color(stroke),lineWidth:1)}
            // Stationary desk plane supplies a world-frame reference for a face-up Watch.
            for step in -2...2 {
                let a=Double(step)*0.8
                for pair in [(Vector3(x:a,y:-1.6,z:-0.18),Vector3(x:a,y:1.6,z:-0.18)),(Vector3(x:-1.6,y:a,z:-0.18),Vector3(x:1.6,y:a,z:-0.18))] {
                    let p=camera.rotate(pair.0),q=camera.rotate(pair.1)
                    var line=Path();line.move(to:CGPoint(x:center.x+p.x*scale,y:center.y-p.y*scale));line.addLine(to:CGPoint(x:center.x+q.x*scale,y:center.y-q.y*scale))
                    context.stroke(line,with:.color(.white.opacity(0.07)),lineWidth:0.5)
                }
            }
            for sign in [-1.0,1.0] {
                polygon([.init(x:-0.36,y:sign*0.7,z:0),.init(x:0.36,y:sign*0.7,z:0),.init(x:0.32,y:sign*1.45,z:-0.03),.init(x:-0.32,y:sign*1.45,z:-0.03)],fill:color.opacity(0.14),stroke:color.opacity(0.35))
            }
            let vertices:[Vector3]=[.init(x:-0.58,y:-0.73,z:0.12),.init(x:0.58,y:-0.73,z:0.12),.init(x:0.67,y:-0.62,z:0.12),.init(x:0.67,y:0.62,z:0.12),.init(x:0.58,y:0.73,z:0.12),.init(x:-0.58,y:0.73,z:0.12),.init(x:-0.67,y:0.62,z:0.12),.init(x:-0.67,y:-0.62,z:0.12)]
            let back=vertices.map{Vector3(x:$0.x,y:$0.y,z:-0.12)}
            polygon(back,fill:Color(white:0.12),stroke:color.opacity(0.45))
            for i in vertices.indices {
                let j=(i+1)%vertices.count
                polygon([vertices[i],vertices[j],back[j],back[i]],fill:Color(white:0.18),stroke:color.opacity(0.35))
            }
            let faceFront=rotation.rotate(Vector3(x:0,y:0,z:1)).z>=0
            polygon(faceFront ? vertices:back,fill:faceFront ? Color(white:0.035):Color(white:0.10),stroke:color)
            if faceFront {
                context.draw(Text("12").font(.system(size:8,weight:.bold)).foregroundColor(color),at:point(.init(x:0,y:0.43,z:0.14)))
                context.draw(Text("FACE").font(.system(size:7,weight:.medium)).foregroundColor(color.opacity(0.7)),at:point(.init(x:0,y:-0.12,z:0.14)))
            } else { context.draw(Text("BACK").font(.system(size:7)).foregroundColor(color),at:point(.init(x:0,y:0,z:-0.14))) }
            if let crownLeft {
                let p=point(.init(x:crownLeft ? -0.78:0.78,y:0.28,z:0))
                context.fill(Path(roundedRect:CGRect(x:p.x-3,y:p.y-5,width:6,height:10),cornerRadius:2),with:.color(color))
            }
            let axisOrigin=CGPoint(x:size.width*0.79,y:size.height*0.52)
            for (name,v,c) in [("X",Vector3(x:0.8,y:0,z:0),Color.red),("Y",Vector3(x:0,y:0.8,z:0),Color.green),("Z",Vector3(x:0,y:0,z:0.8),Color.blue)] {
                let end=point(v,origin:axisOrigin);var p=Path();p.move(to:axisOrigin);p.addLine(to:end);context.stroke(p,with:.color(c),lineWidth:1.6)
                context.draw(Text(name).font(.system(size:8,weight:.bold)).foregroundColor(c),at:CGPoint(x:end.x+5,y:end.y-4))
            }
            if let gravity {
                let start=center;let end=point(Vector3(x:gravity.normalized.x*1.15,y:gravity.normalized.y*1.15,z:gravity.normalized.z*1.15))
                var line=Path();line.move(to:start);line.addLine(to:end);context.stroke(line,with:.color(.orange),style:StrokeStyle(lineWidth:2.5,lineCap:.round))
                let angle=atan2(end.y-start.y,end.x-start.x);var arrow=Path();arrow.move(to:end);arrow.addLine(to:CGPoint(x:end.x-7*cos(angle-0.45),y:end.y-7*sin(angle-0.45)));arrow.move(to:end);arrow.addLine(to:CGPoint(x:end.x-7*cos(angle+0.45),y:end.y-7*sin(angle+0.45)));context.stroke(arrow,with:.color(.orange),lineWidth:2)
                context.draw(Text("g").font(.system(size:10,weight:.bold)).foregroundColor(.orange),at:CGPoint(x:end.x+7,y:end.y+4))
            }
        }.accessibilityLabel(gravity==nil ? "Watch pose, configured Crown, and sensor axes":"Gravity vector relative to the Watch; yaw is not determined")
    }
}

// Brightness follows receipt of actual readings, never a synthetic heartbeat timer.
struct FreshnessPulse:View {
    let received:Date?
    let color:Color
    let frozen:Bool
    var age:Double { received.map { max(0,Date().timeIntervalSince($0)) } ?? .infinity }
    var body:some View {
        let strength=received == nil ? 0:exp(-age/0.35)
        Circle().fill(received == nil ? Color.gray:color)
            .frame(width:7,height:7)
            .opacity(frozen ? 0.25:0.15+0.85*strength)
            .shadow(color:color.opacity(frozen ? 0:strength*0.65),radius:4)
            .help(frozen ? "Display frozen":received == nil ? "No reading received":String(format:"Last reading received %.2f seconds ago",age))
            .accessibilityLabel(received == nil ? "No data":frozen ? "Frozen":String(format:"Last received %.1f seconds ago",age))
    }
}
