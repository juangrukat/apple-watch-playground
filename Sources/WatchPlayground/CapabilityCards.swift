import SwiftUI

struct Palette:View {
    @EnvironmentObject var s:Studio
    @Binding var tile:Tile
    let clock:FeedClock
    @State private var drag=CGSize.zero
    private var c:Capability { catalog.first{$0.id==tile.capability}! }
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            HStack(spacing:5) {
                ZStack(alignment:.leading) {
                    HStack(spacing:8) { Image(systemName:"line.3.horizontal").font(.system(size:10)).foregroundStyle(.secondary);Image(systemName:c.icon).foregroundStyle(c.color);Text(c.name).font(.system(size:12,weight:.semibold)).lineLimit(2);Spacer(minLength:0) }.allowsHitTesting(false)
                    CardDragHandle(title:c.name,begin:{s.activeCardID=tile.id;s.draggingCardID=tile.id},change:{drag=$0},end:{delta,bypass in s.draggingCardID=nil;s.move(tile.id,x:tile.x+delta.width,y:tile.y+delta.height,bypassSnap:bypass);drag = .zero })
                }.frame(height:38)
                Button { s.activeCardID=tile.id;tile.wide.toggle();s.persist() } label:{Image(systemName:tile.wide ? "arrow.down.right.and.arrow.up.left":"arrow.up.left.and.arrow.down.right")}.help("Expand "+c.name).accessibilityLabel("Expand "+c.name)
                Button { s.tiles.removeAll{$0.id==tile.id};s.persist() } label:{Image(systemName:"xmark")}.help("Remove "+c.name).accessibilityLabel("Remove "+c.name)
            }.buttonStyle(.plain).font(.system(size:11))
            CardLiveBody(tile:$tile,clock:clock)
            Spacer(minLength:0)
            Text(c.explanation).font(.system(size:10)).foregroundStyle(.secondary).lineLimit(tile.wide ? 4:3).help(c.explanation)
        }.padding(16).frame(width:tile.width,height:tile.height,alignment:.topLeading)
            .background(panel,in:RoundedRectangle(cornerRadius:17))
            .overlay(RoundedRectangle(cornerRadius:17).stroke(s.activeCardID==tile.id ? c.color.opacity(0.8):.white.opacity(0.10),lineWidth:s.activeCardID==tile.id ? 1.5:1))
            .shadow(color:.black.opacity(drag == .zero ? 0.16:0.45),radius:drag == .zero ? 8:20,y:5)
            .offset(drag)
            .onChange(of:tile.settings) { _,_ in s.activeCardID=tile.id;s.persist() }
            .onChange(of:tile.axis) { _,_ in if var p=tile.settings {p.reference=nil;tile.settings=p};s.resetCardResponse(tile.id);s.persist() }
    }
}
struct CardLiveBody:View {
    @EnvironmentObject var s:Studio
    @Binding var tile:Tile
    @ObservedObject var clock:FeedClock
    private var c:Capability { catalog.first{$0.id==tile.capability}! }
    private var sample:Sample? {
        guard let reading=s.sample(c.id) else{return nil}
        if c.id=="steps",config.mode=="Cadence",!s.demo,!s.paused,Date().timeIntervalSince(reading.date)>3 {return nil}
        return reading
    }
    private var config:CardSettings { tile.settings ?? .defaults(c.id) }
    private var value:Double { s.measurement(tile) }
    private var unit:String { s.measurementUnit(tile) }
    var body:some View {
        VStack(alignment:.leading,spacing:9) {
            statusRow
            if c.id=="performance" { PerformancePanel() }
            else if c.access=="Historical" { savedRecord }
            else if c.access=="Output" { OutputInstrument(tile:$tile) }
            else if c.id=="network" { ConnectionInstrument() }
            else if c.stream {
                if sample != nil || c.id=="location" { instrument }
                else { missing }
                HStack(alignment:.firstTextBaseline,spacing:5) {
                    Text(sample == nil || (c.id=="location" && (sample?.values.first ?? -1)<0) ? "—":formatted(value)).font(.system(size:28,weight:.medium,design:.rounded)).monospacedDigit()
                    Text(unit).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if c.id=="rhythm" { Button(s.metronome ? "Stop preview":"Beat preview") { s.metronome.toggle() }.font(.caption2) }
                }
                sourceSettings
                if ["acceleration","rotation","pressure","altitude","steps"].contains(c.id) {plotControls}
                Toggle("Creative response",isOn:Binding(get:{config.response},set:{ var p=config;p.response=$0;if $0,p.reference==nil,["pressure","heading","altitude","crown"].contains(c.id) {p.reference=value};tile.settings=p;s.smoothed[tile.id]=nil })).toggleStyle(.switch).controlSize(.mini).font(.system(size:10)).accessibilityLabel("Creative response for "+c.name)
                if config.response { ResponseEditor(tile:$tile) }
            } else { reference }
        }
    }
    private func formatted(_ x:Double)->String {
        if ["touch","steps","battery"].contains(c.id) { return String(format:"%.0f",x) }
        return String(format:c.id=="pressure" ? "%.3f":"%.2f",x)
    }
    private var statusRow:some View {
        HStack(spacing:6) {
            FreshnessPulse(received:c.access=="Historical" ? nil:s.samples[c.id]?.receivedAt,color:c.color,frozen:s.paused)
            Text(status).lineLimit(1)
            Spacer(minLength:0)
            Text(c.access=="Historical" ? "SAVED":s.demo && c.stream ? "SIMULATED":c.stream ? "SOURCE":c.access.uppercased()).font(.system(size:8,weight:.semibold,design:.monospaced)).foregroundStyle(c.color)
        }.font(.system(size:9)).foregroundStyle(.secondary)
    }
    private var status:String {
        if s.paused,c.stream { return "View frozen" }
        if s.demo,c.stream { return "Simulated · not your Watch" }
        if !s.demo,!s.connected,c.stream {return "Disconnected · last source reading"}
        if let issue=s.statuses[c.id],!issue.isEmpty,!s.demo { return issue }
        if let reading=sample {
            if c.access=="Historical" { return "Recorded "+reading.date.formatted(date:.abbreviated,time:.shortened) }
            let age=max(0,Date().timeIntervalSince(reading.date))
            if ["touch","crown"].contains(c.id) { return String(format:"Held input · source %.1fs ago",age) }
            return String(format:"Source %.1fs ago",age)
        }
        return c.stream ? c.activationHint:s.capabilityState(c)
    }
    private var missing:some View {
        VStack(spacing:8) { Image(systemName:c.icon).font(.system(size:25)).foregroundStyle(c.color.opacity(0.6));Text(s.samples[c.id]==nil ? "Waiting for a source reading":"Last value held · source is stale").font(.caption2).foregroundStyle(.secondary) }.frame(maxWidth:.infinity).frame(height:125).background(.black.opacity(0.14),in:RoundedRectangle(cornerRadius:12))
    }
    @ViewBuilder private var instrument:some View {
        switch c.id {
        case "orientation","gravity":PoseCardInstrument(gravity:c.id=="gravity",color:c.color)
        case "heading":CompassInstrument(angle:s.displayHeading ?? value,reference:config.reference,color:c.color).frame(height:125)
        case "crown":EncoderInstrument(value:value,span:max(0.01,config.upper-config.lower),color:c.color).frame(height:125)
        case "touch":
            VStack(spacing:8) { Image(systemName:"hand.tap.fill").font(.system(size:38)).foregroundStyle(c.color).opacity(0.25+0.75*exp(-max(0,Date().timeIntervalSince(sample?.date ?? .distantPast))/0.25));Text("PAD ACTIVATIONS").font(.system(size:9,design:.monospaced));Text("Counter changes are events; repeated packets are not.").font(.system(size:10)).foregroundStyle(.secondary) }.frame(maxWidth:.infinity).frame(height:125).background(c.color.opacity(0.06),in:RoundedRectangle(cornerRadius:12))
        case "microphone":
            VStack(alignment:.leading,spacing:9) { Text("RMS LEVEL · dBFS").font(.system(size:9,design:.monospaced));LevelInstrument(value:(value+80)/80,color:c.color);HStack {Text("−80");Spacer();Text("−40");Spacer();Text("0")}.font(.system(size:9,design:.monospaced)).foregroundStyle(.secondary);Text("Level only · no waveform or audio transmitted").font(.system(size:9)).foregroundStyle(.secondary) }.padding(12).frame(height:125).background(.black.opacity(0.14),in:RoundedRectangle(cornerRadius:12))
        case "intensity","stillness":
            VStack(alignment:.leading,spacing:10) { Text(c.id=="stillness" ? "DERIVED STEADINESS · \(config.window,specifier:"%.1f")s WINDOW":"GRAVITY-FREE MOVEMENT MAGNITUDE").font(.system(size:9,design:.monospaced));LevelInstrument(value:c.id=="stillness" ? value:value/max(0.01,config.span),color:c.color);Text(c.id=="stillness" ? "From received movement levels; not a medical measure.":"0 to \(config.span,specifier:"%.2f") g · source stays unchanged").font(.system(size:10)).foregroundStyle(.secondary) }.padding(12).frame(height:125).background(.black.opacity(0.14),in:RoundedRectangle(cornerRadius:12))
        case "rhythm":
            VStack(spacing:12) { HStack { ForEach(0..<4) { i in Circle().fill(s.metronome && s.beats%4==i ? c.color:c.color.opacity(0.13)).frame(width:22,height:22) } };Text("METRONOME PREVIEW · user grouping").font(.system(size:9,design:.monospaced));Text("BPM is estimated on Watch. Gesture timestamps are not sent.").font(.system(size:10)).foregroundStyle(.secondary).multilineTextAlignment(.center) }.frame(maxWidth:.infinity).frame(height:125)
        case "battery":BatteryInstrument(level:sample?.values.first ?? 0,state:sample?.values.dropFirst().first).frame(height:125)
        case "location":VStack(spacing:4) {
            LocationInstrument(points:s.cardHistories[c.id]?.points(since:(s.frozenAt ?? Date()).timeIntervalSince1970-config.window) ?? [],color:c.color,window:config.window).frame(height:125)
            Text(s.samples["locationQuality"]?.values.first.map{$0>=0 ? String(format:"Fix accuracy ±%.0f m",$0):"Waiting for GPS fix · last position retained"} ?? "Waiting for location quality").font(.system(size:9)).foregroundStyle(.secondary)
            if let speed=s.samples[c.id]?.values.first,speed<0 {Text("Speed unavailable from GPS · not zero").font(.system(size:9)).foregroundStyle(.secondary)}
            if config.showCoordinates,let values=s.samples[c.id]?.values,values.count>=3 {Text(String(format:"%.5f, %.5f",values[1],values[2])).font(.system(size:10,design:.monospaced))}
        }
        default:sourcePlot
        }
    }
    private var sourcePlot:some View {
        let points=s.cardHistories[c.id]?.points(since:(s.frozenAt ?? Date()).timeIntervalSince1970-config.window) ?? []
        let vector=["acceleration","rotation"].contains(c.id)
        let series=(vector ? [0,1,2]:[tile.axis]).map { axis -> [PlotPoint] in
            var copy=tile;copy.axis=axis
            return points.map{PlotPoint(time:$0.time,value:s.measurement(copy,values:$0.values))}
        }
        let center:Double=c.id=="pressure" ? (config.reference ?? series.first?.first?.value ?? value):0
        let low:Double=["steps"].contains(c.id) ? 0:center-config.span/2
        let high:Double=["steps"].contains(c.id) ? config.span:center+config.span/2
        return TimePlot(series:series,colors:vector ? [.red,.green,.blue]:[c.color],lower:low,upper:high,window:config.window,unit:unit,now:(s.frozenAt ?? Date()).timeIntervalSince1970).frame(height:125)
    }
    @ViewBuilder private var sourceSettings:some View {
        switch c.id {
        case "orientation":VStack(alignment:.leading,spacing:5) {
            HStack {axisPicker(["Roll","Pitch","Yaw"]);unitsPicker(["Degrees","Radians"]);Spacer()}
            HStack {Button("Set neutral pose") {s.setNeutralPose()};Button("Reset neutral") {s.resetNeutralPose()};Spacer()}
        }.font(.system(size:10))
        case "acceleration","rotation":HStack { axisPicker(["X","Y","Z","Magnitude"]);if c.id=="rotation" {unitsPicker(["Degrees/s","Radians/s"])};Spacer();Text("R/G/B = X/Y/Z").foregroundStyle(.secondary) }.font(.system(size:9))
        case "gravity":HStack { modePicker(["Tilt","Axis"]);if config.mode=="Axis" { axisPicker(["X","Y","Z","Magnitude"]) };Spacer();Text("Physical pose · g arrow").foregroundStyle(.secondary) }.font(.system(size:9))
        case "steps":HStack { modePicker(["Count","Cadence"]);Spacer();Text(config.mode=="Cadence" ? "0 may mean cadence unavailable":"Cadence shown only with a fresh update").foregroundStyle(.secondary) }.font(.system(size:9))
        case "battery":Text("Watch charge · not battery health or remaining runtime").font(.system(size:9)).foregroundStyle(.secondary)
        case "touch":HStack {Text("Counter on the Watch Play pad").foregroundStyle(.secondary);Spacer();Button("Reset view") {s.setCardReference(tile.id)} }.font(.system(size:9))
        case "crown":HStack {modePicker(["Position","Delta"]);Spacer();Button("Set origin") {s.setCardReference(tile.id)}}.font(.system(size:9))
        case "stillness":HStack {Text("Window");Slider(value:setting(\.window),in:0.5...3);Text("\(config.window,specifier:"%.1f")s");Text("Tolerance");Slider(value:setting(\.tolerance),in:0.02...0.3)}.font(.system(size:9))
        case "altitude":HStack {unitsPicker(["Meters","Feet"]);Spacer();Button("Set reference") {s.setCardReference(tile.id)}}.font(.system(size:9))
        case "pressure":HStack {unitsPicker(["kPa","hPa"]);Spacer();Button("Set reference") {s.setCardReference(tile.id)}}.font(.system(size:9))
        case "heading":HStack {Text(s.samples["headingQuality"]?.values.first.map{ $0<0 ? "Unreliable heading":String(format:"Magnetic · ±%.0f°",$0) } ?? "Magnetic · accuracy unavailable").foregroundStyle(.secondary);Spacer();Button("Set direction") {s.setCardReference(tile.id)}}.font(.system(size:9))
        case "location":HStack {unitsPicker(["m/s","km/h","mph"]);windowPicker;Spacer();Toggle("Coordinates",isOn:setting(\.showCoordinates)).toggleStyle(.checkbox)}.font(.system(size:9))
        case "rhythm":Text("Detector settings are fixed on Watch; this card adjusts the response only.").font(.system(size:9)).foregroundStyle(.secondary)
        default:Text("Measured source above · response below").font(.system(size:9)).foregroundStyle(.secondary)
        }
    }
    private var plotControls:some View {
        HStack {Text("View span");TextField("Plot span",value:setting(\.span),format:.number).frame(width:48).textFieldStyle(.roundedBorder);Text(unit);Spacer();windowPicker}.font(.system(size:9))
    }
    private var windowPicker:some View {Picker("Time window",selection:setting(\.window)){Text("10s").tag(10.0);Text("30s").tag(30.0);Text("60s").tag(60.0);Text("5m").tag(300.0)}.labelsHidden().frame(width:63)}
    private func modePicker(_ choices:[String])->some View {Picker("Source mode",selection:Binding(get:{config.mode},set:{var p=config;p.changeMode(for:c.id,to:$0);tile.settings=p;s.resetCardResponse(tile.id)})){ForEach(choices,id:\.self){Text($0)}}.labelsHidden().frame(maxWidth:100)}
    private func unitsPicker(_ choices:[String])->some View {Picker("Units",selection:Binding(get:{config.units=="Default" ? (choices.first ?? "Default"):config.units},set:{var p=config;p.convertUnits(for:c.id,to:$0);tile.settings=p})){ForEach(choices,id:\.self){Text($0)}}.labelsHidden().frame(width:95)}
    private func axisPicker(_ labels:[String])->some View {Picker("Component",selection:$tile.axis){ForEach(Array(labels.enumerated()),id:\.offset){i,name in Text(name).tag(i)}}.labelsHidden().frame(width:90)}
    private func setting<T>(_ key:WritableKeyPath<CardSettings,T>)->Binding<T> {Binding(get:{config[keyPath:key]},set:{var p=config;p[keyPath:key]=$0;tile.settings=p})}
    private var savedRecord:some View {
        VStack(alignment:.leading,spacing:14) {
            HStack(alignment:.firstTextBaseline) {Text(config.hideValue ? "Hidden":sample.map{_ in formatted(value)} ?? "—").font(.system(size:36,weight:.medium,design:.rounded)).monospacedDigit();Text(unit).foregroundStyle(.secondary);Spacer();Image(systemName:"calendar").foregroundStyle(c.color)}
            Text(sample.map{"Recorded "+$0.date.formatted(date:.abbreviated,time:.shortened)} ?? "No authorized matching record").font(.caption)
            Text(c.id=="hrv" ? "SDNN · one saved record, not a live stress signal":"One saved record · no live biological waveform").font(.system(size:10)).foregroundStyle(.secondary)
            HStack {Toggle("Hide value",isOn:setting(\.hideValue)).toggleStyle(.checkbox);if c.id=="temperature" { unitsPicker(["°C","°F"]) }}.font(.caption2)
            Text("Read saved Health data from the Watch Feeds screen to refresh.").font(.system(size:10)).foregroundStyle(.secondary)
        }
    }
    private var reference:some View {
        VStack(alignment:.leading,spacing:12) {
            HStack {Image(systemName:c.access=="Restricted" ? "lock":"info.circle").font(.title2);Text(c.id=="action" ? "Not on Series 10":c.id=="doubletap" ? "Shares the Touch action":c.access=="Restricted" ? "Not accessible in this app":"Integration not implemented").font(.system(size:14,weight:.medium))}.foregroundStyle(c.color)
            Text(c.id=="doubletap" ? "The system shortcut and a pad tap increment the same counter. Their origins are not separately reported.":"This is a capability reference, not an inactive sensor. It has no live signal or sensitivity settings.").font(.system(size:11)).foregroundStyle(.secondary)
            if c.id=="doubletap" {Button("Add Touch card") {if let touch=catalog.first(where:{$0.id=="touch"}){s.add(touch)}}.font(.caption)}
        }.padding(.vertical,8)
    }
}
