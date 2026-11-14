import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons

// Dock look: icon size, magnification and background. Changes apply to the
// live dock as the sliders move and are saved when the pointer is released.
PanelWindow {
  id: root

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  // The DockPanelBase controller.
  property var dock: null
  property bool opened: false
  // Where the dock menu was opened; the card appears next to it.
  property point requestedPosition: Qt.point(0, 0)

  visible: opened && dock !== null
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "macos-dock-settings"
  WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
  anchors { top: true; bottom: true; left: true; right: true }
  mask: Region { item: dismissSurface }

  onOpenedChanged: if (opened) keys.forceActiveFocus()

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
    Keys.onReturnPressed: root.opened = false
  }

  Rectangle {
    id: card
    width: 280
    height: content.implicitHeight + 28
    radius: 12
    color: Util.alpha(Color.background, 0.97)
    border.color: Util.alpha(Color.foreground, 0.14)
    border.width: 1

    x: {
      var px = root.requestedPosition.x
      var side = root.dock ? root.dock.dockSide : "bottom"
      var v = side === "left" ? px + 30 : side === "right" ? px - width - 30 : px - width / 2
      return Math.round(Math.max(8, Math.min(v, root.width - width - 8)))
    }
    y: {
      var py = root.requestedPosition.y
      var side = root.dock ? root.dock.dockSide : "bottom"
      var v = side === "bottom" ? py - height - 30 : py - height / 2
      return Math.round(Math.max(8, Math.min(v, root.height - height - 8)))
    }

    // Swallow clicks so they do not reach the dismiss surface.
    MouseArea { anchors.fill: parent }

    Column {
      id: content
      x: 14
      y: 14
      width: parent.width - 28
      spacing: 6

      Text {
        textFormat: Text.PlainText
        text: strings.t("settings.title")
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
        bottomPadding: 4
      }

      SettingSlider {
        width: content.width
        label: strings.t("settings.iconSize")
        valueText: root.dock ? root.dock.iconSize + " px" : ""
        from: 24; to: 80; stepSize: 2
        value: root.dock ? root.dock.iconSize : 30
        onMoved: function(v) { root.dock.iconSize = Math.round(v) }
        onReleased: root.dock.saveSettings()
      }

      Column {
        width: content.width
        spacing: 6
        Text {
          x: 2
          textFormat: Text.PlainText
          text: strings.t("settings.hoverEffect")
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }
        Row {
          spacing: 6
          Repeater {
            model: [
              { value: "magnify", label: strings.t("settings.effectMagnify") },
              { value: "lift", label: strings.t("settings.effectLift") },
              { value: "none", label: strings.t("settings.effectNone") }
            ]
            delegate: Rectangle {
              required property var modelData
              readonly property bool selected: root.dock && root.dock.hoverEffect === modelData.value
              width: (content.width - 12) / 3
              height: 28
              radius: 7
              color: selected ? Util.alpha(Color.accent, 0.35)
                   : choiceMouse.containsMouse ? Util.alpha(Color.accent, 0.18) : Util.alpha(Color.foreground, 0.08)
              border.width: selected ? 1 : 0
              border.color: Color.accent
              Text {
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: parent.modelData.label
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.body
              }
              MouseArea {
                id: choiceMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: { root.dock.hoverEffect = parent.modelData.value; root.dock.saveSettings() }
              }
            }
          }
        }
      }

      SettingSlider {
        width: content.width
        visible: root.dock && root.dock.hoverEffect === "magnify"
        label: strings.t("settings.hoverScale")
        valueText: !root.dock ? "" : (root.dock.hoverScale <= 1.001 ? strings.t("settings.hoverOff") : "×" + root.dock.hoverScale.toFixed(2))
        from: 1; to: 2.5; stepSize: 0.05
        value: root.dock ? root.dock.hoverScale : 1.5
        onMoved: function(v) { root.dock.hoverScale = v }
        onReleased: root.dock.saveSettings()
      }

      SettingSlider {
        width: content.width
        visible: root.dock && root.dock.hoverEffect === "magnify"
        label: strings.t("settings.magnifyReach")
        valueText: root.dock ? root.dock.magnifyReach + " px" : ""
        from: 40; to: 240; stepSize: 8
        value: root.dock ? root.dock.magnifyReach : 96
        onMoved: function(v) { root.dock.magnifyReach = Math.round(v) }
        onReleased: root.dock.saveSettings()
      }

      SettingSlider {
        width: content.width
        label: strings.t("settings.padding")
        valueText: root.dock ? root.dock.dockPadding + " px" : ""
        from: 8; to: 48; stepSize: 2
        value: root.dock ? root.dock.dockPadding : 22
        onMoved: function(v) { root.dock.dockPadding = Math.round(v) }
        onReleased: root.dock.saveSettings()
      }

      SettingSlider {
        width: content.width
        label: strings.t("settings.background")
        valueText: !root.dock ? "" : (root.dock.backgroundOpacity >= 0.995 ? strings.t("settings.solid")
                   : root.dock.backgroundOpacity <= 0.005 ? strings.t("settings.transparent")
                   : Math.round(root.dock.backgroundOpacity * 100) + " %")
        from: 0; to: 1; stepSize: 0.05
        value: root.dock ? root.dock.backgroundOpacity : 0.5
        onMoved: function(v) { root.dock.backgroundOpacity = v }
        onReleased: root.dock.saveSettings()
      }

      Item { width: 1; height: 4 }

      Row {
        spacing: 8
        anchors.right: parent.right
        Repeater {
          model: [
            { label: strings.t("settings.reset"), action: "reset" },
            { label: strings.t("settings.done"), action: "done" }
          ]
          delegate: Rectangle {
            required property var modelData
            width: 84
            height: 28
            radius: 7
            color: btn.containsMouse ? Util.alpha(Color.accent, 0.28) : Util.alpha(Color.foreground, 0.08)
            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: parent.modelData.label
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body
            }
            MouseArea {
              id: btn
              anchors.fill: parent
              hoverEnabled: true
              onClicked: {
                if (parent.modelData.action === "reset") root.dock.resetDockLook()
                else root.opened = false
              }
            }
          }
        }
      }
    }
  }
}
