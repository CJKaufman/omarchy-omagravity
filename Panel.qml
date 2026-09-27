import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "cjkaufman.omagravity"
  ipcTarget: "cjkaufman.omagravity"
  manageIpc: false

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.runHelper(["sync"]) }
    function launch(): void { root.runHelper(["launch"]) }
    function setDefault(): void { root.runHelper(["set-default"]) }
  }

  // Nerd Font Glyphs
  readonly property string glyphAgy: "󱚣"
  readonly property string glyphTerminal: "󰆍"
  readonly property string glyphHerdr: "󱂬"
  readonly property string glyphContinue: "󰁯"
  readonly property string glyphIde: "󰨞"
  readonly property string glyphScratchpad: "󰅪"
  readonly property string glyphRefresh: "󰑐"
  readonly property string glyphCheck: "󰄬"
  readonly property string glyphHistory: "󰋚"
  readonly property string glyphSparkle: "󰚩"
  readonly property string glyphKey: "󰌌"
  readonly property string glyphFolder: "󰉋"

  readonly property string helper: Qt.resolvedUrl("bin/omagravity").toString().replace("file://", "")

  // Theme & Styling
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color accent: Color.accent
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color successColor: "#4EBA6F"
  readonly property color dim: Qt.darker(foreground, 1.6)
  readonly property color subtleBg: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.08)
  readonly property color cardBg: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.04)
  readonly property color borderCol: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.12)
  
  // Clean font separation: proportional UI font for text, monospace for keybinds & code
  readonly property string uiFont: Style.font.family
  readonly property string monoFont: bar ? bar.fontFamily : Style.font.family

  // Plugin Settings
  readonly property bool showOnBar: Boolean(setting("showOnBar", true))
  readonly property string launchMode: String(setting("launchMode", "terminal"))
  readonly property string preferredTerminal: String(setting("preferredTerminal", "foot"))
  readonly property string defaultWorkDir: String(setting("defaultWorkDir", "work"))
  readonly property bool skipPermissions: Boolean(setting("skipPermissions", true))
  readonly property int recentLimit: Math.max(3, Number(setting("recentLimit", 5)))
  readonly property int refreshIntervalSec: Math.max(5, Number(setting("refreshIntervalSec", 15)))

  // Live State
  property bool agyInstalled: true
  property string agyVersion: "Antigravity CLI"
  property bool isDefaultAgent: true
  property var recentSessions: []
  property string lastResumedId: ""

  // Reactive State Watcher
  FileView {
    id: stateWatcher
    path: Quickshell.env("HOME") + "/.local/state/omarchy/cjkaufman.omagravity/state.json"
    watchChanges: true
    printErrors: false
    onLoaded: root.parseState(text())
    onFileChanged: reload()
    Component.onCompleted: reload()
  }

  function parseState(raw) {
    try {
      if (!raw || raw.trim() === "") return
      var s = JSON.parse(raw)
      if (s.doctor && s.doctor.agy) {
        root.agyInstalled = s.doctor.agy.installed === true
        root.agyVersion = String(s.doctor.agy.version || "Antigravity CLI")
        root.isDefaultAgent = s.doctor.agy.isDefaultAgent === true
      }
      root.recentSessions = Array.isArray(s.recent_sessions) ? s.recent_sessions : []
    } catch (e) {
      console.warn("omagravity state parse error", e)
    }
  }

  // Periodic Poller
  Timer {
    interval: root.refreshIntervalSec * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.runHelper(["sync", "--limit", String(root.recentLimit)])
  }

  // Process Runner
  Process {
    id: helperProc
    onExited: function(exitCode, exitStatus) {
      stateWatcher.reload()
    }
  }

  function runHelper(args) {
    helperProc.command = [root.helper].concat(args)
    helperProc.running = true
  }

  function launchSession(extraArgs) {
    var cmd = [
      "launch",
      "--mode", root.launchMode,
      "--terminal", root.preferredTerminal,
      "--workdir", root.defaultWorkDir
    ]
    if (root.skipPermissions) {
      cmd.push("--skip-permissions")
    } else {
      cmd.push("--no-skip-permissions")
    }
    if (Array.isArray(extraArgs)) {
      cmd = cmd.concat(extraArgs)
    }
    runHelper(cmd)
    root.close()
  }

  function resumeSession(convId) {
    if (!convId) return
    root.lastResumedId = convId
    var cmd = [
      "resume",
      convId,
      "--terminal", root.preferredTerminal,
      "--workdir", root.defaultWorkDir
    ]
    if (root.skipPermissions) {
      cmd.push("--skip-permissions")
    } else {
      cmd.push("--no-skip-permissions")
    }
    runHelper(cmd)
    root.close()
  }

  // Component sizing: collapsible when showOnBar is false
  implicitWidth: root.showOnBar ? barButton.implicitWidth : 0
  implicitHeight: root.showOnBar ? barButton.implicitHeight : 0
  width: implicitWidth
  height: implicitHeight
  visible: root.showOnBar || root.opened

  // Top Bar Button
  WidgetButton {
    id: barButton
    anchors.fill: parent
    visible: root.showOnBar
    bar: root.bar
    active: root.opened
    activeColor: root.accent
    useActiveColor: true
    labelVisible: false
    hasVisualContent: true
    fixedWidth: root.showOnBar ? (barContentRow.implicitWidth + Style.space(12)) : 0

    Row {
      id: barContentRow
      anchors.centerIn: parent

      // Antigravity icon directly indicates status via color
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.glyphAgy
        font.family: root.monoFont
        font.pixelSize: Style.font.body
        color: {
          if (root.opened) return root.accent
          if (!root.agyInstalled) return root.urgent
          if (root.isDefaultAgent) return root.successColor
          return root.foreground
        }
      }
    }

    tooltipText: {
      var lines = [
        "OmaGravity: " + (root.agyInstalled ? root.agyVersion : "Not Found"),
        "Default Agent: " + (root.isDefaultAgent ? "Yes (Antigravity)" : "Other"),
        "Recent Sessions: " + root.recentSessions.length,
        "",
        "Left-Click: Open OmaGravity Panel",
        "Super+A: Quick Launch CLI"
      ]
      return lines.join("\n")
    }

    onPressed: function(btn) {
      root.toggle()
    }
  }

  // Interactive Popup Window
  KeyboardPanel {
    id: panel
    anchorItem: barButton
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(480))
    contentHeight: panel.fittedContentHeight(menuCol.implicitHeight + Style.space(20), Style.space(640))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: menuCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: menuCol
          width: parent.width
          spacing: Style.space(6)

          // 1. Hero Status Card
          Rectangle {
            width: parent.width
            implicitHeight: heroLayout.implicitHeight + Style.space(12)
            radius: 8
            color: root.cardBg
            border.color: root.borderCol
            border.width: 1

            RowLayout {
              id: heroLayout
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(8)

              // Antigravity Glyph Box
              Rectangle {
                implicitWidth: Style.space(32)
                implicitHeight: Style.space(32)
                radius: 6
                color: root.subtleBg
                border.color: root.borderCol
                border.width: 1

                Text {
                  anchors.centerIn: parent
                  text: root.glyphAgy
                  font.family: root.monoFont
                  font.pixelSize: Style.font.title
                  color: root.isDefaultAgent ? root.successColor : root.accent
                }
              }

              ColumnLayout {
                spacing: 1

                RowLayout {
                  spacing: Style.space(6)

                  Text {
                    text: "Antigravity CLI"
                    textFormat: Text.PlainText
                    font.family: root.uiFont
                    font.pixelSize: Style.font.subtitle
                    font.bold: true
                    color: root.foreground
                  }

                  Rectangle {
                    implicitWidth: Style.space(7)
                    implicitHeight: Style.space(7)
                    radius: 3.5
                    color: root.agyInstalled ? root.successColor : root.urgent
                  }

                  Text {
                    text: root.agyInstalled ? "Ready" : "Missing"
                    textFormat: Text.PlainText
                    font.family: root.uiFont
                    font.pixelSize: Style.font.caption
                    color: root.agyInstalled ? root.successColor : root.urgent
                  }
                }

                Text {
                  text: root.agyVersion
                  textFormat: Text.PlainText
                  font.family: root.uiFont
                  font.pixelSize: Style.font.caption
                  color: root.dim
                }
              }

              Item { Layout.fillWidth: true }

              // Default Agent Pill
              Rectangle {
                implicitWidth: defLabel.implicitWidth + Style.space(14)
                implicitHeight: Style.space(22)
                radius: 11
                color: root.isDefaultAgent ? Qt.rgba(78/255, 186/255, 111/255, 0.15) : root.subtleBg
                border.color: root.isDefaultAgent ? root.successColor : root.borderCol
                border.width: 1

                Text {
                  id: defLabel
                  anchors.centerIn: parent
                  text: root.isDefaultAgent ? "DEFAULT AGENT" : "SET AS DEFAULT"
                  textFormat: Text.PlainText
                  font.family: root.uiFont
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  color: root.isDefaultAgent ? root.successColor : root.dim
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.runHelper(["set-default"])
                  }
                }
              }

              // Refresh Button
              Rectangle {
                implicitWidth: Style.space(22)
                implicitHeight: Style.space(22)
                radius: 4
                color: refreshMouseArea.containsMouse ? root.subtleBg : "transparent"
                border.color: refreshMouseArea.containsMouse ? root.accent : root.borderCol
                border.width: 1

                Text {
                  anchors.centerIn: parent
                  text: root.glyphRefresh
                  font.family: root.monoFont
                  font.pixelSize: Style.font.caption
                  color: refreshMouseArea.containsMouse ? root.accent : root.foreground
                }

                MouseArea {
                  id: refreshMouseArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.runHelper(["sync", "--limit", String(root.recentLimit)])
                }
              }
            }
          }

          // 2. Quick Launch Section
          Text {
            text: "Quick Launch"
            textFormat: Text.PlainText
            font.family: root.uiFont
            font.pixelSize: Style.font.caption
            font.bold: true
            color: root.dim
          }

          GridLayout {
            width: parent.width
            columns: 2
            rowSpacing: Style.space(4)
            columnSpacing: Style.space(6)

            // Button: Launch CLI
            Rectangle {
              Layout.fillWidth: true
              implicitHeight: Style.space(28)
              radius: 6
              color: btn1Area.containsMouse ? root.subtleBg : root.cardBg
              border.color: btn1Area.containsMouse ? root.accent : root.borderCol
              border.width: 1

              RowLayout {
                anchors.centerIn: parent
                spacing: Style.space(6)
                Text {
                  text: root.glyphTerminal
                  font.family: root.monoFont
                  font.pixelSize: Style.font.bodySmall
                  color: btn1Area.containsMouse ? root.accent : root.foreground
                }
                Text {
                  text: "Interactive CLI"
                  textFormat: Text.PlainText
                  font.family: root.uiFont
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  color: root.foreground
                }
              }

              MouseArea {
                id: btn1Area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.launchSession([])
              }
            }

            // Button: Open in Herdr
            Rectangle {
              Layout.fillWidth: true
              implicitHeight: Style.space(28)
              radius: 6
              color: btn2Area.containsMouse ? root.subtleBg : root.cardBg
              border.color: btn2Area.containsMouse ? root.accent : root.borderCol
              border.width: 1

              RowLayout {
                anchors.centerIn: parent
                spacing: Style.space(6)
                Text {
                  text: root.glyphHerdr
                  font.family: root.monoFont
                  font.pixelSize: Style.font.bodySmall
                  color: btn2Area.containsMouse ? root.accent : root.foreground
                }
                Text {
                  text: "Open in Herdr"
                  textFormat: Text.PlainText
                  font.family: root.uiFont
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  color: root.foreground
                }
              }

              MouseArea {
                id: btn2Area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.runHelper(["launch", "--mode", "herdr", "--workdir", root.defaultWorkDir])
                  root.close()
                }
              }
            }

            // Button: Continue Last Session
            Rectangle {
              Layout.fillWidth: true
              implicitHeight: Style.space(28)
              radius: 6
              color: btn3Area.containsMouse ? root.subtleBg : root.cardBg
              border.color: btn3Area.containsMouse ? root.accent : root.borderCol
              border.width: 1

              RowLayout {
                anchors.centerIn: parent
                spacing: Style.space(6)
                Text {
                  text: root.glyphContinue
                  font.family: root.monoFont
                  font.pixelSize: Style.font.bodySmall
                  color: btn3Area.containsMouse ? root.accent : root.foreground
                }
                Text {
                  text: "Continue Last"
                  textFormat: Text.PlainText
                  font.family: root.uiFont
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  color: root.foreground
                }
              }

              MouseArea {
                id: btn3Area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.launchSession(["-c"])
              }
            }

            // Button: Launch Antigravity IDE
            Rectangle {
              Layout.fillWidth: true
              implicitHeight: Style.space(28)
              radius: 6
              color: btn4Area.containsMouse ? root.subtleBg : root.cardBg
              border.color: btn4Area.containsMouse ? root.accent : root.borderCol
              border.width: 1

              RowLayout {
                anchors.centerIn: parent
                spacing: Style.space(6)
                Text {
                  text: root.glyphIde
                  font.family: root.monoFont
                  font.pixelSize: Style.font.bodySmall
                  color: btn4Area.containsMouse ? root.accent : root.foreground
                }
                Text {
                  text: "Antigravity IDE"
                  textFormat: Text.PlainText
                  font.family: root.uiFont
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  color: root.foreground
                }
              }

              MouseArea {
                id: btn4Area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.runHelper(["ide", root.defaultWorkDir])
                  root.close()
                }
              }
            }
          }

          // 3. Recent Sessions Explorer Header
          RowLayout {
            width: parent.width
            Text {
              text: "Recent Conversations"
              textFormat: Text.PlainText
              font.family: root.uiFont
              font.pixelSize: Style.font.caption
              font.bold: true
              color: root.dim
            }
            Item { Layout.fillWidth: true }
            Text {
              text: root.recentSessions.length + " loaded"
              textFormat: Text.PlainText
              font.family: root.uiFont
              font.pixelSize: Style.font.caption
              color: root.dim
            }
          }

          // Recent Sessions List
          Column {
            id: sessionListCol
            width: parent.width
            spacing: Style.space(4)

            Repeater {
              model: root.recentSessions

              delegate: Rectangle {
                id: sessionCard
                width: sessionListCol.width
                implicitHeight: Style.space(38)
                radius: 6
                color: sessionMouseArea.containsMouse ? root.subtleBg : root.cardBg
                border.color: sessionMouseArea.containsMouse ? root.accent : root.borderCol
                border.width: 1

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(8)
                  anchors.rightMargin: Style.space(8)
                  spacing: Style.space(8)

                  Rectangle {
                    implicitWidth: Style.space(22)
                    implicitHeight: Style.space(22)
                    radius: 4
                    color: root.subtleBg
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                      anchors.centerIn: parent
                      text: root.glyphHistory
                      font.family: root.monoFont
                      font.pixelSize: Style.font.caption
                      color: root.dim
                    }
                  }

                  ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0

                    Text {
                      text: modelData.title || "Untitled Session"
                      textFormat: Text.PlainText
                      font.family: root.uiFont
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      color: root.foreground
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }

                    RowLayout {
                      spacing: Style.space(4)

                      Text {
                        text: modelData.last_modified || "Recent"
                        textFormat: Text.PlainText
                        font.family: root.uiFont
                        font.pixelSize: Style.font.caption
                        color: root.dim
                      }

                      Text {
                        text: "•"
                        textFormat: Text.PlainText
                        font.family: root.uiFont
                        font.pixelSize: Style.font.caption
                        color: root.dim
                      }

                      Text {
                        text: (modelData.step_count || 0) + " turns"
                        textFormat: Text.PlainText
                        font.family: root.uiFont
                        font.pixelSize: Style.font.caption
                        color: root.dim
                      }
                    }
                  }

                  // Resume Button
                  Rectangle {
                    implicitWidth: Style.space(52)
                    implicitHeight: Style.space(20)
                    radius: 4
                    color: resumeArea.containsMouse ? root.accent : root.subtleBg
                    border.color: resumeArea.containsMouse ? root.accent : root.borderCol
                    border.width: 1
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                      anchors.centerIn: parent
                      text: "Resume"
                      textFormat: Text.PlainText
                      font.family: root.uiFont
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      color: resumeArea.containsMouse ? Color.background : root.foreground
                    }

                    MouseArea {
                      id: resumeArea
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.resumeSession(modelData.id)
                    }
                  }
                }

                MouseArea {
                  id: sessionMouseArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.resumeSession(modelData.id)
                }
              }
            }

            // Empty state placeholder
            Rectangle {
              visible: root.recentSessions.length === 0
              width: sessionListCol.width
              implicitHeight: Style.space(38)
              radius: 6
              color: root.cardBg
              border.color: root.borderCol
              border.width: 1

              Text {
                anchors.centerIn: parent
                text: "No conversation history found in database"
                textFormat: Text.PlainText
                font.family: root.uiFont
                font.pixelSize: Style.font.caption
                color: root.dim
              }
            }
          }

          // 4. Keybindings Guide Card
          Rectangle {
            width: parent.width
            implicitHeight: keyCol.implicitHeight + Style.space(10)
            radius: 6
            color: root.cardBg
            border.color: root.borderCol
            border.width: 1

            ColumnLayout {
              id: keyCol
              anchors.fill: parent
              anchors.margins: Style.space(6)
              spacing: Style.space(4)

              RowLayout {
                spacing: Style.space(6)
                Text {
                  text: root.glyphKey
                  font.family: root.monoFont
                  font.pixelSize: Style.font.caption
                  color: root.accent
                }
                Text {
                  text: "Configured Keybindings"
                  textFormat: Text.PlainText
                  font.family: root.uiFont
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  color: root.foreground
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.space(4)

                // Row 1
                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(8)

                  // Key 1: Super + A
                  RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(4)
                    Rectangle {
                      implicitWidth: k1Text.implicitWidth + Style.space(8)
                      implicitHeight: Style.space(18)
                      radius: 3
                      color: root.subtleBg
                      border.color: root.borderCol
                      border.width: 1
                      Text {
                        id: k1Text
                        anchors.centerIn: parent
                        text: "Super + A"
                        font.family: root.monoFont
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: root.accent
                      }
                    }
                    Text {
                      text: "Quick Launch"
                      font.family: root.uiFont
                      font.pixelSize: Style.font.caption
                      color: root.dim
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }
                  }

                  // Key 2: Super + Shift + A
                  RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(4)
                    Rectangle {
                      implicitWidth: k2Text.implicitWidth + Style.space(8)
                      implicitHeight: Style.space(18)
                      radius: 3
                      color: root.subtleBg
                      border.color: root.borderCol
                      border.width: 1
                      Text {
                        id: k2Text
                        anchors.centerIn: parent
                        text: "Super + Shift + A"
                        font.family: root.monoFont
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: root.accent
                      }
                    }
                    Text {
                      text: "Continue Last"
                      font.family: root.uiFont
                      font.pixelSize: Style.font.caption
                      color: root.dim
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }
                  }
                }

                // Row 2
                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(8)

                  // Key 3: Super + Alt + G
                  RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(4)
                    Rectangle {
                      implicitWidth: k3Text.implicitWidth + Style.space(8)
                      implicitHeight: Style.space(18)
                      radius: 3
                      color: root.subtleBg
                      border.color: root.borderCol
                      border.width: 1
                      Text {
                        id: k3Text
                        anchors.centerIn: parent
                        text: "Super + Alt + G"
                        font.family: root.monoFont
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: root.accent
                      }
                    }
                    Text {
                      text: "OmaGravity Panel"
                      font.family: root.uiFont
                      font.pixelSize: Style.font.caption
                      color: root.dim
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }
                  }

                  // Key 4: Super + Alt + A
                  RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(4)
                    Rectangle {
                      implicitWidth: k4Text.implicitWidth + Style.space(8)
                      implicitHeight: Style.space(18)
                      radius: 3
                      color: root.subtleBg
                      border.color: root.borderCol
                      border.width: 1
                      Text {
                        id: k4Text
                        anchors.centerIn: parent
                        text: "Super + Alt + A"
                        font.family: root.monoFont
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: root.accent
                      }
                    }
                    Text {
                      text: "Desktop IDE"
                      font.family: root.uiFont
                      font.pixelSize: Style.font.caption
                      color: root.dim
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
