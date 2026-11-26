import QtQuick
import qs.Commons as Commons
import qs.Commons

// Section heading with title and bottom divider.
// Usage: SettingsSection { title: "Editor" }
Item {
  id: root
  property string title: ""

  implicitWidth: parent ? parent.width : Style.space(300)
  implicitHeight: col.implicitHeight
  width: implicitWidth
  height: implicitHeight

  Column {
    id: col
    anchors.left: parent.left
    anchors.right: parent.right
    spacing: 0

    Item { width: 1; height: Style.space(6) }

    Text {
      text: root.title
      color: Commons.Color.accent
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.bodySmall
      font.weight: Font.DemiBold
      leftPadding: Style.space(2)
    }

    Item { width: 1; height: Style.space(4) }

    Rectangle {
      width: parent.width
      height: 1
      color: Util.alpha(Commons.Color.foreground, 0.1)
    }

    Item { width: 1; height: Style.space(2) }
  }
}
