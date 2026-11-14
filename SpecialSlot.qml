import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import "DockModel.js" as DockModel

// Downloads or Trash after the separator, one copy per output.

Item {
  id: specialWrapper
  required property var dock
  required property string outputName
  required property string modelData
  readonly property string specialId: modelData
  property string screenName: outputName
  width: dock.effSlotWidth * targetScale
  height: dock.itemHeight
  x: 0
  rotation: dock.vertical ? -90 : 0
  property bool animating: false
  property alias targetScale: specialItem.targetScale
  property alias targetOpacity: specialItem.targetOpacity
  Behavior on x {
    enabled: specialWrapper.animating && dock.layoutTransition && Style.duration(1) > 0
    SpringAnimation { spring: 4.5; damping: 0.95; mass: 1 }
  }
  Component.onCompleted: {
    dock.registerItem(specialId, specialWrapper)
    var seed = dock.seedFor(specialId)
    x = seed.x
    targetScale = seed.scale
    animating = true
  }
  Component.onDestruction: dock.unregisterItem(specialId, specialWrapper)

  DockItem {
    id: specialItem
    // Only the icon reacts to the pointer. On a side dock the area also spans
    // the gap to the neighbors (pitch = slot + spacing), so there are no dead
    // strips between icons where the magnification would flicker off.
    hoverLift: dock.hoverEffect === "lift" && dock.hoveredItemId === specialId ? dock.liftHeight : 0
    hitTop: dock.vertical ? -Math.round((dock.effSlotWidth + dock.slotSpacing - dock.iconSize) / 2) : 0
    hitHeight: dock.vertical ? dock.effSlotWidth + dock.slotSpacing : dock.iconSize
    anchors.centerIn: parent
    draggable: false
    itemData: specialWrapper.specialId === "downloads"
      ? ({ id: "downloads", name: dock.t("special.downloads"), icon: "folder-download", pinned: false, running: false, special: true })
      : ({ id: "trash", name: dock.t("special.trash"), icon: dock.trashFull ? "user-trash-full" : "user-trash", pinned: false, running: false, special: true })
    iconSize: dock.iconSize
    dockSide: dock.dockSide
    animationEnabled: specialWrapper.animating && dock.layoutTransition
    iconSourceOverride: ""
    onItemLeftClicked: function(clickedItem) {
      if (specialWrapper.specialId === "downloads") dock.openDownloads()
      else dock.openTrash()
    }
    onItemRightClicked: function(clickedItem, position) { dock.openMenu(clickedItem, position) }
    onTooltipRequested: function(hoveredItem, isVisible, center) {
      dock.markActiveScreen(outputName)
      dock.tooltipCenterX = dock.vertical ? center.y : center.x
      dock.showTooltip(hoveredItem, isVisible)
    }
    onHoverPointerChanged: function(hoveredItem, isInside, position) {
      dock.markActiveScreen(outputName)
      dock.hoverSpecial(hoveredItem, isInside, position)
    }
  }
}
