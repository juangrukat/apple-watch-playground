import SwiftUI
import AppKit

@main struct PlaygroundApp: App {
    @StateObject var studio = Studio()
    init() {
        if ProcessInfo.processInfo.arguments.contains("--self-test") {
            let model=Studio(startNetworking:false)
            model.setDemo(false)
            model.tiles=[Tile(capability:"acceleration",x:20,y:20,gain:2,smoothing:0,deadzone:0.1,inverted:true)]
            model.ingest("acceleration",[0.4,0,0]); model.tick()
            precondition(abs(model.transformed(model.tiles[0])+0.8)<0.0001,"Sensitivity/invert")
            model.tiles[0].bias=0.4; model.tick()
            precondition(model.transformed(model.tiles[0])==0,"Zero baseline")
            model.ingest("acceleration",[.nan]); precondition(model.sample("acceleration")!.values[0]==0.4,"Reject invalid values")
            model.samples["acceleration"]=Sample(values:[1],date:Date(timeIntervalSinceNow:-10))
            precondition(model.sample("acceleration")==nil,"Stale stream hidden")
            model.ingest("heart",[70],source:Date(timeIntervalSinceNow:-3600))
            precondition(model.sample("heart")?.sourceDate != nil,"Historical timestamp preserved")
            model.tiles=[Tile(capability:"orientation",x:28,y:28),Tile(capability:"rotation",x:600,y:600)]
            model.move(model.tiles[1].id,x:390,y:30)
            precondition(model.tiles[1].x==380 && model.tiles[1].y==28,"Edge snapping")
            model.setDemo(true); model.tick()
            precondition(model.sample("orientation") != nil && model.sample("heart")==nil,"Demo separates health data")
            let data=try! JSONEncoder().encode(Workspace(name:"Test",tiles:model.tiles))
            precondition((try! JSONDecoder().decode(Workspace.self,from:data)).tiles.count==2,"Workspace round trip")
            print("PASS: sensitivity, inversion, baseline, invalid data, stale streams, historical timestamps, snapping, demo isolation, workspace serialization")
            exit(0)
        }
        NSApplication.shared.setActivationPolicy(.regular)
    }
    var body: some Scene {
        WindowGroup("Watch Playground") { ContentView().environmentObject(studio).preferredColorScheme(.dark).frame(minWidth:1100,minHeight:740).onAppear { NSApp.activate(ignoringOtherApps:true) } }
            .defaultSize(width:1440,height:980)
            .commands { CommandGroup(replacing:.newItem) { Button("Save workspace") { studio.save() }.keyboardShortcut("s"); Button("Arrange palettes") { studio.backupAndArrange() }.keyboardShortcut("0") } }
    }
}
let ink = Color(red:0.045,green:0.055,blue:0.075)
let panel = Color(red:0.085,green:0.10,blue:0.125)

