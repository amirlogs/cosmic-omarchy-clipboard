import QtQuick
import qs.Commons as Commons
import qs.Commons

// Horizontal slider with draggable thumb and value label.
// Bind value, min, max, step. Connect moved(val) signal.
Item {
  id: root

  property real value: 0
  property real min: 0
  property real max: 1
  property real step: 0.1
  property var formatValue: function(v) { return String(Math.round(v)) }
  signal moved(real val)

  implicitHeight: Style.space(28)
  implicitWidth: Style.space(160)
  width: implicitWidth
  height: implicitHeight

  readonly property real fraction: max > min ? Math.min(1, Math.max(0, (value - min) / (max - min))) : 0

  Item {
    id: sliderArea
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.right: valLabel.left
    anchors.rightMargin: Style.space(8)

    // Track background
    Rectangle {
      id: track
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      height: Style.space(4)
      radius: height / 2
      color: Util.alpha(Commons.Color.foreground, 0.12)

      // Filled portion
      Rectangle {
        width: root.fraction * parent.width
        height: parent.height
        radius: parent.radius
        color: Util.alpha(Commons.Color.accent, 0.6)
      }
    }

    // Thumb
    Rectangle {
      id: thumb
      width: Style.space(14)
      height: Style.space(14)
      radius: height / 2
      anchors.verticalCenter: track.verticalCenter
      x: root.fraction * (sliderArea.width - width)
      color: Commons.Color.accent
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      function updateFromMouse(mouseX) {
        var frac = Math.min(1, Math.max(0, mouseX / sliderArea.width))
        var raw = root.min + frac * (root.max - root.min)
        var stepped = Math.round(raw / root.step) * root.step
        var clamped = Math.min(root.max, Math.max(root.min, stepped))
        root.moved(clamped)
      }
      onPressed: function(mouse) { updateFromMouse(mouse.x) }
      onPositionChanged: function(mouse) { if (pressed) updateFromMouse(mouse.x) }
    }
  }

  Text {
    id: valLabel
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    text: root.formatValue(root.value)
    color: Util.alpha(Commons.Color.accent, 0.85)
    font.family: Style.font.menuFamily
    font.pixelSize: Style.font.bodySmall
    width: Style.space(42)
    horizontalAlignment: Text.AlignRight
  }
}
