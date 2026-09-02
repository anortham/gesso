import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
  id: page

  title: "Install"

  property var apps: []
  property string errorText: ""
  property bool busy: false

  Component.onCompleted: loadApps()

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

  function parseRows(result) {
    if (recordError(result))
      return []
    try {
      return JSON.parse(result.stdout)
    } catch (e) {
      if (errorText.length === 0)
        errorText = "Could not read the app catalog."
      return []
    }
  }

  function containsId(list, id) {
    var i
    for (i = 0; i < list.length; i++) {
      if (list[i].id === id)
        return true
    }
    return false
  }

  function loadApps() {
    errorText = ""
    var kinds = ["browser", "terminal", "editor"]
    var next = []
    var k
    for (k = 0; k < kinds.length; k++) {
      var rows = parseRows(gessoCli.runBinary("gesso-catalog-get", ["--json", "--kind", kinds[k]]))
      if (rows.length === 0)
        continue
      var presentResult = gessoCli.runBinary("gesso-app-present", ["--list", "--kind", kinds[k]])
      var present = recordError(presentResult) ? [] : stdoutLines(presentResult.stdout)
      var i
      for (i = 0; i < rows.length; i++) {
        if (containsId(next, rows[i].id))
          continue
        next.push({
          id: rows[i].id,
          label: rows[i].label ? rows[i].label : rows[i].id,
          present: present.indexOf(rows[i].id) >= 0
        })
      }
    }
    apps = next
  }

  function installApp(id) {
    if (page.busy || gessoCli.busy)
      return
    errorText = ""
    page.busy = true
    gessoCli.runAsync(["pkg", "add", id])
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
      page.loadApps()
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

    Repeater {
      model: page.apps
      delegate: RowLayout {
        Layout.fillWidth: true
        opacity: modelData.present ? 0.5 : 1.0

        Controls.Label {
          Layout.fillWidth: true
          text: modelData.label
        }

        Controls.Button {
          text: "Install"
          enabled: !modelData.present && !page.busy && !gessoCli.busy
          onClicked: page.installApp(modelData.id)
        }
      }
    }
  }
}
