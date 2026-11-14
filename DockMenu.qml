import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons

// Compact context menu anchored at the clicked icon: the app's open windows,
// the actions that apply to it, and the dock's own settings behind a "Dock"
// row. Keyboard: Up/Down, Enter, Esc.
PanelWindow {
  id: root

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  property var itemData: null
  property string iconSource: ""
  property bool opened: false
  // Pointer position (output coordinates) where the icon was clicked.
  property point requestedPosition: Qt.point(0, 0)
  property bool autoHideEnabled: true
  property string dockSide: "bottom"
  property bool trashFull: false
  // Open windows of the app: [{ address, title, active }].
  property var windows: []
  property bool dockExpanded: false
  property int currentIndex: -1

  // action, item data, optional argument (a window address).
  signal actionTriggered(string action, var itemData, string arg)

  readonly property bool isSpecial: !!(itemData && itemData.special)
  readonly property bool isRunning: !!(itemData && itemData.running)

  function row(kind, label, action, extra) {
    var r = { kind: kind, label: label || "", action: action || "", arg: "", checked: false, indent: false, danger: false, trailing: "" }
    if (extra) for (var k in extra) r[k] = extra[k]
    return r
  }

  function buildRows() {
    var rows = []
    if (!itemData) return rows
    var id = itemData.id
    rows.push(row("header", itemData.name || strings.t("menu.application")))
    rows.push(row("sep"))
    if (isSpecial) {
      rows.push(row("item", strings.t("menu.open"), "open"))
      if (id === "trash" && trashFull) rows.push(row("item", strings.t("menu.emptyTrash"), "emptyTrash", { danger: true }))
    } else {
      var shown = (windows || []).slice(0, 8)
      for (var i = 0; i < shown.length; i++)
        rows.push(row("item", shown[i].title || itemData.name, "focusWindow", { arg: shown[i].address, checked: !!shown[i].active, mark: true }))
      if (shown.length > 0) rows.push(row("sep"))
      rows.push(row("item", isRunning ? strings.t("menu.newWindow") : strings.t("menu.open"), "newWindow"))
      rows.push(row("sep"))
      rows.push(row("item", itemData.pinned ? strings.t("menu.removeFromDock") : strings.t("menu.keepInDock"), "togglePin"))
      rows.push(row("item", strings.t("menu.changeIcon"), "setIcon"))
      rows.push(row("item", strings.t("menu.manageIcons"), "manageIcons"))
    }
    rows.push(row("sep"))
    rows.push(row("item", strings.t("menu.dock"), "toggleDock", { trailing: dockExpanded ? "▾" : "▸" }))
    if (dockExpanded) {
      rows.push(row("item", strings.t("menu.autoHide"), "toggleAutoHide", { checked: autoHideEnabled, mark: true, indent: true }))
      rows.push(row("item", strings.t("menu.bottom"), "setSideBottom", { checked: dockSide === "bottom", mark: true, indent: true }))
      rows.push(row("item", strings.t("menu.left"), "setSideLeft", { checked: dockSide === "left", mark: true, indent: true }))
      rows.push(row("item", strings.t("menu.right"), "setSideRight", { checked: dockSide === "right", mark: true, indent: true }))
    }
    if (!isSpecial && isRunning) {
      rows.push(row("sep"))
      rows.push(row("item", strings.t("menu.closeAll"), "close", { danger: true }))
    }
    return rows
  }

  readonly property var rows: buildRows()

  function actionable(from, step) {
    var n = rows.length
    for (var i = 1; i <= n; i++) {
      var idx = ((from + step * i) % n + n) % n
      if (rows[idx].kind === "item") return idx
    }
    return -1
  }

  function trigger(index) {
    var r = rows[index]
    if (!r || r.kind !== "item") return
    if (r.action === "toggleDock") { dockExpanded = !dockExpanded; return }
    var data = itemData
    opened = false
    root.actionTriggered(r.action, data, r.arg)
  }

  onOpenedChanged: {
    dockExpanded = false
    currentIndex = -1
    if (opened) keys.forceActiveFocus()
  }

  visible: opened && itemData !== null
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "macos-dock-menu"
  WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
  anchors { top: true; bottom: true; left: true; right: true }
  mask: Region { item: dismissSurface }

  Item {
    id: dismissSurface
    anchors.fill: parent
    z: -1
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: root.opened = false
    }
  }

  Item {
    id: keys
    focus: true
    Keys.onEscapePressed: root.opened = false
    Keys.onUpPressed: root.currentIndex = root.actionable(root.currentIndex < 0 ? 0 : root.currentIndex, -1)
    Keys.onDownPressed: root.currentIndex = root.actionable(root.currentIndex, 1)
    Keys.onReturnPressed: root.trigger(root.currentIndex)
    Keys.onEnterPressed: root.trigger(root.currentIndex)
  }

  Rectangle {
    id: card
    width: 236
    height: content.implicitHeight + 12
    radius: 12
    color: Util.alpha(Color.background, 0.97)
    border.color: Util.alpha(Color.foreground, 0.14)
    border.width: 1

    // Beside the icon, on the side facing away from the dock edge.
    x: {
      var px = root.requestedPosition.x
      var v = root.dockSide === "left" ? px + 30
            : root.dockSide === "right" ? px - width - 30
            : px - width / 2
      return Math.round(Math.max(8, Math.min(v, root.width - width - 8)))
    }
    y: {
      var py = root.requestedPosition.y
      var v = root.dockSide === "bottom" ? py - height - 30 : py - height / 2
      return Math.round(Math.max(8, Math.min(v, root.height - height - 8)))
    }

    Column {
      id: content
      x: 6
      y: 6
      width: parent.width - 12
      spacing: 1

      Repeater {
        model: root.rows
        delegate: Item {
          id: entry
          required property var modelData
          required property int index
          width: content.width
          height: modelData.kind === "sep" ? 9 : (modelData.kind === "header" ? 32 : 28)

          Rectangle {
            visible: entry.modelData.kind === "sep"
            anchors.verticalCenter: parent.verticalCenter
            x: 6
            width: parent.width - 12
            height: 1
            color: Util.alpha(Color.foreground, 0.12)
          }

          Row {
            visible: entry.modelData.kind === "header"
            anchors.verticalCenter: parent.verticalCenter
            x: 8
            spacing: 8
            Image {
              width: 22
              height: 22
              anchors.verticalCenter: parent.verticalCenter
              source: root.iconSource
              sourceSize: Qt.size(44, 44)
              fillMode: Image.PreserveAspectFit
            }
            Text {
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              width: content.width - 50
              elide: Text.ElideRight
              text: entry.modelData.label
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
            }
          }

          Rectangle {
            visible: entry.modelData.kind === "item"
            anchors.fill: parent
            radius: 7
            color: (entry.index === root.currentIndex || itemMouse.containsMouse)
              ? (entry.modelData.danger ? Util.alpha(Color.urgent, 0.18) : Util.alpha(Color.accent, 0.20))
              : "transparent"

            Text {
              textFormat: Text.PlainText
              x: entry.modelData.indent ? 24 : 8
              width: 16
              anchors.verticalCenter: parent.verticalCenter
              text: entry.modelData.mark && entry.modelData.checked ? "✓" : ""
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.body
            }
            Text {
              // Window titles and app names are client-controlled.
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              x: entry.modelData.indent ? 44 : 26
              width: parent.width - x - 26
              elide: Text.ElideRight
              text: entry.modelData.label
              color: entry.modelData.danger ? Color.urgent : Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body
            }
            Text {
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              anchors.right: parent.right
              anchors.rightMargin: 10
              text: entry.modelData.trailing
              color: Util.alpha(Color.foreground, 0.55)
              font.pixelSize: Style.font.body
            }
            MouseArea {
              id: itemMouse
              anchors.fill: parent
              hoverEnabled: true
              onEntered: root.currentIndex = entry.index
              onClicked: root.trigger(entry.index)
            }
          }
        }
      }
    }
  }

}
