import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

// Invisible strip at the screen edge that reveals an auto-hidden dock.
// `dock` is the DockPanelBase controller.
PanelWindow {
  id: edgeHotZone
  required property var modelData
  required property var dock
  visible: !dock.conflictDetected && dock.enabled && dock.autoHide && dock.dockReady && !dock.remapping
  screen: modelData
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.namespace: "macos-dock-edge"
  // Full-screen surface on every side; input is limited to the mask below,
  // exactly like dockWindow, so the hot-zone can never balloon into a
  // full-screen input grab (the previous conditional-undefined anchors did).
  anchors.top: true
  anchors.bottom: true
  anchors.left: true
  anchors.right: true
  mask: Region { item: edgeMouse }

  Item {
    id: edgeMouse
    x: dock.dockSide === "bottom" ? 0 : (dock.dockSide === "left" ? 0 : parent.width - dock.edgeHeight)
    y: dock.dockSide === "bottom" ? parent.height - dock.edgeHeight : 0
    width: dock.dockSide === "bottom" ? parent.width : dock.edgeHeight
    height: dock.dockSide === "bottom" ? dock.edgeHeight : parent.height
    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onEntered: dock.edgeEnter(modelData.name)
      // Leaving while the dock is hidden cancels the pending reveal; leaving
      // while it is visible arms the hide via onEdgeHoveredChanged.
      onExited: dock.edgeExit()
    }
  }
}
