import QtQuick
import qs.Commons as Commons
import qs.Commons

// Shortcut row: label+description left, keycap chips right + Edit/Clear buttons.
// Properties: label, description, comboString (e.g. "Ctrl+Shift+Z"), recording, conflicted
// Signals: edit(), clear()
Item {
  id: root
  property string label: ""
  property string description: ""
  property string comboString: ""
  property bool recording: false
  property bool conflicted: false
  signal edit()
  signal clear()
  signal cancel()

  implicitHeight: description.length > 0 ? Style.space(52) : Style.space(44)
  implicitWidth: parent ? parent.width : Style.space(300)

  // Conflict left border
  Rectangle {
    visible: root.conflicted
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: Style.space(2)
    color: Commons.Color.warning
  }

  // Edit + Clear buttons (right-most)
  Row {
    id: btnRow
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(8)

    Text {
      text: root.recording ? "Cancel" : "Edit"
      color: Commons.Color.accent
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.bodySmall
      opacity: editMouse.containsMouse ? 1.0 : 0.75
      MouseArea {
        id: editMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (root.recording) root.cancel()
          else root.edit()
        }
      }
    }

    Text {
      text: "Clear"
      color: Util.alpha(Commons.Color.urgent, 0.85)
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.bodySmall
      visible: root.comboString.length > 0 && !root.recording
      opacity: clearMouse.containsMouse ? 1.0 : 0.75
      MouseArea {
        id: clearMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clear()
      }
    }
  }

  // Keycaps or recording indicator
  Item {
    id: keycapArea
    anchors.right: btnRow.left
    anchors.rightMargin: Style.space(12)
    anchors.verticalCenter: parent.verticalCenter
    width: root.recording ? Style.space(130) : (keycapRow.implicitWidth + Style.space(4))
    height: Style.space(24)

    Rectangle {
      visible: root.recording
      anchors.fill: parent
      radius: Style.space(4)
      color: Util.alpha(Commons.Color.accent, 0.1)
      border.width: 1
      border.color: Util.alpha(Commons.Color.accent, 0.5)

      Text {
        anchors.centerIn: parent
        text: "Press shortcut…"
        color: Commons.Color.accent
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.caption
        font.italic: true
      }

      SequentialAnimation on opacity {
        running: root.recording
        loops: Animation.Infinite
        NumberAnimation { from: 1.0; to: 0.5; duration: 600; easing.type: Easing.InOutSine }
        NumberAnimation { from: 0.5; to: 1.0; duration: 600; easing.type: Easing.InOutSine }
      }
    }

    Row {
      id: keycapRow
      visible: !root.recording
      anchors.verticalCenter: parent.verticalCenter
      anchors.right: parent.right
      spacing: Style.space(3)

      Repeater {
        model: root.comboString.length > 0 ? root.comboString.split("+") : []
        delegate: Keycap {
          required property string modelData
          keyText: modelData
        }
      }
    }
  }

  // Label+description (left side, fills remainder)
  Column {
    anchors.left: parent.left
    anchors.leftMargin: root.conflicted ? Style.space(8) : Style.space(2)
    anchors.right: keycapArea.left
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

  // Bottom divider
  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: 1
    color: Util.alpha(Commons.Color.foreground, 0.07)
  }
}
