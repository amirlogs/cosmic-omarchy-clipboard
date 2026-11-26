import QtQuick
import qs.Commons as Commons
import qs.Commons

// Compact dropdown selector.
// model: array of { val, label }
// currentValue: selected val
// signal selected(val)
Item {
  id: root

  property var model: []
  property var currentValue: null
  property string placeholder: "Select…"
  property bool _open: false
  signal selected(var val)

  implicitHeight: Style.space(28)
  implicitWidth: Style.space(140)
  width: implicitWidth
  height: implicitHeight
  z: _open ? 1000 : 1

  on_OpenChanged: {
    var p = root.parent
    var depth = 0
    while (p && depth < 5) {
      if (p.z !== undefined) {
        if (root._open) {
          if (p._savedZ === undefined) p._savedZ = p.z
          p.z = 200
        } else if (p._savedZ !== undefined) {
          p.z = p._savedZ
          p._savedZ = undefined
        }
      }
      p = p.parent
      depth++
    }
  }

  readonly property string currentLabel: {
    for (var i = 0; i < root.model.length; i++) {
      if (root.model[i].val === root.currentValue) return root.model[i].label
    }
    return root.placeholder
  }

  Rectangle {
    id: trigger
    anchors.fill: parent
    radius: Math.max(4, Style.space(4))
    color: root._open ? Util.alpha(Commons.Color.foreground, 0.12) : Util.alpha(Commons.Color.foreground, 0.07)
    border.width: 1
    border.color: root._open ? Util.alpha(Commons.Color.accent, 0.5) : Util.alpha(Commons.Color.foreground, 0.18)

    Row {
      anchors.fill: parent
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(6)

      Text {
        width: parent.width - arrowText.implicitWidth - Style.space(4)
        height: parent.height
        text: root.currentLabel
        color: Commons.Color.foreground
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.bodySmall
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
      }
      Text {
        id: arrowText
        anchors.verticalCenter: parent.verticalCenter
        text: root._open ? "▴" : "▾"
        color: Util.alpha(Commons.Color.foreground, 0.6)
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.caption
      }
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: root._open = !root._open
    }
  }

  // Popup overlay
  Rectangle {
    id: popup
    visible: root._open
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.bottom
    anchors.topMargin: Style.space(2)
    z: 1001
    height: Math.min(root.model.length * Style.space(28), Style.space(160))
    radius: Math.max(4, Style.space(4))
    color: Commons.Color.menu.background
    border.width: 1
    border.color: Util.alpha(Commons.Color.foreground, 0.22)
    clip: true

    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_Escape) {
        root._open = false
        event.accepted = true
      }
    }

    ListView {
      anchors.fill: parent
      model: root.model
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      delegate: Rectangle {
        required property var modelData
        required property int index

        width: ListView.view.width
        height: Style.space(28)
        color: itemMouse.containsMouse ? Util.alpha(Commons.Color.foreground, 0.09) : "transparent"
        readonly property bool isSelected: root.currentValue === modelData.val

        Text {
          anchors.fill: parent
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(8)
          text: modelData.label
          color: isSelected ? Commons.Color.accent : Commons.Color.foreground
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.bodySmall
          font.weight: isSelected ? Font.DemiBold : Font.Normal
          verticalAlignment: Text.AlignVCenter
        }

        MouseArea {
          id: itemMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root._open = false
            root.selected(modelData.val)
          }
        }
      }
    }
  }
}
