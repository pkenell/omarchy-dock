import QtQuick
import qs.Commons

// Label + value + horizontal slider. `value` is bound by the owner; the slider
// only reports user changes through moved(), and released() when the pointer
// lets go (the moment to save).
Item {
  id: root

  property string label: ""
  property string valueText: ""
  property real from: 0
  property real to: 1
  property real stepSize: 0.05
  property real value: 0

  signal moved(real value)
  signal released()

  readonly property real fraction: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0

  implicitHeight: 46

  Text {
    textFormat: Text.PlainText
    x: 2
    text: root.label
    color: Color.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.body
  }
  Text {
    textFormat: Text.PlainText
    anchors.right: parent.right
    anchors.rightMargin: 2
    text: root.valueText
    color: Util.alpha(Color.foreground, 0.6)
    font.family: Style.font.family
    font.pixelSize: Style.font.body
  }

  Item {
    id: track
    x: 8
    y: 26
    width: parent.width - 16
    height: 16

    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width
      height: 4
      radius: 2
      color: Util.alpha(Color.foreground, 0.16)
    }
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: root.fraction * parent.width
      height: 4
      radius: 2
      color: Color.accent
    }
    Rectangle {
      x: root.fraction * (parent.width - width)
      anchors.verticalCenter: parent.verticalCenter
      width: 16
      height: 16
      radius: 8
      color: Color.foreground
      border.color: Util.alpha(Color.background, 0.4)
      border.width: 1
    }

    MouseArea {
      anchors.fill: parent
      anchors.margins: -6
      function update(mouse) {
        var f = Math.max(0, Math.min(1, (mouse.x - 6 - 8) / (track.width - 16)))
        var v = root.from + f * (root.to - root.from)
        if (root.stepSize > 0) v = Math.round(v / root.stepSize) * root.stepSize
        v = Math.max(root.from, Math.min(root.to, v))
        if (Math.abs(v - root.value) > 1e-9) root.moved(v)
      }
      onPressed: function(mouse) { update(mouse) }
      onPositionChanged: function(mouse) { if (pressed) update(mouse) }
      onReleased: root.released()
      onCanceled: root.released()
    }
  }
}
