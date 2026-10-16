import SwiftUI
import AppKit

struct CanvasNavigator:NSViewRepresentable {
    let request:CanvasJump?
    final class Marker:NSView {var last:UUID?}
    func makeNSView(context:Context)->Marker {Marker()}
    func updateNSView(_ view:Marker,context:Context) {
        guard let request,request.id != view.last else{return}
        DispatchQueue.main.async {
            guard let scroll=view.enclosingScrollView,let document=scroll.documentView else{return}
            view.last=request.id
            let clip=scroll.contentView
            let x=max(0,min(max(0,document.bounds.width-clip.bounds.width),request.point.x-16))
            let y=max(0,min(max(0,document.bounds.height-clip.bounds.height),request.point.y-16))
            clip.scroll(to:CGPoint(x:x,y:document.isFlipped ? y:max(0,document.bounds.height-clip.bounds.height-y)));scroll.reflectScrolledClipView(clip)
        }
    }
}
