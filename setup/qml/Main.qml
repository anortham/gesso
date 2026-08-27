import QtQuick
import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
  id: root

  title: "Gesso Setup"
  width: 720
  height: 520
  minimumWidth: 640
  minimumHeight: 400

  property int currentPage: 0

  pageStack.initialPage: themePage
  pageStack.defaultColumnWidth: root.width

  footer: Kirigami.NavigationTabBar {
    actions: [
      Kirigami.Action {
        text: "Theme"
        icon.name: "preferences-desktop-theme"
        checked: root.currentPage === 0
        onTriggered: root.showPage(0, themePage)
      },
      Kirigami.Action {
        text: "Defaults"
        icon.name: "preferences-desktop-default-applications"
        checked: root.currentPage === 1
        onTriggered: root.showPage(1, defaultsPage)
      },
      Kirigami.Action {
        text: "Agents"
        icon.name: "applications-development"
        checked: root.currentPage === 2
        onTriggered: root.showPage(2, agentsPage)
      },
      Kirigami.Action {
        text: "Install"
        icon.name: "install"
        checked: root.currentPage === 3
        onTriggered: root.showPage(3, installPage)
      }
    ]
  }

  Component {
    id: themePage
    Kirigami.Page {
      title: "Theme"
    }
  }

  Component {
    id: defaultsPage
    Kirigami.Page {
      title: "Defaults"
    }
  }

  Component {
    id: agentsPage
    Kirigami.Page {
      title: "Agents"
    }
  }

  Component {
    id: installPage
    Kirigami.Page {
      title: "Install"
    }
  }

  function showPage(index, page) {
    currentPage = index
    pageStack.replace(page)
  }
}
