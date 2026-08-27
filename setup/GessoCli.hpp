#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantMap>

class GessoCli : public QObject
{
  Q_OBJECT

public:
  explicit GessoCli(QObject *parent = nullptr);

  Q_INVOKABLE QVariantMap run(const QStringList &args);
  Q_INVOKABLE QVariantMap runBinary(const QString &program, const QStringList &args);
};
