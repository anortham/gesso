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

    var rows = parseRows(gessoCli.runBinary("gesso-catalog-get", ["--json", "--kind", kind]))
    var presentResult = gessoCli.runBinary("gesso-app-present", ["--list", "--kind", kind])
    var present = recordError(presentResult) ? [] : stdoutLines(presentResult.stdout)
    var i
    for (i = 0; i < rows.length; i++) {
      group.apps.push({
        id: rows[i].id,
        label: rows[i].label ? rows[i].label : rows[i].id,
        present: present.indexOf(rows[i].id) >= 0
      })
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
          text: "Current: " + groupBox.group.current
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
