import SwiftUI

struct PresetLibrary:View {
    @EnvironmentObject var s:Studio
    @Environment(\.dismiss) private var dismiss
    @State private var name=""
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            HStack {VStack(alignment:.leading,spacing:5){Text("Preset library").font(.title2.bold());Text("Add a card group. Remove it without removing your other cards.").font(.caption).foregroundStyle(.secondary)};Spacer();Button("Done") {dismiss()}}
            ScrollView {
                VStack(alignment:.leading,spacing:12) {
                    Text("READY TO EXPLORE").font(.system(size:10,weight:.bold,design:.monospaced)).foregroundStyle(.mint)
                    ForEach(CardKit.builtins) { kit in
                        HStack(spacing:14) {
                            VStack(alignment:.leading,spacing:4){Text(kit.name).font(.headline);Text(kit.detail).font(.caption).foregroundStyle(.secondary);Text("\(kit.capabilities.count) cards").font(.caption2).foregroundStyle(.secondary)}
                            Spacer()
                            if s.tiles.contains(where:{$0.presetID==kit.id}) {Button("Show cards") {if let first=s.tiles.first(where:{$0.presetID==kit.id}) {s.focusCard(first.id);dismiss()}};Button("Remove group") {s.removeGroup(kit.id)}.accessibilityLabel("Remove \(kit.name) preset group")}
                            else {Button("Add cards") {s.addKit(kit)}.accessibilityLabel("Add \(kit.name) preset")}
                        }.padding(12).background(.white.opacity(0.04),in:RoundedRectangle(cornerRadius:12))
                    }
                    Divider().padding(.vertical,6)
                    Text("YOUR PRESETS").font(.system(size:10,weight:.bold,design:.monospaced)).foregroundStyle(.mint)
                    HStack {TextField("Preset name",text:$name).textFieldStyle(.roundedBorder);Button("Save current setup") {let previous=s.workspaceName;s.workspaceName=name.trimmingCharacters(in:.whitespacesAndNewlines);s.save();s.workspaceName=previous;s.persist()}.disabled(name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)}
                    Text("Saves card types, response settings and layout. Sensor readings and permissions are not stored in a preset.").font(.caption2).foregroundStyle(.secondary)
                    ForEach(s.savedNames,id:\.self) { item in
                        HStack {Text(item).lineLimit(1);Spacer();if s.tiles.contains(where:{$0.presetID=="saved:"+item}) {Button("Remove group") {s.removeGroup("saved:"+item)}}else{Button("Add cards") {s.addSavedPreset(item)}};Button("Remove preset") {s.removeSavedPreset(item)}}.font(.caption).padding(.vertical,5)
                    }
                    if !s.archivedPresetNames.isEmpty {
                        Divider();Text("REMOVED PRESETS · RECOVERABLE").font(.system(size:10,weight:.bold,design:.monospaced)).foregroundStyle(.secondary)
                        ForEach(s.archivedPresetNames,id:\.self) { item in HStack {Text(item).font(.caption);Spacer();Button("Restore") {s.restoreSavedPreset(item)}} }
                    }
                }
            }
        }.padding(24).frame(width:680,height:640).onAppear{name=s.workspaceName}
    }
}
