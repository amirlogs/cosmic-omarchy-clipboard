import QtQuick
import qs.Commons as Commons
import qs.Commons

// Segmented exclusive-choice control.
// model: array of { val, label }
// currentValue: the selected val
// signal selected(val)
Item {
  id: root

  property var model: []
  property var currentValue: null
  signal selected(var val)

  implicitHeight: Style.space(28)
  implicitWidth: row.implicitWidth
  width: implicitWidth
  height: implicitHeight

  Row {
    id: row
    height: parent.height
    spacing: 0

    Repeater {
      model: root.model
      delegate: Item {
        required property var modelData
        required property int index

        readonly property bool isActive: root.currentValue === modelData.val
        readonly property bool isFirst: index === 0
        readonly property bool isLast: index === root.model.length - 1

        width: segText.implicitWidth + Style.space(16)
        height: row.height

        Rectangle {
          anchors.fill: parent
          color: isActive ? Util.alpha(Commons.Color.accent, 0.22) : Util.alpha(Commons.Color.foreground, 0.07)
          border.width: 1
          border.color: isActive ? Util.alpha(Commons.Color.accent, 0.5) : Util.alpha(Commons.Color.foreground, 0.18)

          // Corner radius only on first/last
          radius: (isFirst || isLast) ? Math.max(4, Style.space(5)) : 0

          // Clip the unwanted corners for first/last
          Rectangle {
            visible: isFirst && !isLast
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.radius
            color: parent.color
          }
          Rectangle {
            visible: isLast && !isFirst
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.radius
            color: parent.color
          }
        }

        Text {
          id: segText
          anchors.centerIn: parent
          text: modelData.label
          color: isActive ? Commons.Color.accent : Commons.Color.foreground
          opacity: isActive ? 1.0 : 0.65
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.bodySmall
          font.weight: isActive ? Font.DemiBold : Font.Normal
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.selected(modelData.val)
        }
      }
    }
  }
}
