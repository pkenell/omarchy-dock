import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons

// App drawer: every installed app on one grid. Type to narrow it, arrows to
// move, Enter to launch, right-click to keep an app in the dock or take it out.
// Opened from the first dock icon or with `omarchy-shell macos.dock apps`.
PanelWindow {
  id: root

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  // The DockPanelBase controller (app entries, icons, launching, pinning).
  property var dock: null
  property bool opened: false
  property string filterText: ""
  property int selectedIndex: 0
  property var apps: []
  property var menuEntry: null
  property point menuPoint: Qt.point(0, 0)

  readonly property int iconSize: 56
  readonly property int cellWidth: 124
  readonly property int cellHeight: 116
  readonly property int maxColumns: 7
  readonly property int visibleRows: 4
  readonly property int cardPadding: 22
  readonly property int searchHeight: 40
  readonly property int cardWidth: Math.min(width - 80, maxColumns * cellWidth + cardPadding * 2)
  readonly property int columns: Math.max(1, Math.floor((cardWidth - cardPadding * 2) / cellWidth))
  readonly property int cardHeight: Math.min(height - 80, cardPadding * 2 + searchHeight + 16 + visibleRows * cellHeight)

  visible: opened && dock !== null
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "macos-dock-apps"
  WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  anchors { top: true; bottom: true; left: true; right: true }

  onOpenedChanged: {
    menuEntry = null
    if (!opened) return
    filterText = ""
    selectedIndex = 0
    rebuild()
    grid.positionViewAtBeginning()
    Qt.callLater(function() { keys.forceActiveFocus() })
  }

  Connections {
    target: root.dock
    function onAppEntriesChanged() { if (root.opened) root.rebuild() }
  }

  function close() { root.opened = false }

  function rebuild() {
    var source = root.dock ? (root.dock.appEntries || []) : []
    var needle = root.filterText.trim().toLowerCase()
    var rows = []
    for (var i = 0; i < source.length; i++) {
      var entry = source[i]
      if (!entry || entry.noDisplay === true || entry.hidden === true) continue
      var name = String(entry.name || entry.id || "")
      if (needle && name.toLowerCase().indexOf(needle) === -1
          && String(entry.id || "").toLowerCase().indexOf(needle) === -1) continue
      rows.push(entry)
    }
    rows.sort(function(a, b) {
      return String(a.name || a.id).toLowerCase().localeCompare(String(b.name || b.id).toLowerCase())
    })
    root.apps = rows
    root.selectedIndex = Math.max(0, Math.min(root.selectedIndex, rows.length - 1))
  }

  function setFilter(text) {
    root.filterText = text
    root.selectedIndex = 0
    root.rebuild()
    grid.positionViewAtBeginning()
  }

  function select(delta) {
    if (root.apps.length === 0) return
    root.selectedIndex = Math.max(0, Math.min(root.apps.length - 1, root.selectedIndex + delta))
    grid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
  }

  function launchEntry(entry) {
    if (!entry || !root.dock) return
    root.close()
    root.dock.launchApp(entry.id, entry.name)
  }

  Item {
    id: keys
    focus: true
    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_Escape) {
        if (root.menuEntry) root.menuEntry = null
        else if (root.filterText) root.setFilter("")
        else root.close()
      } else if (event.key === Qt.Key_Left) root.select(-1)
      else if (event.key === Qt.Key_Right) root.select(1)
      else if (event.key === Qt.Key_Up) root.select(-root.columns)
      else if (event.key === Qt.Key_Down) root.select(root.columns)
      else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.launchEntry(root.apps[root.selectedIndex])
      else if (event.key === Qt.Key_Backspace) root.setFilter(root.filterText.slice(0, -1))
      else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127
               && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) root.setFilter(root.filterText + event.text)
      else return
      event.accepted = true
    }
  }

  // Dim the screen; a click anywhere outside the card closes the drawer.
  Rectangle {
    anchors.fill: parent
    color: Util.alpha(Color.background, 0.55)
    opacity: root.opened ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Style.duration(150); easing.type: Easing.OutCubic } }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: {
      if (root.menuEntry) root.menuEntry = null
      else root.close()
    }
  }

  Rectangle {
    id: card
    width: root.cardWidth
    height: root.cardHeight
    anchors.centerIn: parent
    radius: 16
    color: Util.alpha(Color.background, 0.97)
    border.color: Util.alpha(Color.foreground, 0.14)
    border.width: 1
    opacity: root.opened ? 1 : 0
    scale: root.opened ? 1 : 0.97
    Behavior on opacity { NumberAnimation { duration: Style.duration(150); easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: Style.duration(150); easing.type: Easing.OutCubic } }

    // Swallow clicks so they do not reach the dismiss area.
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: root.menuEntry = null
    }

    Column {
      x: root.cardPadding
      y: root.cardPadding
      width: parent.width - root.cardPadding * 2
      height: parent.height - root.cardPadding * 2
      spacing: 16

      Rectangle {
        width: parent.width
        height: root.searchHeight
        radius: 10
        color: Util.alpha(Color.foreground, 0.07)

        Text {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.leftMargin: 14
          anchors.rightMargin: 14
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: root.filterText || strings.t("drawer.search")
          color: Color.foreground
          opacity: root.filterText ? 1 : 0.55
          font.family: Style.font.family
          font.pixelSize: Style.font.body + 3
          elide: Text.ElideRight
        }
      }

      Item {
        width: parent.width
        height: parent.height - root.searchHeight - parent.spacing

        GridView {
          id: grid
          anchors.horizontalCenter: parent.horizontalCenter
          width: root.columns * root.cellWidth
          height: parent.height
          model: root.apps
          clip: true
          cellWidth: root.cellWidth
          cellHeight: root.cellHeight
          boundsBehavior: Flickable.StopAtBounds

          delegate: Item {
            id: cell
            required property int index
            required property var modelData
            readonly property bool selected: index === root.selectedIndex
            width: root.cellWidth
            height: root.cellHeight

            Image {
              id: icon
              anchors.horizontalCenter: parent.horizontalCenter
              y: 10
              width: root.iconSize
              height: root.iconSize
              sourceSize: Qt.size(root.iconSize * 2, root.iconSize * 2)
              source: root.dock ? root.dock.iconSourceFor(cell.modelData.id) : ""
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              smooth: true
              mipmap: true
            }

            Rectangle {
              anchors.centerIn: label
              width: Math.min(cell.width - 8, label.contentWidth + 16)
              height: label.contentHeight + 6
              radius: 8
              color: cell.selected ? Util.alpha(Color.foreground, 0.16) : "transparent"
            }

            Text {
              id: label
              anchors.top: icon.bottom
              anchors.topMargin: 10
              anchors.horizontalCenter: parent.horizontalCenter
              width: parent.width - 16
              textFormat: Text.PlainText
              text: String(cell.modelData.name || cell.modelData.id)
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.Wrap
              maximumLineCount: 2
              elide: Text.ElideRight
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              onContainsMouseChanged: if (containsMouse) root.selectedIndex = cell.index
              onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton) {
                  root.menuPoint = cell.mapToItem(null, mouse.x, mouse.y)
                  root.menuEntry = cell.modelData
                  return
                }
                root.menuEntry = null
                root.launchEntry(cell.modelData)
              }
            }
          }
        }

        Text {
          anchors.centerIn: parent
          visible: root.apps.length === 0
          textFormat: Text.PlainText
          text: strings.t("drawer.noMatch").arg(root.filterText)
          color: Color.foreground
          opacity: 0.7
          font.family: Style.font.family
          font.pixelSize: Style.font.body + 2
        }
      }
    }
  }

  // Right-click on an app: open it, or keep it in the dock or take it out.
  Rectangle {
    id: menu
    readonly property bool pinned: !!root.menuEntry && !!root.dock && root.dock.isAppPinned(root.menuEntry.id)
    visible: !!root.menuEntry
    width: 190
    height: menuColumn.implicitHeight + 12
    x: Math.max(8, Math.min(root.menuPoint.x, root.width - width - 8))
    y: Math.max(8, Math.min(root.menuPoint.y, root.height - height - 8))
    radius: 10
    color: Util.alpha(Color.background, 0.98)
    border.color: Util.alpha(Color.foreground, 0.18)
    border.width: 1

    MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton }

    Column {
      id: menuColumn
      x: 6
      y: 6
      width: parent.width - 12

      Repeater {
        model: [
          { label: strings.t("drawer.open"), action: "open" },
          { label: menu.pinned ? strings.t("drawer.removeFromDock") : strings.t("drawer.keepInDock"), action: "pin" }
        ]
        delegate: Rectangle {
          required property var modelData
          width: menuColumn.width
          height: 30
          radius: 6
          color: rowMouse.containsMouse ? Util.alpha(Color.foreground, 0.12) : "transparent"

          Text {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: parent.modelData.label
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }

          MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              var entry = root.menuEntry
              if (!entry) return
              if (parent.modelData.action === "open") root.launchEntry(entry)
              else {
                root.dock.toggleAppPinned(entry.id)
                root.menuEntry = null
              }
            }
          }
        }
      }
    }
  }
}
