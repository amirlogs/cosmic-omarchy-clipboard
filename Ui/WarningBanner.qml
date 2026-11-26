import QtQuick
import qs.Commons as Commons
import qs.Commons

// Contextual warning banner.
// Properties: message, actionLabel, onAction, dismissible
Item {
  id: root
  property string message: ""
  property string actionLabel: ""
  property bool dismissible: false
  property bool _dismissed: false
  signal action()

  visible: !_dismissed && message.length > 0
  implicitHeight: visible ? Math.max(Style.space(36), bannerText.implicitHeight + Style.space(16)) : 0
  implicitWidth: parent ? parent.width : Style.space(300)
  width: implicitWidth
  height: implicitHeight

  Rectangle {
    anchors.fill: parent
    radius: Math.max(4, Style.space(5))
    color: Util.alpha(Commons.Color.warning, 0.1)
    border.width: 1
    border.color: Util.alpha(Commons.Color.warning, 0.35)

    Row {
      anchors.fill: parent
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      Text {
        text: "⚠"
        color: Commons.Color.warning
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.body
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        id: bannerText
        width: parent.width - Style.space(24) - (root.actionLabel.length > 0 ? actionBtn.implicitWidth + Style.space(8) : 0) - (root.dismissible ? Style.space(20) : 0)
        text: root.message
        color: Commons.Color.warning
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        id: actionBtn
        visible: root.actionLabel.length > 0
        text: root.actionLabel
        color: Commons.Color.accent
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.bodySmall
        font.underline: true
        anchors.verticalCenter: parent.verticalCenter
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.action()
        }
      }

      Text {
        visible: root.dismissible
        text: "✕"
        color: Util.alpha(Commons.Color.foreground, 0.5)
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.bodySmall
        anchors.verticalCenter: parent.verticalCenter
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root._dismissed = true
        }
      }
    }
  }
}
