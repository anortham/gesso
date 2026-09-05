#pragma once

#include <QHash>
#include <QJSValue>
#include <QList>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantMap>

class QProcess;

struct GessoCliRequest
{
  int requestId = 0;
  bool isMutation = false;
  QString program;
  QStringList args;
  QJSValue callback;
};

class GessoCli : public QObject
{
  Q_OBJECT
  Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
  explicit GessoCli(QObject *parent = nullptr);
  ~GessoCli() override;

  bool busy() const;

  Q_INVOKABLE QVariantMap run(const QStringList &args);
  Q_INVOKABLE QVariantMap runBinary(const QString &program, const QStringList &args);

  Q_INVOKABLE int runAsync(const QStringList &args, const QJSValue &callback = QJSValue(), bool isMutation = true);
  Q_INVOKABLE int runBinaryAsync(const QString &program, const QStringList &args, const QJSValue &callback = QJSValue(), bool isMutation = true);

  Q_INVOKABLE int runQueryAsync(const QStringList &args, const QJSValue &callback = QJSValue());
  Q_INVOKABLE int runBinaryQueryAsync(const QString &program, const QStringList &args, const QJSValue &callback = QJSValue());

  Q_INVOKABLE int runCommandAsync(int requestId, const QStringList &args, const QJSValue &callback = QJSValue(), bool isMutation = false);
  Q_INVOKABLE int runCommandAsync(const QStringList &args, const QJSValue &callback = QJSValue(), bool isMutation = false);
  Q_INVOKABLE int runBinaryCommandAsync(int requestId, const QString &program, const QStringList &args, const QJSValue &callback = QJSValue(), bool isMutation = false);

  Q_INVOKABLE bool startDetached(const QString &program, const QStringList &args);

Q_SIGNALS:
  void finished(const QVariantMap &result);
  void busyChanged();
  void commandFinished(int requestId, const QVariantMap &result);

private:
  int startAsyncRequest(GessoCliRequest req);
  void executeMutation(const GessoCliRequest &req);
  void executeQuery(const GessoCliRequest &req);
  void invokeCallback(const QJSValue &callback, const QVariantMap &result);

  int m_nextRequestId = 0;
  QProcess *m_activeMutationProcess = nullptr;
  GessoCliRequest m_activeMutationRequest;
  QList<GessoCliRequest> m_mutationQueue;
  QHash<QProcess *, GessoCliRequest> m_activeQueries;
};
