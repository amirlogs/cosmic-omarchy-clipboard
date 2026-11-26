import QtQuick
import qs.Commons as Commons
import qs.Commons

// Animated toggle switch. Bind `checked` and connect `toggled` signal.
Item {
  id: root

  property bool checked: false
  signal toggled()

  implicitWidth: Style.space(32)
  implicitHeight: Style.space(18)
  width: implicitWidth
  height: implicitHeight

  Rectangle {
    id: track
    anchors.fill: parent
    radius: height / 2
    color: root.checked ? Util.alpha(Commons.Color.accent, 0.35) : Util.alpha(Commons.Color.foreground, 0.14)
    border.width: 1
    border.color: root.checked ? Util.alpha(Commons.Color.accent, 0.65) : Util.alpha(Commons.Color.foreground, 0.22)

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    Rectangle {
      id: thumb
      width: Style.space(14)
      height: Style.space(14)
      radius: height / 2
      anchors.verticalCenter: parent.verticalCenter
      x: root.checked ? parent.width - width - Style.space(2) : Style.space(2)
      color: root.checked ? Commons.Color.accent : Util.alpha(Commons.Color.foreground, 0.75)

      Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
      Behavior on color { ColorAnimation { duration: 120 } }
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggled()
  }
}
