/*
 * Schiefer – Inhalt eines Ordners für die Ordner-Schublade
 * (KDirModel, Ordner zuerst und natürlich sortiert wie in Dolphin)
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
#pragma once

#include <KDirSortFilterProxyModel>
#include <QUrl>
#include <qqmlregistration.h>

class KDirModel;

class SchieferFolder : public KDirSortFilterProxyModel
{
    Q_OBJECT
    QML_NAMED_ELEMENT(FolderModel)

    Q_PROPERTY(QUrl url READ url WRITE setUrl NOTIFY urlChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    // Name und Symbol des Ordners selbst (z. B. „Schreibtisch“, user-desktop)
    Q_PROPERTY(QString folderName READ folderName NOTIFY urlChanged)
    Q_PROPERTY(QString folderIcon READ folderIcon NOTIFY urlChanged)

public:
    enum Roles {
        NameRole = Qt::UserRole + 100,
        IconRole,
        UrlRole,
        IsDirRole,
        DetailRole,
    };

    explicit SchieferFolder(QObject *parent = nullptr);

    QUrl url() const;
    void setUrl(const QUrl &url);
    int count() const;
    QString folderName() const;
    QString folderIcon() const;

    QHash<int, QByteArray> roleNames() const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;

Q_SIGNALS:
    void urlChanged();
    void countChanged();

private:
    KDirModel *m_dirModel;
    QUrl m_url;
};
