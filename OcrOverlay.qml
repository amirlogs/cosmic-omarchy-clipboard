import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

OverlayWindow {
  id: ocrWindow

  property color accentColor: Commons.Color.menu.selectedText
  property color scrimColor: Util.alpha(Commons.Color.menu.background, 0.45)
  property string fontFamily: Style.font.menuFamily

  property bool dragging: false
  property bool keyboardActive: false
  property real startX: 0
  property real startY: 0
  property real selX: 0
  property real selY: 0
  property real selW: 0
  property real selH: 0

  signal regionSelected(string region)
  signal canceled()

  onShownChanged: {
    if (shown) {
      dragging = false
      keyboardActive = false
      selW = 0
      selH = 0
      selX = Math.max(0, Math.round((width - 280) / 2))
      selY = Math.max(0, Math.round((height - 140) / 2))
      Qt.callLater(function() { ocrKeys.forceActiveFocus() })
    }
  }

  function confirmSelection() {
    if (selW < 8 || selH < 8) {
      shown = false
      canceled()
      return
    }
    var x = Math.max(0, Math.round(selX))
    var y = Math.max(0, Math.round(selY))
    var w = Math.max(1, Math.round(selW))
    var h = Math.max(1, Math.round(selH))
    shown = false
    pendingRegion = x + "," + y + " " + w + "x" + h
    emitTimer.restart()
  }

  property string pendingRegion: ""
  Timer {
    id: emitTimer
    interval: 120
    repeat: false
    onTriggered: {
      if (ocrWindow.pendingRegion) {
        var r = ocrWindow.pendingRegion
        ocrWindow.pendingRegion = ""
        ocrWindow.regionSelected(r)
      }
    }
  }

  Item {
    id: ocrKeys
    anchors.fill: parent
    focus: true

    Keys.onPressed: function(event) {
      var step = (event.modifiers & Qt.ControlModifier) ? 40 : 12
      var resize = !!(event.modifiers & Qt.ShiftModifier)

      if (event.key === Qt.Key_Escape) {
        ocrWindow.shown = false
        ocrWindow.canceled()
        event.accepted = true
      } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
        ocrWindow.confirmSelection()
        event.accepted = true
      } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right || event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
        if (!ocrWindow.keyboardActive && ocrWindow.selW < 8) {
          ocrWindow.selW = 280
          ocrWindow.selH = 140
          ocrWindow.selX = Math.max(0, Math.round((ocrWindow.width - ocrWindow.selW) / 2))
          ocrWindow.selY = Math.max(0, Math.round((ocrWindow.height - ocrWindow.selH) / 2))
        }
        ocrWindow.keyboardActive = true
        if (resize) {
          if (event.key === Qt.Key_Right) ocrWindow.selW = Math.min(ocrWindow.width - ocrWindow.selX, ocrWindow.selW + step)
          else if (event.key === Qt.Key_Left) ocrWindow.selW = Math.max(16, ocrWindow.selW - step)
          else if (event.key === Qt.Key_Down) ocrWindow.selH = Math.min(ocrWindow.height - ocrWindow.selY, ocrWindow.selH + step)
          else if (event.key === Qt.Key_Up) ocrWindow.selH = Math.max(16, ocrWindow.selH - step)
        } else {
          if (event.key === Qt.Key_Right) ocrWindow.selX = Math.min(ocrWindow.width - ocrWindow.selW, ocrWindow.selX + step)
          else if (event.key === Qt.Key_Left) ocrWindow.selX = Math.max(0, ocrWindow.selX - step)
          else if (event.key === Qt.Key_Down) ocrWindow.selY = Math.min(ocrWindow.height - ocrWindow.selH, ocrWindow.selY + step)
          else if (event.key === Qt.Key_Up) ocrWindow.selY = Math.max(0, ocrWindow.selY - step)
        }
        event.accepted = true
      }
    }
  }

  // Four scrim rectangles around the selection hole
  Rectangle {
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: ocrWindow.selW > 0 ? ocrWindow.selY : parent.height
    color: ocrWindow.scrimColor
  }
  Rectangle {
    visible: ocrWindow.selW > 0 && ocrWindow.selH > 0
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: Math.max(0, parent.height - (ocrWindow.selY + ocrWindow.selH))
    color: ocrWindow.scrimColor
  }
  Rectangle {
    visible: ocrWindow.selW > 0 && ocrWindow.selH > 0
    x: 0
    y: ocrWindow.selY
    width: Math.max(0, ocrWindow.selX)
    height: ocrWindow.selH
    color: ocrWindow.scrimColor
  }
  Rectangle {
    visible: ocrWindow.selW > 0 && ocrWindow.selH > 0
    x: ocrWindow.selX + ocrWindow.selW
    y: ocrWindow.selY
    width: Math.max(0, parent.width - (ocrWindow.selX + ocrWindow.selW))
    height: ocrWindow.selH
    color: ocrWindow.scrimColor
  }

  Rectangle {
    visible: ocrWindow.selW > 0 && ocrWindow.selH > 0
    x: ocrWindow.selX
    y: ocrWindow.selY
    width: ocrWindow.selW
    height: ocrWindow.selH
    color: "transparent"
    border.width: 2
    border.color: ocrWindow.accentColor
  }

  Rectangle {
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.topMargin: Style.space(18)
    width: hintText.implicitWidth + Style.space(24)
    height: Style.space(30)
    radius: Style.cornerRadius
    color: Commons.Color.menu.background
    border.width: 1
    border.color: Util.alpha(Commons.Color.menu.border, 0.4)

    Text {
      id: hintText
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: "Drag to select region · Arrows move · Shift+Arrows resize · Enter confirm · Esc cancel"
      color: Commons.Color.menu.text
      font.family: ocrWindow.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.CrossCursor
    onPressed: function(mouse) {
      ocrWindow.dragging = true
      ocrWindow.keyboardActive = false
      ocrWindow.startX = mouse.x
      ocrWindow.startY = mouse.y
      ocrWindow.selX = mouse.x
      ocrWindow.selY = mouse.y
      ocrWindow.selW = 0
      ocrWindow.selH = 0
    }
    onPositionChanged: function(mouse) {
      if (!ocrWindow.dragging) return
      ocrWindow.selX = Math.min(ocrWindow.startX, mouse.x)
      ocrWindow.selY = Math.min(ocrWindow.startY, mouse.y)
      ocrWindow.selW = Math.abs(mouse.x - ocrWindow.startX)
      ocrWindow.selH = Math.abs(mouse.y - ocrWindow.startY)
    }
    onReleased: {
      if (!ocrWindow.dragging) return
      ocrWindow.dragging = false
      ocrWindow.confirmSelection()
    }
  }
}
