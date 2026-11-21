/*
 * Schiefer: folder contents for the folder drawer
 * (KDirModel, folders first and naturally sorted as in Dolphin)
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
#pragma once

#include <KDirSortFilterProxyModel>
#include <QHash>
#include <QUrl>
#include <qqmlregistration.h>

class KDirModel;
class KFileItem;

class SchieferFolder : public KDirSortFilterProxyModel
{
    Q_OBJECT
    QML_NAMED_ELEMENT(FolderModel)

    Q_PROPERTY(QUrl url READ url WRITE setUrl NOTIFY urlChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    // name and icon of the folder itself (for example "Desktop", user-desktop)
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
    // name, icon and description of a launcher (.desktop), read once
    struct DesktopInfo {
        QString name;
        QString icon;
        QString detail;
    };
    const DesktopInfo &desktopInfo(const KFileItem &item) const;

    KDirModel *m_dirModel;
    QUrl m_url;
    // cleared as soon as the source changes (file edited, removed, relisted)
    mutable QHash<QUrl, DesktopInfo> m_desktopCache;
};
