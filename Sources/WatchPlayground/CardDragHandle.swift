import SwiftUI
import AppKit

struct CardDragHandle:NSViewRepresentable {
    let title:String
    let begin:()->Void
    let change:(CGSize)->Void
    let end:(CGSize,Bool)->Void
    func makeNSView(context:Context)->DragArea { let view=DragArea();updateNSView(view,context:context);return view }
    func updateNSView(_ view:DragArea,context:Context) {
        view.begin=begin;view.change=change;view.end=end
        view.setAccessibilityElement(true);view.setAccessibilityRole(.button);view.setAccessibilityLabel("Move "+title+" card")
        view.setAccessibilityHelp("Drag to move. Option bypasses snapping. Arrow keys move; Shift moves faster.")
    }
    final class DragArea:NSView {
        var begin:(()->Void)?,change:((CGSize)->Void)?,end:((CGSize,Bool)->Void)?
        private var origin=NSPoint.zero
        override var acceptsFirstResponder:Bool { true }
        override func resetCursorRects() { addCursorRect(bounds,cursor:.openHand) }
        override func mouseDown(with event:NSEvent) { window?.makeFirstResponder(self);origin=event.locationInWindow;begin?();NSCursor.closedHand.push() }
        override func mouseDragged(with event:NSEvent) { change?(CGSize(width:event.locationInWindow.x-origin.x,height:origin.y-event.locationInWindow.y)) }
        override func mouseUp(with event:NSEvent) {
            end?(CGSize(width:event.locationInWindow.x-origin.x,height:origin.y-event.locationInWindow.y),event.modifierFlags.contains(.option));NSCursor.pop()
        }
        override func keyDown(with event:NSEvent) {
            let amount:CGFloat=event.modifierFlags.contains(.shift) ? 24:4
            let moves:[UInt16:CGSize]=[123:CGSize(width:-amount,height:0),124:CGSize(width:amount,height:0),125:CGSize(width:0,height:amount),126:CGSize(width:0,height:-amount)]
            if let delta=moves[event.keyCode] { begin?();end?(delta,true) } else { super.keyDown(with:event) }
        }
    }
}
