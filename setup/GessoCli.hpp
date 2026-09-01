#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantMap>

class QProcess;

class GessoCli : public QObject
{
  Q_OBJECT
  Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
  explicit GessoCli(QObject *parent = nullptr);

  bool busy() const;

  Q_INVOKABLE QVariantMap run(const QStringList &args);
  Q_INVOKABLE QVariantMap runBinary(const QString &program, const QStringList &args);
  Q_INVOKABLE void runAsync(const QStringList &args);
  Q_INVOKABLE void runBinaryAsync(const QString &program, const QStringList &args);
  Q_INVOKABLE bool startDetached(const QString &program, const QStringList &args);

Q_SIGNALS:
  void finished(const QVariantMap &result);
  void busyChanged();

private:
  QProcess *m_process = nullptr;
};
