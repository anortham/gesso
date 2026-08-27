#include "GessoCli.hpp"

#include <QByteArray>
#include <QProcess>

namespace {

QVariantMap makeResult(int exitCode, const QString &out, const QString &err)
{
  QVariantMap result;
  result.insert(QStringLiteral("exitCode"), exitCode);
  result.insert(QStringLiteral("stdout"), out);
  result.insert(QStringLiteral("stderr"), err);
  return result;
}

}

GessoCli::GessoCli(QObject *parent)
  : QObject(parent)
{
}

bool GessoCli::busy() const
{
  return m_process != nullptr;
}

QVariantMap GessoCli::run(const QStringList &args)
{
  return runBinary(QStringLiteral("gesso"), args);
}

QVariantMap GessoCli::runBinary(const QString &program, const QStringList &args)
{
  QProcess process;
  process.start(program, args);

  if (!process.waitForStarted(30000)) {
    return makeResult(127, QString(), process.errorString());
  }

  if (!process.waitForFinished(30000)) {
    process.kill();
    process.waitForFinished(30000);
    return makeResult(1,
                      QString::fromUtf8(process.readAllStandardOutput()),
                      process.errorString());
  }

  const int exitCode = process.exitStatus() == QProcess::NormalExit
    ? process.exitCode()
    : 1;
  return makeResult(exitCode,
                    QString::fromUtf8(process.readAllStandardOutput()),
                    QString::fromUtf8(process.readAllStandardError()));
}

void GessoCli::runAsync(const QStringList &args)
{
  runBinaryAsync(QStringLiteral("gesso"), args);
}

void GessoCli::runBinaryAsync(const QString &program, const QStringList &args)
{
  if (m_process)
    return;

  auto *process = new QProcess(this);
  m_process = process;
  emit busyChanged();

  QObject::connect(process, &QProcess::finished, this,
    [this, process](int exitCode, QProcess::ExitStatus status) {
      if (m_process != process)
        return;
      const int code = status == QProcess::NormalExit ? exitCode : 1;
      const QString out = QString::fromUtf8(process->readAllStandardOutput());
      const QString err = QString::fromUtf8(process->readAllStandardError());
      m_process = nullptr;
      process->deleteLater();
      emit finished(makeResult(code, out, err));
      emit busyChanged();
    });

  QObject::connect(process, &QProcess::errorOccurred, this,
    [this, process](QProcess::ProcessError error) {
      if (m_process != process)
        return;
      if (error != QProcess::FailedToStart)
        return;
      const QString err = process->errorString();
      m_process = nullptr;
      process->deleteLater();
      emit finished(makeResult(127, QString(), err));
      emit busyChanged();
    });

  process->start(program, args);
}

bool GessoCli::startDetached(const QString &program, const QStringList &args)
{
  return QProcess::startDetached(program, args);
}
