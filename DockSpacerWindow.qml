import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

// Reserves the dock footprint as a Wayland exclusive zone so tiled windows
// never overlap the dock (auto-hide off). `dock` is the DockPanelBase controller.
PanelWindow {
  id: dockSpacerWindow
  required property var modelData
  required property var dock
  visible: !dock.conflictDetected && dock.enabled && !dock.autoHide && !dock.remapping
  screen: modelData
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Background
  WlrLayershell.namespace: "macos-dock-spacer"
  WlrLayershell.exclusiveZone: dock.autoHide ? 0 : (dock.enabled ? dock.dockHeight + dock.bottomMargin : 0)
  // The exclusive zone is edge-anchored so tiled windows avoid the dock
  // footprint on whichever side the dock currently lives. Anchors are
  // assigned plain booleans (never undefined), so each side commits a
  // complete, non-conflicting anchor set that reliably detaches the
  // previous one. PanelWindow has no state machine, so no states here.
  anchors.top: dock.dockSide !== "bottom"
  anchors.bottom: true
  anchors.left: dock.dockSide !== "right"
  anchors.right: dock.dockSide === "right"
  implicitWidth: dock.dockSide === "bottom" ? 0 : dock.dockHeight + dock.bottomMargin
  implicitHeight: dock.dockSide === "bottom" ? dock.dockHeight + dock.bottomMargin : 0
  mask: Region {}
}
