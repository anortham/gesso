#include "GessoCli.hpp"

#include <QByteArray>
#include <QProcess>

GessoCli::GessoCli(QObject *parent)
  : QObject(parent)
{
}

QVariantMap GessoCli::run(const QStringList &args)
{
  return runBinary(QStringLiteral("gesso"), args);
}

QVariantMap GessoCli::runBinary(const QString &program, const QStringList &args)
{
  QProcess process;
  process.start(program, args);

  QVariantMap result;
  if (!process.waitForStarted(-1)) {
    result.insert(QStringLiteral("exitCode"), 127);
    result.insert(QStringLiteral("stdout"), QString());
    result.insert(QStringLiteral("stderr"), process.errorString());
    return result;
  }

  process.waitForFinished(-1);

  const QByteArray out = process.readAllStandardOutput();
  const QByteArray err = process.readAllStandardError();
  const int exitCode = process.exitStatus() == QProcess::NormalExit
    ? process.exitCode()
    : 1;

  result.insert(QStringLiteral("exitCode"), exitCode);
  result.insert(QStringLiteral("stdout"), QString::fromUtf8(out));
  result.insert(QStringLiteral("stderr"), QString::fromUtf8(err));
  return result;
}
