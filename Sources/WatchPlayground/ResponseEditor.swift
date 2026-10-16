import SwiftUI

struct ResponseEditor:View {
    @EnvironmentObject var s:Studio
    @Binding var tile:Tile
    private var config:CardSettings {tile.settings ?? .defaults(tile.capability)}
    private var isEvent:Bool {tile.capability=="touch" || (tile.capability=="steps" && config.mode=="Count")}
    var body:some View {
        VStack(alignment:.leading,spacing:8) {
            HStack {Text("RESPONSE · 0 TO 1").font(.system(size:9,weight:.semibold,design:.monospaced));Spacer();Text(s.transformed(tile),format:.number.precision(.fractionLength(2))).monospacedDigit();Menu("Presets") {Button("Default response") {var c=CardSettings.defaults(tile.capability);c.response=true;tile.settings=c};Button("Immediate") {var c=config;c.smoothingMS=0;c.cooldownMS=100;tile.settings=c};Button("Gentle") {var c=config;c.smoothingMS=200;c.curve="Gentle";tile.settings=c}}.font(.system(size:9))}
            LevelInstrument(value:s.transformed(tile),color:.mint).frame(height:7)
            if isEvent {
                HStack {Picker("Event action",selection:setting(\.eventMode)){Text("Pulse").tag("Pulse");Text("Toggle").tag("Toggle")}.labelsHidden();Stepper("Every \(config.every)",value:setting(\.every),in:1...20)}.font(.system(size:10))
                HStack {Text("Pulse");Slider(value:setting(\.pulseMS),in:20...1000);Text("\(Int(config.pulseMS))ms")}.font(.system(size:9))
            } else {
                HStack {Text("Input");TextField("Low",value:setting(\.lower),format:.number).frame(width:52);Text("→");TextField("High",value:setting(\.upper),format:.number).frame(width:52);Text(s.measurementUnit(tile)).foregroundStyle(.secondary);Spacer()}.font(.system(size:10)).textFieldStyle(.roundedBorder)
                HStack {Button("Learn low") {var c=config;c.lower=s.measurement(tile)-(c.reference ?? 0);tile.settings=c};Button("Learn high") {var c=config;c.upper=s.measurement(tile)-(c.reference ?? 0);tile.settings=c};Toggle("Invert response",isOn:$tile.inverted).toggleStyle(.checkbox)}.font(.system(size:9))
                HStack {Text("Smooth");Slider(value:setting(\.smoothingMS),in:0...1000);Text("\(Int(config.smoothingMS))ms");Picker("Curve",selection:setting(\.curve)){ForEach(["Linear","Gentle","Fast"],id:\.self){Text($0)}}.labelsHidden().frame(width:80)}.font(.system(size:9))
                if config.upper<=config.lower {Text("High must be greater than low.").font(.caption2).foregroundStyle(.orange)}
            }
            if !isEvent,["orientation","acceleration","rotation","gravity","crown","heading"].contains(tile.capability) {
                HStack {Text("Neutral band ±");TextField("Neutral band",value:setting(\.deadband),format:.number).frame(width:48);Text(s.measurementUnit(tile));Spacer();Button("Set reference") {s.setCardReference(tile.id)}}.font(.system(size:9)).textFieldStyle(.roundedBorder)
            }
            HStack {
                Picker("Route",selection:Binding(get:{tile.output},set:{s.chooseRoute(tile.id,$0)})) {Text("Visual only").tag("Visual");Text("Tempo").tag("Tempo");Text("Mac sound trigger").tag("Sound trigger");Text("Watch notification").tag("Watch click")}.labelsHidden()
                if tile.output=="Tempo" {TextField("BPM low",value:setting(\.outLow),format:.number).frame(width:42);Text("→");TextField("BPM high",value:setting(\.outHigh),format:.number).frame(width:42)}
            }.font(.system(size:10)).textFieldStyle(.roundedBorder)
            if ["Sound trigger","Watch click"].contains(tile.output) {
                HStack {if !isEvent {Text(tile.capability=="battery" ? "Below":"Above");TextField("Threshold",value:setting(\.threshold),format:.number).frame(width:45)};Text("Cooldown");Slider(value:setting(\.cooldownMS),in:0...1500);Text("\(Int(config.cooldownMS))ms")}.font(.system(size:9))
            }
        }.padding(10).background(.white.opacity(0.035),in:RoundedRectangle(cornerRadius:10))
    }
    private func setting<T>(_ key:WritableKeyPath<CardSettings,T>)->Binding<T> {Binding(get:{config[keyPath:key]},set:{var p=config;p[keyPath:key]=$0;tile.settings=p})}
}
