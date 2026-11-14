import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import "DockModel.js" as DockModel

// One app icon in one output dock row. `dock` is the DockPanelBase
// controller that owns layout, drag and hover state.

Item {
  id: wrapper
  required property var dock
  // The dock window pill, for mapping drag coordinates to surface space.
  required property Item surface
  required property string outputName
  required property string modelData
  // Capture the output once: `modelData` is shadowed by the app id
  // here, and pruneOutputs() needs the output to drop delegates of
  // unplugged monitors (no destruction hook fires for them).
  property string screenName: outputName
  // The wrapper spans the scaled slot so the centered icon sits at
  // the slot's visual center — a single magnified icon stays
  // centered in the dock instead of drifting left.
  width: dock.effSlotWidth * targetScale
  height: dock.itemHeight
  x: 0
  rotation: dock.vertical ? -90 : 0
  property bool animating: false

  // Live metadata mirrored from observable root state so a pin or
  // running toggle updates the delegate in place instead of the
  // Repeater rebuilding every DockItem.
  property var liveData: ({
    id: modelData,
    name: dock.appNameFor(modelData),
    icon: dock.appIconNameFor(modelData),
    pinned: dock.pinnedIds.indexOf(modelData) !== -1,
    running: dock.runningIds.indexOf(modelData) !== -1
  })

  property alias targetScale: dockItem.targetScale
  property alias targetOpacity: dockItem.targetOpacity
  property alias bounceOffset: dockItem.bounceOffset
  function playBounce() { return dockItem.playLaunchBounce() }
  function cancelBounce() { dockItem.cancelLaunchBounce() }

  Behavior on x {
    enabled: wrapper.animating && dock.layoutTransition && Style.duration(1) > 0
    SpringAnimation { spring: 4.5; damping: 0.95; mass: 1 }
  }

  Component.onCompleted: {
    dock.registerItem(modelData, wrapper)
    var seed = dock.seedFor(modelData)
    x = seed.x
    targetScale = seed.scale
    targetOpacity = (modelData === dock.floatingId) ? 0.01 : 1
    animating = true
    // Newly appearing launched app: the bounce intent was recorded
    // before this delegate existed; play it now that animation is on.
    if (dock.bouncingIds.indexOf(modelData) !== -1 && !dockItem.playLaunchBounce())
      dock.finishLaunchBounce(modelData)
  }
  Component.onDestruction: {
    dock.visualCache[modelData] = { x: x, scale: targetScale }
    dock.unregisterItem(modelData, wrapper)
  }

  DockItem {
    id: dockItem
    // Only the icon reacts to the pointer. On a side dock the area also spans
    // the gap to the neighbors (pitch = slot + spacing), so there are no dead
    // strips between icons where the magnification would flicker off.
    hitTop: dock.vertical ? -Math.round((dock.effSlotWidth + dock.slotSpacing - dock.iconSize) / 2) : 0
    hitHeight: dock.vertical ? dock.effSlotWidth + dock.slotSpacing : dock.iconSize
    anchors.centerIn: parent
    itemData: wrapper.liveData
    iconSize: dock.iconSize
    dockSide: dock.dockSide
    animationEnabled: wrapper.animating && dock.layoutTransition
    iconSourceOverride: dock.iconSourceFor(modelData)
    onItemLeftClicked: function(clickedItem) { dock.handleClick(clickedItem) }
    onItemRightClicked: function(clickedItem, position) { dock.openMenu(clickedItem, position) }
    onLaunchBounceFinished: dock.finishLaunchBounce(modelData)
    onDragMoved: function(draggedItem, position) {
      dock.onDragMoved(draggedItem,
        dockItem.mapToItem(null, position.x, position.y),
        dockItem.mapToItem(surface, position.x, position.y))
    }
    onDragFinished: function(draggedItem, position) {
      dock.finishDrag(draggedItem, dockItem.mapToItem(surface, position.x, position.y))
    }
    onTooltipRequested: function(hoveredItem, isVisible, center) {
      dock.markActiveScreen(outputName)
      dock.tooltipCenterX = dock.vertical ? center.y : center.x
      dock.onItemHoverChanged(hoveredItem, isVisible, dock.tooltipCenterX)
      dock.showTooltip(hoveredItem, isVisible)
    }
    onHoverPointerChanged: function(hoveredItem, isInside, position) {
      dock.markActiveScreen(outputName)
      if (isInside) {
        dock.hoveredItemId = hoveredItem.id
        dock.hoveredMouseX = dock.vertical ? position.y : position.x
        dock.tooltipCenterX = dock.vertical ? position.y : position.x
      } else if (!dock.floatingId && dock.hoveredItemId === hoveredItem.id) {
        dock.hoveredItemId = ""
      }
      dock.applyLayout()
    }
  }
}
