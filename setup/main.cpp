#include "GessoCli.hpp"

#include <QCoreApplication>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QUrl>
#include <QtQml>

int main(int argc, char *argv[])
{
  QGuiApplication app(argc, argv);
  app.setApplicationName(QStringLiteral("gesso-setup"));
  app.setOrganizationName(QStringLiteral("gesso"));
  app.setDesktopFileName(QStringLiteral("org.gesso.setup"));

  if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE")) {
    QQuickStyle::setStyle(QStringLiteral("org.kde.desktop"));
  }

  GessoCli cli;
  qmlRegisterSingletonInstance("org.gesso.setup", 1, 0, "Cli", &cli);

  QQmlApplicationEngine engine;
  engine.rootContext()->setContextProperty(QStringLiteral("gessoCli"), &cli);

  const QUrl url(QStringLiteral("qrc:/qml/Main.qml"));
  QObject::connect(
    &engine,
    &QQmlApplicationEngine::objectCreated,
    &app,
    [url](QObject *obj, const QUrl &objUrl) {
      if (!obj && url == objUrl) {
        QCoreApplication::exit(1);
      }
    },
    Qt::QueuedConnection);
  engine.load(url);

  if (engine.rootObjects().isEmpty()) {
    return 1;
  }

  return app.exec();
}