struct ContentView: View {
    @EnvironmentObject var s:Studio
    @State private var search=""
    @State private var selectedFamily="All"
    @State private var showConnect=false
    @State private var showHelp=false
    @State private var showPresets=false
    var families:[String] { ["All","Movement","Interaction","Sound","Feedback","Environment","Body","Connections","Restricted"] }
    var filtered:[Capability] { catalog.filter { (selectedFamily=="All" || $0.family==selectedFamily) && (search.isEmpty || "\($0.name) \($0.explanation)".localizedCaseInsensitiveContains(search)) } }
    var body: some View {
        HStack(spacing:0) {
            VStack(alignment:.leading,spacing:18) {
                HStack { Image(systemName:"applewatch.radiowaves.left.and.right").font(.title).foregroundStyle(.mint); VStack(alignment:.leading) { Text("WATCH").font(.system(size:11,weight:.bold,design:.monospaced)).tracking(4); Text("Playground").font(.title2.bold()) } }
                Text("A studio for things your wrist can do.").font(.subheadline).foregroundStyle(.secondary)
                TextField("Find a capability…",text:$search).textFieldStyle(.roundedBorder)
                Picker("Family",selection:$selectedFamily) { ForEach(families,id:\.self) { Text($0) } }.labelsHidden()
                HStack { Text("CAPABILITY LIBRARY").font(.system(size:10,weight:.bold,design:.monospaced)).tracking(2); Spacer(); Text("\(catalog.count)").foregroundStyle(.mint) }.foregroundStyle(.secondary)
                ScrollView {
                    LazyVStack(spacing:6) {
                        ForEach(filtered) { c in
                            Button { s.add(c) } label: {
                                HStack(spacing:10) {
                                    Image(systemName:c.icon).font(.system(size:16)).foregroundStyle(c.color).frame(width:25)
                                    VStack(alignment:.leading,spacing:3) { Text(c.name).font(.system(size:12,weight:.medium)).foregroundStyle(.white); Text(s.capabilityState(c)).font(.system(size:10)).foregroundStyle(.secondary) }
                                    Spacer(); Image(systemName:"plus").font(.caption).foregroundStyle(.secondary)
                                }.padding(10).background(.white.opacity(0.035),in:RoundedRectangle(cornerRadius:10))
                            }.buttonStyle(.plain).help("Add \(c.name) palette")
                        }
                    }
                }
                Button { showHelp=true } label: { Label("How to play",systemImage:"questionmark.circle") }.buttonStyle(.plain).foregroundStyle(.mint)
                Text("Local by design. No cloud.\nHealth and location are opt-in.").font(.system(size:10)).foregroundStyle(.secondary)
            }.padding(20).frame(width:240).background(panel)
            Rectangle().fill(.white.opacity(0.07)).frame(width:1)
            VStack(spacing:0) {
                header
                HStack(spacing:12) {
                    Circle().fill(s.demo ? .orange : s.connected ? .mint:.gray).frame(width:7,height:7)
                    Text(s.message).font(.system(size:11)).foregroundStyle(.secondary)
                    if s.bluetoothMode {
                        Picker("Controller rate",selection:$s.controllerRate) { ForEach([25,50,75,100],id:\.self) { Text("\($0) Hz target").tag($0) } }.labelsHidden().frame(width:115).onChange(of:s.controllerRate) { _,_ in s.applyControllerRate() }
                        Text(String(format:"%.0f Hz",s.bluetoothRate)+" · "+s.bluetoothRTT).font(.system(size:10,design:.monospaced)).foregroundStyle(.mint) }
                    if !s.bluetoothMode && !s.usbBridge && s.connected { Text(String(format:"%.0f Hz received",s.httpRate)).font(.system(size:10,design:.monospaced)).foregroundStyle(.mint) }
                    if !s.streamAge.isEmpty { Text(s.streamAge).font(.caption).foregroundStyle(.orange) }
                    Spacer()
                    Text(s.demo ? "SIMULATED" : s.bluetoothMode ? "DIRECT BLE":s.usbBridge ? "USB WATCH":"WATCH INPUT").font(.system(size:10,weight:.bold,design:.monospaced)).tracking(1).foregroundStyle(s.demo ? .orange:.mint)
                }.padding(.horizontal,24).padding(.vertical,10).background(.white.opacity(0.025))
                ScrollView([.horizontal,.vertical]) {
                    ZStack(alignment:.topLeading) {
                        Canvas { ctx,size in
                            for x in stride(from:12.0,to:Double(size.width),by:24) {
                                for y in stride(from:12.0,to:Double(size.height),by:24) { ctx.fill(Path(ellipseIn:CGRect(x:x,y:y,width:1.5,height:1.5)),with:.color(.white.opacity(0.10))) }
                            }
                        }.allowsHitTesting(false)
                        if s.tiles.isEmpty {
                            VStack(spacing:14) { Image(systemName:"square.stack.3d.up").font(.system(size:48)).foregroundStyle(.mint); Text("Start with a little curiosity.").font(.title); Text("Add a capability from the library, or choose a workspace above.").foregroundStyle(.secondary) }.frame(width:850,height:600)
                        }
                        ForEach($s.tiles) { $tile in Palette(tile:$tile,clock:s.feedClock).environmentObject(s).offset(x:tile.x,y:tile.y).zIndex(s.activeCardID==tile.id ? 1000:0) }
                    }.background(CanvasNavigator(request:s.canvasJump).allowsHitTesting(false)).frame(width:max(1000,(s.tiles.map{$0.x+$0.width+400}.max() ?? 1200)),height:max(800,(s.tiles.map{$0.y+$0.height+400}.max() ?? 1000)),alignment:.topLeading)
                }.background(ink).coordinateSpace(name:"CardCanvas")
                HStack { Text(s.note.isEmpty ? "Drag the grip or title · Option skips snapping · Presets add removable groups" : s.note).font(.system(size:11)).foregroundStyle(.secondary); Spacer(); Text("\(s.tiles.count) palettes").font(.caption.monospaced()) }.padding(12).background(panel)
            }
        }.background(ink)
        .overlay(alignment:.bottomTrailing) { RenderHeartbeat(clock:s.feedClock,studio:s).allowsHitTesting(false) }
        .sheet(isPresented:$showConnect) { connectionSheet }
        .sheet(isPresented:$showHelp) { helpSheet }
        .sheet(isPresented:$showPresets) { PresetLibrary().environmentObject(s) }
    }
    var header:some View {
        HStack(spacing:14) {
            VStack(alignment:.leading,spacing:4) {
                Text("YOUR EXPERIMENT SPACE").font(.system(size:9,weight:.semibold,design:.monospaced)).tracking(2).foregroundStyle(.mint)
                TextField("Workspace name",text:$s.workspaceName).textFieldStyle(.plain).font(.system(size:23,weight:.semibold)) .frame(width:230)
            }
            Menu { ForEach(CardKit.builtins.map(\.name),id:\.self) { name in Button("Replace with "+name) { s.preset(name) } }; Divider(); ForEach(s.savedNames,id:\.self) { name in Button("Saved: \(name)") { s.load(name) } } } label: { Image(systemName:"square.grid.2x2") }.help("Choose a workspace")
            Button { showPresets=true } label:{Label("Presets",systemImage:"square.stack.3d.up")}.help("Add or remove preset groups")
            Button { s.save() } label: { Image(systemName:"square.and.arrow.down") }.help("Save workspace")
            Button { s.backupAndArrange() } label: { Image(systemName:"rectangle.3.group") }.help("Arrange palettes")
            Toggle("Snap",isOn:$s.snap).toggleStyle(.checkbox).font(.caption)
            Spacer(minLength:0)
            Button { s.paused.toggle() } label: { Image(systemName:s.paused ? "play.fill":"pause.fill") }.help("Freeze feeds")
            Button { if s.recording { s.exportRecording() } else { s.startRecording() } } label: { Label(s.recording ? "Stop & export":"Record",systemImage:s.recording ? "stop.circle.fill":"record.circle") }.foregroundStyle(s.recording ? .red:.white)
            Button { showConnect=true } label: { Label("Connect Watch",systemImage:"applewatch") }.buttonStyle(.plain).padding(.horizontal,12).padding(.vertical,9).background(Color.mint,in:RoundedRectangle(cornerRadius:8)).foregroundStyle(.black)
        }.buttonStyle(.borderless).padding(22).background(panel)
    }
    var connectionSheet:some View {
        VStack(alignment:.leading,spacing:20) {
            HStack { Text("Bring your wrist into the studio.").font(.title2.bold()); Spacer(); Button("Done") { showConnect=false } }
            Text("1. Install and open the included Watch companion.\n2. Put Watch and Mac on the same trusted Wi-Fi.\n3. Enter this Mac address and pairing code, then tap Connect.").lineSpacing(8).foregroundStyle(.secondary)
            HStack(spacing:30) { VStack(alignment:.leading) { Text("MAC ADDRESS").font(.caption.monospaced()); Text(s.macAddress).font(.title2.monospaced()).textSelection(.enabled) }; VStack(alignment:.leading) { Text("PAIRING CODE").font(.caption.monospaced()); Text(s.pairingCode).font(.title2.monospaced()).foregroundStyle(.mint).textSelection(.enabled) } }
            Text("Port 8765 • local HTTP with pairing code. Transport is not encrypted; use a trusted private network. Health and location stay off until enabled on the Watch.").font(.caption).foregroundStyle(.secondary)
            Divider()
            Button(s.bluetoothMode ? "Stop direct Bluetooth":"Use direct Bluetooth") { if s.bluetoothMode { s.stopBluetooth() } else { s.startBluetooth(); showConnect=false } }.buttonStyle(.borderedProminent).tint(.mint).foregroundStyle(.black)
            Text("Fast direct Watch-to-Mac link. After starting it here, enter this Mac's code on the Watch and choose Direct Bluetooth. Keep the Watch app active. No iPhone or router in the data path.").font(.caption).foregroundStyle(.secondary)
            Toggle("Explore with simulated feeds",isOn:Binding(get:{s.demo},set:{s.setDemo($0)}))
            Text("Demo lets you explore layouts and sensitivity before pairing. Simulated readings are never labeled as live Watch data.").font(.caption).foregroundStyle(.secondary)
            Text("Watch installation requires full Xcode, a signing team and Developer Mode on the Watch. See the included README for exact steps.").font(.caption).foregroundStyle(.secondary)
        }.padding(30).frame(width:580)
    }
    var helpSheet:some View {
        VStack(alignment:.leading,spacing:18) {
            Text("Follow the feed. Find an idea.").font(.largeTitle.bold())
            Text("Add palettes from the library. Drag their headers to arrange them; nearby edges snap into place. Expand a palette for more space. Save a named workspace to come back later.")
            Text("Source values keep their physical units. Enable Creative response to map an input range to 0–1, choose a time-based smoothing setting, and route it. Plots show a labeled source scale and real time window.")
            Text("Use Presets to add or remove card groups. Save your current setup as a custom preset; removed presets can be restored. Drag a card title or grip; Option bypasses snapping, and arrow keys move a focused drag handle.")
            Text("Conductor previews the BPM estimate sent by the Watch. Detection settings and peak timestamps are not configurable through the current protocol. The generated beat preview is separate from measured gestures. Music-file time stretching is not included.")
            Text("Grey and reference palettes explain the rest of the hardware map. A feature listed here is not a claim that your model exposes it. Freshness and permission states matter, especially for health records.").foregroundStyle(.secondary)
            Button("Let's play") { showHelp=false }.buttonStyle(.borderedProminent).tint(.mint)
        }.padding(32).frame(width:620)
    }
}
