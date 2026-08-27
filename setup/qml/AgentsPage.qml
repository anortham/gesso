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

  Component.onCompleted: loadAgents()

  // Hidden helpers are not routed as `gesso agent-get`.
  // gessoCli.run(["default", "agent", id]) vs
  // gessoCli.runBinary("gesso-agent-get", ["--list"])

  function stdoutLines(text) {
    var lines = []
    var raw = text.split("\n")
    var i
    for (i = 0; i < raw.length; i++) {
      var line = raw[i].trim()
      if (line.length > 0)
        lines.push(line)
    }
    return lines
  }

  function recordError(result) {
    if (result.exitCode == 0)
      return false
    if (errorText.length === 0)
      errorText = result.stderr
    return true
  }

  function loadAgent(id) {
    var agent = {
      id: id,
      label: id
    }

    var labelResult = gessoCli.runBinary("gesso-agent-get", [id, "label"])
    if (!recordError(labelResult)) {
      var label = labelResult.stdout.trim()
      if (label.length > 0)
        agent.label = label
    }

    return agent
  }

  function loadAgents() {
    errorText = ""
    var next = []

    var idsResult = gessoCli.runBinary("gesso-agent-get", ["--list"])
    if (!recordError(idsResult)) {
      var ids = stdoutLines(idsResult.stdout)
      var i
      for (i = 0; i < ids.length; i++)
        next.push(loadAgent(ids[i]))
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
    errorText = ""
    if (selected.length === 0)
      return

    var result = gessoCli.run(["default", "agent", selected])
    if (result.exitCode != 0) {
      errorText = result.stderr
      return
    }
    loadAgents()
  }

  function launchAgent() {
    errorText = ""
    bannerText = ""
    var presentResult = gessoCli.runBinary("gesso-cmd-present", ["konsole"])
    if (presentResult.exitCode == 0) {
      var result = gessoCli.runBinary("konsole", ["-e", "gesso", "agent"])
      if (result.exitCode != 0)
        errorText = result.stderr
      return
    }
    bannerText = "Konsole is not installed. Run gesso agent in a terminal."
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
      text: page.current
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
        onClicked: page.launchAgent()
      }

      Item {
        Layout.fillWidth: true
      }

      Controls.Button {
        text: "Set default"
        enabled: page.agents.length > 0
        onClicked: page.applyDefault()
      }
    }
  }
}
