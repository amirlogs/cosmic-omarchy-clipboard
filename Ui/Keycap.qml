import QtQuick
import qs.Commons as Commons
import qs.Commons

// A single key badge — small rounded rectangle with monospace/menu font.
Item {
  id: root
  property string keyText: ""

  implicitWidth: Math.max(Style.space(22), keyLabel.implicitWidth + Style.space(10))
  implicitHeight: Style.space(22)
  width: implicitWidth
  height: implicitHeight

  Rectangle {
    anchors.fill: parent
    radius: Math.max(3, Style.space(4))
    color: Util.alpha(Commons.Color.foreground, 0.09)
    border.width: 1
    border.color: Util.alpha(Commons.Color.foreground, 0.22)

    Text {
      id: keyLabel
      anchors.centerIn: parent
      text: root.keyText
      color: Util.alpha(Commons.Color.foreground, 0.90)
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.caption
      font.weight: Font.DemiBold
    }
  }
}
