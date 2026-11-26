import QtQuick
import qs.Commons as Commons
import qs.Commons

// A single key badge — small rounded rectangle with monospace text.
Item {
  id: root
  property string keyText: ""

  implicitWidth: keyLabel.implicitWidth + Style.space(8)
  implicitHeight: Style.space(20)
  width: implicitWidth
  height: implicitHeight

  Rectangle {
    anchors.fill: parent
    radius: Style.space(3)
    color: Util.alpha(Commons.Color.foreground, 0.07)
    border.width: 1
    border.color: Util.alpha(Commons.Color.foreground, 0.3)

    Text {
      id: keyLabel
      anchors.centerIn: parent
      text: root.keyText
      color: Util.alpha(Commons.Color.foreground, 0.85)
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.caption
    }
  }
}
