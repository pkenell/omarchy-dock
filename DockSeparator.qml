import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import "DockModel.js" as DockModel

// The fixed divider before Downloads and Trash.

Item {
  id: separatorItem
  required property var dock
  required property string outputName
  property string screenName: outputName
  width: dock.separatorWidth
  height: dock.itemHeight
  x: 0
  property bool animating: false
  property real targetScale: 1
  property real targetOpacity: 1
  Behavior on x {
    enabled: separatorItem.animating && dock.layoutTransition && Style.duration(1) > 0
    SpringAnimation { spring: 4.5; damping: 0.95; mass: 1 }
  }
  // No icon owns the gap around the separator, so without this the
  // magnification would freeze at the last icon and then jump on the next one.
  // Follow the pointer across the whole gap (separator plus the spacing on each
  // side), at the height of an icon.
  MouseArea {
    x: -dock.slotSpacing
    width: separatorItem.width + 2 * dock.slotSpacing
    y: Math.round((separatorItem.height - dock.iconSize) / 2)
    height: dock.iconSize
    acceptedButtons: Qt.NoButton
    hoverEnabled: true
    function follow() {
      if (dock.floatingId) return
      var p = mapToItem(null, mouseX, mouseY)
      dock.markActiveScreen(separatorItem.outputName)
      dock.hoveredMouseX = dock.vertical ? p.y : p.x
      dock.applyLayout()
    }
    onEntered: follow()
    onPositionChanged: follow()
  }

  Rectangle {
    anchors.centerIn: parent
    width: 1
    height: 36
    radius: 0.5
    color: Util.alpha(Color.foreground, 0.12)
  }
  Component.onCompleted: {
    dock.registerItem(DockModel.SEPARATOR_ID, separatorItem)
    separatorItem.x = dock.seedFor(DockModel.SEPARATOR_ID).x
    separatorItem.animating = true
  }
  Component.onDestruction: dock.unregisterItem(DockModel.SEPARATOR_ID, separatorItem)
}
