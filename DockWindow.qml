import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import "DockModel.js" as DockModel

// The dock pill, its icon row and its tooltip on one output. `dock` is the
// DockPanelBase controller that owns layout, drag and hover state.
PanelWindow {
  id: dockWindow
  required property var modelData
  required property var dock
  // The Repeater below shadows `modelData` with the dock item id, so the
  // output name is captured once here for the handlers nested inside it.
  readonly property string outputName: modelData.name
  visible: !dock.conflictDetected && dock.enabled && !dock.remapping
  screen: modelData
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.namespace: "macos-dock"
  anchors { top: true; bottom: true; left: true; right: true }
  // Anchored to all four edges on purpose: drag-to-reorder and the hover
  // magnify effect both need pointer coordinates across the whole screen,
  // not just the dock's own footprint. `mask` narrows hit-testing to
  // `dockSurface`, but Hyprland's `layer_rule blur` operates on the full
  // layer geometry regardless of the mask — a `blur = true` rule on this
  // namespace was measured blurring the ENTIRE monitor behind it, not just
  // the small visible pill, on any host with Hyprland blur enabled. The
  // 0.50 alpha tint below is deliberately the only "glass" effect; no
  // compositor backdrop blur is requested for this namespace.
  mask: Region { item: hitArea }

  // Input region: the pill plus the headroom magnified icons grow into,
  // so an enlarged icon keeps receiving the pointer (no flicker at its
  // top edge). The headroom is 0 while auto-hidden.
  Item {
    id: hitArea
    x: dockSurface.x - ((dock.vertical && dock.dockSide === "right") ? dock.magnifyHeadroom : 0)
    y: dockSurface.y - (!dock.vertical ? dock.magnifyHeadroom : 0)
    width: dockSurface.width + (dock.vertical ? dock.magnifyHeadroom : 0)
    height: dockSurface.height + (!dock.vertical ? dock.magnifyHeadroom : 0)
  }

  // Publish this output's dock row: cursorXInRow() needs the row belonging to
  // the screen the hover came from, and only the delegate can reach its own.
  Component.onCompleted: dock.registerRow(modelData.name, dockRow)
  Component.onDestruction: dock.unregisterRow(modelData.name)

  Rectangle {
    id: dockSurface
    x: dock.surfaceForScreen(modelData).x
    y: dock.surfaceForScreen(modelData).y
    width: dock.surfaceWidth
    height: dock.surfaceHeight
    radius: 18
    color: Util.alpha(Color.background, 0.50)
    border.color: Util.alpha(Color.foreground, 0.04)
    border.width: 1
    opacity: !dock.enabled ? 0 : (dock.menuOpen || dock.pickerOpen || dock.dockHovered ? 1 : 0.96)

    // Top edge now matches the other three sides via the 1px border
    // (0.04) alone — no extra highlight, so the dock reads as a uniform
    // glass pill instead of a brighter top. Removed the previous 0.10 bar
    // that made the top brighter than left/right/bottom.

    // The axis along the row is driven directly by the magnification so
    // the pill always hugs the icons; it only glides on structural
    // changes. The cross axis carries the auto-hide slide.
    Behavior on x {
      enabled: dock.vertical || dock.layoutTransition
      NumberAnimation { duration: Style.duration(dock.vertical ? (dock.autoHidden ? dock.hideDuration : dock.showDuration) : 250); easing.type: Easing.OutCubic }
    }
    Behavior on y {
      enabled: !dock.vertical || dock.layoutTransition
      NumberAnimation { duration: Style.duration(!dock.vertical ? (dock.autoHidden ? dock.hideDuration : dock.showDuration) : 250); easing.type: Easing.OutCubic }
    }
    Behavior on width {
      enabled: dock.layoutTransition
      NumberAnimation { duration: Style.duration(250); easing.type: Easing.OutCubic }
    }
    Behavior on height {
      enabled: dock.layoutTransition
      NumberAnimation { duration: Style.duration(250); easing.type: Easing.OutCubic }
    }
    Behavior on opacity { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }

    Item {
      id: dockRow
      anchors.centerIn: parent
      anchors.verticalCenterOffset: 0
      // Fixed to the resting row: the pointer frame never changes while
      // icons magnify. The pill grows around it symmetrically.
      width: dock.restRowWidth
      height: dock.itemHeight
      // Left/right docks reuse the horizontal layout engine: the row is
      // rotated +90° so the x-axis becomes screen-y (first item on top) and
      // each wrapper counter-rotates -90° to keep icons upright.
      rotation: dock.vertical ? 90 : 0

      Behavior on width {
        enabled: dock.layoutTransition
        NumberAnimation { duration: Style.duration(250); easing.type: Easing.OutCubic }
      }
      Behavior on rotation {
        NumberAnimation { duration: Style.duration(250); easing.type: Easing.OutCubic }
      }

      Repeater {
        model: dock.dockItems
        delegate: DockSlot {
          dock: dockWindow.dock
          surface: dockSurface
          outputName: dockWindow.outputName
        }
      }

      // Fixed separator, repeated per output so every dock gets it.
      Repeater {
        model: dock.showSeparator ? 1 : 0
        delegate: DockSeparator {
          dock: dockWindow.dock
          outputName: dockWindow.outputName
        }
      }

      // Downloads / Trash after the separator, one copy per output so
      // layout, hover and the menu reach every dock.
      Repeater {
        model: dock.specialAppIds
        delegate: SpecialSlot {
          dock: dockWindow.dock
          outputName: dockWindow.outputName
        }
      }

    }

    MouseArea {
      id: mouseArea
      anchors.fill: parent
      z: -1
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      hoverEnabled: true
      // This delegate publishes hover for dock.dockHovered: only the screen
      // under the cursor can be hovering, so a plain boolean is enough.
      onContainsMouseChanged: dock.surfaceHovered = containsMouse
      onEntered: dock.markActiveScreen(modelData.name)
      onExited: {
        dock.maybeScheduleHide()
      }
      onPositionChanged: {
        var hoverPoint = mouseArea.mapToItem(null, mouseX, mouseY)
        dock.hoveredMouseX = dock.vertical ? hoverPoint.y : hoverPoint.x
        dock.applyLayout()
      }
      onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton) dock.openIconManager()
      }
    }
  }

  Rectangle {
    visible: dock.tooltipVisible && dock.tooltipItem !== null && dock.activeScreenName === modelData.name
    z: 20
    x: {
      if (dock.vertical && dock.dockSide === "left") return dockSurface.x + dockSurface.width + 8
      if (dock.vertical) return dockSurface.x - width - 8
      return Math.max(12, Math.min(dock.tooltipCenterX - width / 2, parent.width - width - 12))
    }
    y: {
      if (!dock.vertical) return dockSurface.y - height - 8
      return Math.max(12, Math.min(dock.tooltipCenterX - height / 2, parent.height - height - 12))
    }
    width: tooltipText.implicitWidth + 20
    height: 24
    radius: 8
    color: Util.alpha(Color.background, 0.88)
    border.color: Util.alpha(Color.foreground, 0.08)
    border.width: 1
    Text {
      textFormat: Text.PlainText
      id: tooltipText
      anchors.centerIn: parent
      text: dock.tooltipItem ? (dock.tooltipItem.name || dock.tooltipItem.id) : ""
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
    }
    // Subtle stem pointing toward the dock icon.
    Rectangle {
      x: {
        if (dock.vertical && dock.dockSide === "left") return -4
        if (dock.vertical && dock.dockSide === "right") return parent.width - 4
        return (parent.width - 8) / 2
      }
      y: dock.vertical ? (parent.height - 8) / 2 : parent.height - 5
      width: 8
      height: 8
      radius: 1
      color: parent.color
      border.color: parent.border.color
      border.width: 1
      rotation: 45
    }
  }

  MouseArea {
    x: dock.vertical ? (dock.dockSide === "left" ? 0 : parent.width - 18) : 0
    y: dock.vertical ? 0 : parent.height - 18
    width: dock.vertical ? 18 : parent.width
    height: dock.vertical ? parent.height : 18
    hoverEnabled: true
    // Hover here is already covered by the full dockSurface mouseArea
    // (containsMouse) and by icon hover (hoveredItemId). No manual
    // dockHovered needed — the binding handles it.
    onExited: dock.clearHover()
  }
}
