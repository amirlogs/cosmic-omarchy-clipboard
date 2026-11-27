import QtQuick
import qs.Commons as Commons
import qs.Commons

// COSMIC / GNOME-style shortcut row.
// Interactive pill initiates recording on click.
// Subtle ✕ button appears on row hover when a shortcut is assigned.
// Properties: label, description, comboString, recording, conflicted, showDivider
// Signals: edit(), clear(), cancel()
Item {
  id: root

  property string label: ""
  property string description: ""
  property string comboString: ""
  property bool recording: false
  property bool conflicted: false
  property bool showDivider: true

  signal edit()
  signal clear()
  signal cancel()

  implicitHeight: Math.max(description.length > 0 ? Style.space(52) : Style.space(44), labelCol.implicitHeight + Style.space(16))
  implicitWidth: parent ? parent.width : Style.space(300)

  // Row hover state tracking for subtle hover highlight & clear button reveal
  readonly property bool isHovered: rowMouseArea.containsMouse || pillMouse.containsMouse || clearMouse.containsMouse

  // Subtle hover background across the row
  Rectangle {
    anchors.fill: parent
    radius: Style.space(6)
    color: root.isHovered && !root.recording ? Util.alpha(Commons.Color.foreground, 0.035) : "transparent"
  }

  // Left conflict indicator bar
  Rectangle {
    visible: root.conflicted
    anchors.left: parent.left
    anchors.leftMargin: Style.space(4)
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.topMargin: Style.space(6)
    anchors.bottomMargin: Style.space(6)
    width: Style.space(3)
    radius: Style.space(1.5)
    color: Commons.Color.warning
  }

  // Row mouse area for row-level hover detection
  MouseArea {
    id: rowMouseArea
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
  }

  // Label + description
  Column {
    id: labelCol
    anchors.left: parent.left
    anchors.leftMargin: root.conflicted ? Style.space(16) : Style.space(14)
    anchors.right: actionCluster.left
    anchors.rightMargin: Style.space(12)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(2)

    Text {
      width: parent.width
      text: root.label
      color: Commons.Color.foreground
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.body
      font.weight: Font.Normal
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
      maximumLineCount: 2
      elide: Text.ElideRight
    }
  }

  // Action cluster: Interactive Shortcut Pill + Subtle ✕ Clear Button
  Row {
    id: actionCluster
    anchors.right: parent.right
    anchors.rightMargin: Style.space(12)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(6)
    height: Style.space(28)

    // ── 1. INTERACTIVE SHORTCUT PILL BUTTON ────────────────────────────
    Rectangle {
      id: shortcutPill
      height: Style.space(28)
      implicitWidth: {
        if (root.recording) {
          return Math.max(Style.space(140), recordingContent.implicitWidth + Style.space(22))
        }
        if (root.comboString.length === 0) {
          return emptyContent.implicitWidth + Style.space(20)
        }
        return keycapContent.implicitWidth + Style.space(16)
      }
      width: implicitWidth
      radius: Math.max(4, Style.space(5))

      // Dynamic surface colors
      color: {
        if (root.recording) return Util.alpha(Commons.Color.accent, 0.16)
        if (root.conflicted) return Util.alpha(Commons.Color.warning, 0.14)
        if (pillMouse.containsMouse) return Util.alpha(Commons.Color.foreground, 0.10)
        return Util.alpha(Commons.Color.foreground, 0.05)
      }

      border.width: 1
      border.color: {
        if (root.recording) return Commons.Color.accent
        if (root.conflicted) return Util.alpha(Commons.Color.warning, 0.70)
        if (pillMouse.containsMouse) return Util.alpha(Commons.Color.accent, 0.50)
        return Util.alpha(Commons.Color.foreground, 0.16)
      }

      // Smooth pulsing glow during recording
      SequentialAnimation on border.color {
        running: root.recording
        loops: Animation.Infinite
        ColorAnimation {
          from: Util.alpha(Commons.Color.accent, 0.40)
          to: Commons.Color.accent
          duration: 700
          easing.type: Easing.InOutSine
        }
        ColorAnimation {
          from: Commons.Color.accent
          to: Util.alpha(Commons.Color.accent, 0.40)
          duration: 700
          easing.type: Easing.InOutSine
        }
      }

      // ── A. Recording State Display
      Row {
        id: recordingContent
        visible: root.recording
        anchors.centerIn: parent
        spacing: Style.space(6)

        Rectangle {
          width: Style.space(6)
          height: Style.space(6)
          radius: Style.space(3)
          color: Commons.Color.accent
          anchors.verticalCenter: parent.verticalCenter

          SequentialAnimation on opacity {
            running: root.recording
            loops: Animation.Infinite
            NumberAnimation { from: 1.0; to: 0.25; duration: 500; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.25; to: 1.0; duration: 500; easing.type: Easing.InOutSine }
          }
        }

        Text {
          text: "Press shortcut…"
          color: Commons.Color.accent
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.bodySmall
          font.weight: Font.DemiBold
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      // ── B. Empty / Unset State Display
      Row {
        id: emptyContent
        visible: !root.recording && root.comboString.length === 0
        anchors.centerIn: parent
        spacing: Style.space(4)

        Text {
          text: "+"
          color: pillMouse.containsMouse ? Commons.Color.accent : Util.alpha(Commons.Color.foreground, 0.45)
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.caption
          font.weight: Font.DemiBold
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          text: "Add shortcut"
          color: pillMouse.containsMouse ? Commons.Color.accent : Util.alpha(Commons.Color.foreground, 0.45)
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.bodySmall
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      // ── C. Assigned Shortcut Keycaps Display
      Row {
        id: keycapContent
        visible: !root.recording && root.comboString.length > 0
        anchors.centerIn: parent
        spacing: Style.space(4)

        // Conflict warning badge icon
        Text {
          visible: root.conflicted
          text: "⚠"
          color: Commons.Color.warning
          font.pixelSize: Style.font.caption
          anchors.verticalCenter: parent.verticalCenter
        }

        Repeater {
          model: root.comboString.length > 0 ? root.comboString.split("+") : []
          delegate: Keycap {
            required property string modelData
            keyText: modelData
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }

      // Click on the pill triggers recording (or cancels if recording)
      MouseArea {
        id: pillMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (root.recording) root.cancel()
          else root.edit()
        }
      }
    }

    // ── 2. SUBTLE ✕ CLEAR BUTTON ───────────────────────────────────────
    Rectangle {
      id: clearBtn
      visible: root.comboString.length > 0 && !root.recording
      width: Style.space(24)
      height: Style.space(24)
      radius: width / 2
      anchors.verticalCenter: parent.verticalCenter

      // Smooth fade-in on row or button hover
      opacity: (root.isHovered || clearMouse.containsMouse) ? 1.0 : 0.0
      Behavior on opacity { NumberAnimation { duration: 150 } }

      color: clearMouse.containsMouse
        ? Util.alpha(Commons.Color.urgent, 0.18)
        : Util.alpha(Commons.Color.foreground, 0.08)

      border.width: 1
      border.color: clearMouse.containsMouse
        ? Util.alpha(Commons.Color.urgent, 0.45)
        : Util.alpha(Commons.Color.foreground, 0.14)

      Text {
        anchors.centerIn: parent
        text: "✕"
        color: clearMouse.containsMouse ? Commons.Color.urgent : Util.alpha(Commons.Color.foreground, 0.60)
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.caption
      }

      MouseArea {
        id: clearMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clear()
      }
    }
  }

  // Bottom divider within card/surface
  Rectangle {
    visible: root.showDivider
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: Style.space(14)
    anchors.rightMargin: Style.space(14)
    anchors.bottom: parent.bottom
    height: 1
    color: Util.alpha(Commons.Color.foreground, 0.06)
  }
}
