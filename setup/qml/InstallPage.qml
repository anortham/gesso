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

  // Hidden helpers are not routed as `gesso catalog-get`.
  // gessoCli.run(["pkg", "add", id]) vs
  // gessoCli.runBinary("gesso-catalog-get", ["--kind", "browser"])

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
      var idsResult = gessoCli.runBinary("gesso-catalog-get", ["--kind", kinds[k]])
      if (recordError(idsResult))
        continue
      var ids = stdoutLines(idsResult.stdout)
      var i
      for (i = 0; i < ids.length; i++) {
        if (containsId(next, ids[i]))
          continue
        next.push(loadApp(ids[i]))
      }
    }
    apps = next
  }

  function loadApp(id) {
    var app = {
      id: id,
      label: id,
      present: false
    }

    var labelResult = gessoCli.runBinary("gesso-catalog-get", [id, "label"])
    if (!recordError(labelResult)) {
      var label = labelResult.stdout.trim()
      if (label.length > 0)
        app.label = label
    }

    var presentResult = gessoCli.runBinary("gesso-app-present", [id])
    app.present = presentResult.exitCode == 0

    return app
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
