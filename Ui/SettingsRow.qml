import QtQuick
import qs.Commons as Commons
import qs.Commons

// Settings row: label+description left, control slot right.
// Usage: SettingsRow { label: "..."; description: "..."; SSwitch { ... } }
Item {
  id: root
  property string label: ""
  property string description: ""
  property bool disabled: false
  default property alias content: controlSlot.data

  implicitHeight: description.length > 0 ? Style.space(52) : Style.space(44)
  implicitWidth: parent ? parent.width : Style.space(300)

  // Label+description left side
  Column {
    anchors.left: parent.left
    anchors.leftMargin: Style.space(2)
    anchors.right: controlSlot.left
    anchors.rightMargin: Style.space(12)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(2)

    Text {
      width: parent.width
      text: root.label
      color: Commons.Color.foreground
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
    }
    Text {
      visible: root.description.length > 0
      width: parent.width
      text: root.description
      color: Util.alpha(Commons.Color.foreground, 0.52)
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WordWrap
    }
  }

  // Control slot — right-aligned
  Item {
    id: controlSlot
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    implicitWidth: childrenRect.width
    implicitHeight: childrenRect.height
    width: implicitWidth
    height: implicitHeight
    opacity: root.disabled ? 0.38 : 1.0
    enabled: !root.disabled
    z: 2
  }

  // Bottom divider
  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: 1
    color: Util.alpha(Commons.Color.foreground, 0.07)
  }
}
