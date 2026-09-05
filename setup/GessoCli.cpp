#include "GessoCli.hpp"

#include <QByteArray>
#include <QEventLoop>
#include <QJSEngine>
#include <QProcess>
#include <QTimer>

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

GessoCli::~GessoCli()
{
  if (m_activeMutationProcess) {
    m_activeMutationProcess->disconnect(this);
    m_activeMutationProcess->kill();
  }
  for (auto it = m_activeQueries.cbegin(); it != m_activeQueries.cend(); ++it) {
    QProcess *proc = it.key();
    proc->disconnect(this);
    proc->kill();
  }
  m_activeQueries.clear();
  m_mutationQueue.clear();
}

bool GessoCli::busy() const
{
  return m_activeMutationProcess != nullptr || !m_mutationQueue.isEmpty();
}

QVariantMap GessoCli::run(const QStringList &args)
{
  return runBinary(QStringLiteral("gesso"), args);
}

QVariantMap GessoCli::runBinary(const QString &program, const QStringList &args)
{
  QProcess process;
  QEventLoop loop;
  QTimer timer;
  timer.setSingleShot(true);

  QObject::connect(&process, &QProcess::finished, &loop, &QEventLoop::quit);
  QObject::connect(&process, &QProcess::errorOccurred, &loop, &QEventLoop::quit);
  QObject::connect(&timer, &QTimer::timeout, &loop, &QEventLoop::quit);

  process.start(program, args);
  timer.start(30000);
  loop.exec();

  if (timer.isActive()) {
    timer.stop();
  } else {
    process.kill();
    return makeResult(1,
                      QString::fromUtf8(process.readAllStandardOutput()),
                      QStringLiteral("Process timed out"));
  }

  if (process.error() == QProcess::FailedToStart) {
    return makeResult(127, QString(), process.errorString());
  }

  const int exitCode = process.exitStatus() == QProcess::NormalExit
    ? process.exitCode()
    : 1;
  return makeResult(exitCode,
                    QString::fromUtf8(process.readAllStandardOutput()),
                    QString::fromUtf8(process.readAllStandardError()));
}

int GessoCli::runAsync(const QStringList &args, const QJSValue &callback, bool isMutation)
{
  return runBinaryAsync(QStringLiteral("gesso"), args, callback, isMutation);
}

int GessoCli::runBinaryAsync(const QString &program, const QStringList &args, const QJSValue &callback, bool isMutation)
{
  GessoCliRequest req;
  req.requestId = 0;
  req.isMutation = isMutation;
  req.program = program;
  req.args = args;
  req.callback = callback;
  return startAsyncRequest(req);
}

int GessoCli::runQueryAsync(const QStringList &args, const QJSValue &callback)
{
  return runBinaryQueryAsync(QStringLiteral("gesso"), args, callback);
}

int GessoCli::runBinaryQueryAsync(const QString &program, const QStringList &args, const QJSValue &callback)
{
  return runBinaryAsync(program, args, callback, false);
}

int GessoCli::runCommandAsync(int requestId, const QStringList &args, const QJSValue &callback, bool isMutation)
{
  return runBinaryCommandAsync(requestId, QStringLiteral("gesso"), args, callback, isMutation);
}

int GessoCli::runCommandAsync(const QStringList &args, const QJSValue &callback, bool isMutation)
{
  return runCommandAsync(0, args, callback, isMutation);
}

int GessoCli::runBinaryCommandAsync(int requestId, const QString &program, const QStringList &args, const QJSValue &callback, bool isMutation)
{
  GessoCliRequest req;
  req.requestId = requestId;
  req.isMutation = isMutation;
  req.program = program;
  req.args = args;
  req.callback = callback;
  return startAsyncRequest(req);
}

bool GessoCli::startDetached(const QString &program, const QStringList &args)
{
  return QProcess::startDetached(program, args);
}

int GessoCli::startAsyncRequest(GessoCliRequest req)
{
  if (req.requestId <= 0) {
    req.requestId = ++m_nextRequestId;
  } else if (req.requestId >= m_nextRequestId) {
    m_nextRequestId = req.requestId;
  }

  if (req.isMutation) {
    if (m_activeMutationProcess != nullptr) {
      m_mutationQueue.append(req);
      return req.requestId;
    }
    executeMutation(req);
    return req.requestId;
  }

  executeQuery(req);
  return req.requestId;
}

void GessoCli::executeMutation(const GessoCliRequest &req)
{
  m_activeMutationRequest = req;
  auto *process = new QProcess(this);
  m_activeMutationProcess = process;
  Q_EMIT busyChanged();

  auto handleFinished = [this, process, req](int exitCode, const QString &out, const QString &err) {
    if (m_activeMutationProcess != process)
      return;

    const QVariantMap result = makeResult(exitCode, out, err);

    m_activeMutationProcess = nullptr;
    process->deleteLater();

    invokeCallback(req.callback, result);
    Q_EMIT commandFinished(req.requestId, result);
    Q_EMIT finished(result);

    if (!m_mutationQueue.isEmpty()) {
      GessoCliRequest nextReq = m_mutationQueue.takeFirst();
      executeMutation(nextReq);
    } else {
      Q_EMIT busyChanged();
    }
  };

  QObject::connect(process, &QProcess::finished, this,
    [handleFinished, process](int exitCode, QProcess::ExitStatus status) {
      const int code = status == QProcess::NormalExit ? exitCode : 1;
      const QString out = QString::fromUtf8(process->readAllStandardOutput());
      const QString err = QString::fromUtf8(process->readAllStandardError());
      handleFinished(code, out, err);
    });

  QObject::connect(process, &QProcess::errorOccurred, this,
    [handleFinished, process](QProcess::ProcessError error) {
      if (error != QProcess::FailedToStart)
        return;
      handleFinished(127, QString(), process->errorString());
    });

  process->start(req.program, req.args);
}

void GessoCli::executeQuery(const GessoCliRequest &req)
{
  auto *process = new QProcess(this);
  m_activeQueries.insert(process, req);

  auto handleFinished = [this, process](int exitCode, const QString &out, const QString &err) {
    if (!m_activeQueries.contains(process))
      return;

    const GessoCliRequest req = m_activeQueries.take(process);
    process->deleteLater();

    const QVariantMap result = makeResult(exitCode, out, err);

    invokeCallback(req.callback, result);
    Q_EMIT commandFinished(req.requestId, result);
  };

  QObject::connect(process, &QProcess::finished, this,
    [handleFinished, process](int exitCode, QProcess::ExitStatus status) {
      const int code = status == QProcess::NormalExit ? exitCode : 1;
      const QString out = QString::fromUtf8(process->readAllStandardOutput());
      const QString err = QString::fromUtf8(process->readAllStandardError());
      handleFinished(code, out, err);
    });

  QObject::connect(process, &QProcess::errorOccurred, this,
    [handleFinished, process](QProcess::ProcessError error) {
      if (error != QProcess::FailedToStart)
        return;
      handleFinished(127, QString(), process->errorString());
    });

  process->start(req.program, req.args);
}

void GessoCli::invokeCallback(const QJSValue &callback, const QVariantMap &result)
{
  if (!callback.isCallable()) {
    return;
  }

  QJSEngine *engine = qjsEngine(this);
  if (engine) {
    QJSValue arg = engine->toScriptValue(result);
    QJSValue cb = callback;
    cb.call(QJSValueList{arg});
  } else {
    QJSValue cb = callback;
    cb.call();
  }
}

