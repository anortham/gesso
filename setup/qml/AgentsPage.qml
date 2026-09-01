import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
  id: page

  title: "Agents"

  property var agents: []
  property string current: "unset"
  property string selected: ""
  property string errorText: ""
  property string bannerText: ""
  property bool busy: false

  Component.onCompleted: loadAgents()

  function recordError(result) {
    if (result.exitCode == 0)
      return false
    if (errorText.length === 0)
      errorText = result.stderr
    return true
  }

  function parseRows(result) {
    if (recordError(result))
      return []
    try {
      return JSON.parse(result.stdout)
    } catch (e) {
      if (errorText.length === 0)
        errorText = "Could not read the agent catalog."
      return []
    }
  }

  function loadAgents() {
    errorText = ""
    var next = []

    var rows = parseRows(gessoCli.runBinary("gesso-agent-get", ["--json"]))
    var i
    for (i = 0; i < rows.length; i++) {
      next.push({
        id: rows[i].id,
        label: rows[i].label ? rows[i].label : rows[i].id
      })
    }

    var currentResult = gessoCli.run(["default", "agent"])
    if (!recordError(currentResult))
      current = currentResult.stdout.trim()
    else
      current = "unset"

    var selected = ""
    var j
    for (j = 0; j < next.length; j++) {
      if (next[j].id === current) {
        selected = current
        break
      }
    }
    if (selected.length === 0 && next.length > 0)
      selected = next[0].id
    page.selected = selected
    agents = next
  }

  function applyDefault() {
    if (page.busy || gessoCli.busy)
      return
    errorText = ""
    if (selected.length === 0)
      return

    page.busy = true
    gessoCli.runAsync(["default", "agent", selected])
  }

  function launchAgent() {
    if (page.busy || gessoCli.busy || current === "unset")
      return
    errorText = ""
    bannerText = ""
    var presentResult = gessoCli.runBinary("gesso-app-present", ["konsole"])
    if (presentResult.exitCode == 0) {
      if (!gessoCli.startDetached("konsole", ["--hold", "-e", "gesso", "agent"]))
        errorText = "Failed to start Konsole."
      return
    }
    bannerText = "Konsole is not installed. Run gesso agent in a terminal."
  }

  Connections {
    target: gessoCli
    enabled: page.busy
    function onFinished(result) {
      page.busy = false
      if (result.exitCode != 0) {
        page.errorText = result.stderr
        return
      }
      page.loadAgents()
    }
  }

  ColumnLayout {
    width: parent.width

    Kirigami.InlineMessage {
      Layout.fillWidth: true
      visible: page.errorText.length > 0
      type: Kirigami.MessageType.Error
      text: page.errorText
    }

    Kirigami.InlineMessage {
      Layout.fillWidth: true
      visible: page.bannerText.length > 0
      type: Kirigami.MessageType.Information
      text: page.bannerText
    }

    Controls.Label {
      Layout.fillWidth: true
      text: "Current: " + page.current
    }

    Repeater {
      model: page.agents
      delegate: Controls.ItemDelegate {
        Layout.fillWidth: true
        text: modelData.label
        highlighted: page.selected === modelData.id
        onClicked: page.selected = modelData.id
      }
    }

    RowLayout {
      Layout.fillWidth: true

      Controls.Button {
        text: "Launch"
        enabled: page.current !== "unset" && !page.busy && !gessoCli.busy
        onClicked: page.launchAgent()
      }

      Item {
        Layout.fillWidth: true
      }

      Controls.Button {
        text: "Set default"
        enabled: page.agents.length > 0 && !page.busy && !gessoCli.busy
        onClicked: page.applyDefault()
      }
    }
  }
}
