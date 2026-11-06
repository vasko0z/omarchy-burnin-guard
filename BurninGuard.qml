import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons

// Burn-in Guard: раз в N секунд по верхней панели проходит тёмная волна.
// Панель статична (часы, метрики) — на OLED это выгорающие пиксели; волна
// сдвигает их. Окно лежит на слое overlay, клики проходят насквозь (mask пуст).
//
// Настройки: ~/.config/omarchy/burnin-guard.json (перечитывается на лету):
//   intervalSeconds, durationMs, waveWidth, color, opacity, height
Item {
  id: root

  property var shell: null
  property var manifest: null

  property int intervalSeconds: 60
  property int durationMs: 1400
  property int waveWidth: 600
  property color waveColor: "#000000"
  property real waveOpacity: 1.0
  property int barHeight: Style.bar.sizeHorizontal

  readonly property string settingsPath: Quickshell.env("HOME") + "/.config/omarchy/burnin-guard.json"

  function applySettings(raw) {
    try {
      var c = JSON.parse(raw)
      if (typeof c.intervalSeconds === "number") intervalSeconds = Math.max(5, c.intervalSeconds)
      if (typeof c.durationMs === "number") durationMs = Math.max(200, c.durationMs)
      if (typeof c.waveWidth === "number") waveWidth = Math.max(40, c.waveWidth)
      if (typeof c.color === "string") waveColor = c.color
      if (typeof c.opacity === "number") waveOpacity = Math.max(0, Math.min(1, c.opacity))
      if (typeof c.height === "number") barHeight = c.height
    } catch (e) {
      console.warn("burnin-guard: bad settings json: " + e)
    }
  }

  FileView {
    id: settings
    path: root.settingsPath
    watchChanges: true
    onLoaded: root.applySettings(text())
    onFileChanged: reload()
  }

  Variants {
    model: Quickshell.screens
    delegate: PanelWindow {
      required property var modelData
      screen: modelData
      anchors {
        top: true
        left: true
        right: true
      }
      implicitHeight: root.barHeight
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      mask: Region {}

      Rectangle {
        id: wave
        height: parent.height
        width: root.waveWidth
        x: -width
        opacity: 0

        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0.0; color: Qt.rgba(root.waveColor.r, root.waveColor.g, root.waveColor.b, 0) }
          GradientStop { position: 0.5; color: Qt.rgba(root.waveColor.r, root.waveColor.g, root.waveColor.b, root.waveOpacity) }
          GradientStop { position: 1.0; color: Qt.rgba(root.waveColor.r, root.waveColor.g, root.waveColor.b, 0) }
        }

        // Таймер запускает проход; окно прозрачно вне волны (нет лишних кадров).
        Timer {
          interval: root.intervalSeconds * 1000
          running: true
          repeat: true
          triggeredOnStart: true
          onTriggered: {
            wave.opacity = root.waveOpacity
            sweep.restart()
          }
        }

        NumberAnimation {
          id: sweep
          target: wave
          property: "x"
          from: -root.waveWidth
          to: wave.parent.width
          duration: root.durationMs
          easing.type: Easing.InOutSine
          onStopped: wave.opacity = 0
        }
      }
    }
  }
}
