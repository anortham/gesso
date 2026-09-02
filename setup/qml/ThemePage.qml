import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.Page {
  id: page

  title: "Theme"

  property var themeNames: []
  property string currentTheme: ""
  property string selectedTheme: ""
  property string errorText: ""
  property bool busy: false

  Component.onCompleted: loadThemes()

  function loadThemes() {
    errorText = ""

    var listResult = gessoCli.run(["theme", "list"])
    if (listResult.exitCode != 0) {
      errorText = listResult.stderr
      themeNames = []
    } else {
      var names = []
      var lines = listResult.stdout.split("\n")
      var i
      for (i = 0; i < lines.length; i++) {
        var line = lines[i].trim()
        if (line.length > 0)
          names.push(line)
      }
      themeNames = names
    }

    var currentResult = gessoCli.run(["theme", "current"])
    if (currentResult.exitCode != 0) {
      if (errorText.length === 0)
        errorText = currentResult.stderr
    } else {
      currentTheme = currentResult.stdout.trim()
    }

    if (themeNames.indexOf(selectedTheme) < 0) {
      if (themeNames.indexOf(currentTheme) >= 0)
        selectedTheme = currentTheme
      else if (themeNames.length > 0)
        selectedTheme = themeNames[0]
      else
        selectedTheme = ""
    }
  }

  function applySelected() {
    if (page.busy || gessoCli.busy)
      return
    errorText = ""
    if (selectedTheme.length === 0)
      return

    page.busy = true
    gessoCli.runAsync(["theme", "set", selectedTheme])
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
      page.loadThemes()
    }
  }

  ColumnLayout {
    anchors.fill: parent

    Kirigami.InlineMessage {
      Layout.fillWidth: true
      visible: page.errorText.length > 0
      type: Kirigami.MessageType.Error
      text: page.errorText
    }

    Controls.Label {
      Layout.fillWidth: true
      text: "Current: " + page.currentTheme
    }

    ListView {
      id: themeList
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      model: page.themeNames
      delegate: Controls.ItemDelegate {
        width: ListView.view.width
        text: modelData
        highlighted: page.selectedTheme === modelData
        onClicked: page.selectedTheme = modelData
      }
    }

    Controls.Button {
      Layout.alignment: Qt.AlignRight
      text: "Apply"
      enabled: page.themeNames.length > 0 && !page.busy && !gessoCli.busy
      onClicked: page.applySelected()
    }
  }
}
