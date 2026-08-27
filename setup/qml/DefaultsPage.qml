import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
  id: page

  title: "Defaults"

  property var groups: []
  property string errorText: ""
  property bool busy: false

  Component.onCompleted: loadGroups()

  // Hidden helpers are not routed as `gesso catalog-get`.
  // gessoCli.run(["default", "browser", id]) vs
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

  function loadGroups() {
    errorText = ""
    var kinds = [
      { kind: "browser", title: "Browser" },
      { kind: "terminal", title: "Terminal" },
      { kind: "editor", title: "Editor" }
    ]
    var next = []
    var k
    for (k = 0; k < kinds.length; k++)
      next.push(loadKind(kinds[k].kind, kinds[k].title))
    groups = next
  }

  function loadKind(kind, title) {
    var group = {
      kind: kind,
      title: title,
      current: "unset",
      selected: "",
      apps: []
    }

    var idsResult = gessoCli.runBinary("gesso-catalog-get", ["--kind", kind])
    if (!recordError(idsResult)) {
      var ids = stdoutLines(idsResult.stdout)
      var i
      for (i = 0; i < ids.length; i++)
        group.apps.push(loadApp(ids[i]))
    }

    var currentResult = gessoCli.run(["default", kind])
    if (!recordError(currentResult))
      group.current = currentResult.stdout.trim()

    var selected = ""
    var j
    for (j = 0; j < group.apps.length; j++) {
      if (group.apps[j].id === group.current) {
        selected = group.current
        break
      }
    }
    if (selected.length === 0 && group.apps.length > 0)
      selected = group.apps[0].id
    group.selected = selected

    return group
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

  function selectApp(kind, id) {
    var next = []
    var i
    for (i = 0; i < groups.length; i++) {
      var g = groups[i]
      next.push({
        kind: g.kind,
        title: g.title,
        current: g.current,
        selected: g.kind === kind ? id : g.selected,
        apps: g.apps
      })
    }
    groups = next
  }

  function applyDefault(kind) {
    if (page.busy || gessoCli.busy)
      return
    errorText = ""
    var id = ""
    var i
    for (i = 0; i < groups.length; i++) {
      if (groups[i].kind === kind) {
        id = groups[i].selected
        break
      }
    }
    if (id.length === 0)
      return

    page.busy = true
    gessoCli.runAsync(["default", kind, id])
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
      page.loadGroups()
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
      model: page.groups
      delegate: ColumnLayout {
        id: groupBox
        Layout.fillWidth: true
        property var group: modelData

        Controls.Label {
          Layout.fillWidth: true
          text: groupBox.group.title
          font.bold: true
        }

        Controls.Label {
          Layout.fillWidth: true
          text: groupBox.group.current
        }

        Repeater {
          model: groupBox.group.apps
          delegate: Controls.ItemDelegate {
            Layout.fillWidth: true
            text: modelData.present ? modelData.label : modelData.label + " (not installed)"
            highlighted: groupBox.group.selected === modelData.id
            onClicked: page.selectApp(groupBox.group.kind, modelData.id)
          }
        }

        Controls.Button {
          Layout.alignment: Qt.AlignRight
          text: "Set default"
          enabled: groupBox.group.apps.length > 0 && !page.busy && !gessoCli.busy
          onClicked: page.applyDefault(groupBox.group.kind)
        }
      }
    }
  }
}
