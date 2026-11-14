import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

// The dragged icon: an overlay window that follows the cursor anywhere on the
// screen without clipping against the dock mask. Its input region is only the
// anchor, so it never blocks clicks. `dock` is the DockPanelBase controller.
PanelWindow {
  id: dragGhostWindow
  required property var dock
  visible: dock.ghostSource !== ""
  // The ghost follows the cursor on the output the drag started on (set by
  // the dock surface that received it), never on a fixed screen.
  screen: dock.activeScreen
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "macos-dock-drag"
  anchors { top: true; bottom: true; left: true; right: true }
  mask: Region { item: ghostAnchor }

  Item {
    id: ghostAnchor
    x: dock.ghostX
    y: dock.ghostY
    width: dock.iconSize * dock.ghostScale + 16
    height: dock.iconSize * dock.ghostScale + 16
    opacity: dock.ghostOpacity
    Behavior on opacity { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }

    Rectangle {
      anchors.centerIn: parent
      width: parent.width - 4
      height: parent.height - 4
      radius: dock.iconSize * 0.26
      color: Util.alpha(Color.background, 0.55)
      border.color: Util.alpha(Color.foreground, 0.18)
      border.width: 1
    }

    Image {
      anchors.centerIn: parent
      width: dock.iconSize * dock.ghostScale
      height: dock.iconSize * dock.ghostScale
      source: dock.ghostSource
      sourceSize: Qt.size(dock.iconSize * 2, dock.iconSize * 2)
      asynchronous: true
    }
  }
}
