/*
 * Schiefer – Inhalt eines Ordners für die Ordner-Schublade
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
#include "schieferfolder.h"

#include <KDesktopFile>
#include <KDirLister>
#include <KDirModel>
#include <KFileItem>
#include <KIO/Global>

#include <QDir>
#include <QStandardPaths>

SchieferFolder::SchieferFolder(QObject *parent)
    : KDirSortFilterProxyModel(parent)
    , m_dirModel(new KDirModel(this))
{
    m_dirModel->dirLister()->setAutoErrorHandlingEnabled(false);
    setSourceModel(m_dirModel);
    setSortFoldersFirst(true);
    setSortCaseSensitivity(Qt::CaseInsensitive);
    sort(KDirModel::Name, Qt::AscendingOrder);
    connect(this, &QAbstractItemModel::rowsInserted, this, &SchieferFolder::countChanged);
    connect(this, &QAbstractItemModel::rowsRemoved, this, &SchieferFolder::countChanged);
    connect(this, &QAbstractItemModel::modelReset, this, &SchieferFolder::countChanged);
}

QUrl SchieferFolder::url() const
{
    return m_url;
}

void SchieferFolder::setUrl(const QUrl &rawUrl)
{
    QUrl url = rawUrl;
    // „~/…“ und nackte Pfade zulassen
    if (url.scheme().isEmpty()) {
        QString path = url.path();
        if (path.startsWith(QLatin1Char('~'))) {
            path = QDir::homePath() + path.mid(1);
        }
        url = QUrl::fromLocalFile(path);
    }
    if (url == m_url) {
        return;
    }
    m_url = url;
    if (m_url.isValid()) {
        m_dirModel->dirLister()->openUrl(m_url);
    } else {
        m_dirModel->dirLister()->stop();
        m_dirModel->dirLister()->openUrl(QUrl());
    }
    Q_EMIT urlChanged();
}

int SchieferFolder::count() const
{
    return rowCount();
}

QString SchieferFolder::folderName() const
{
    if (!m_url.isValid()) {
        return {};
    }
    if (m_url.isLocalFile()) {
        const QString path = QDir::cleanPath(m_url.toLocalFile());
        if (path == QDir::cleanPath(QStandardPaths::writableLocation(QStandardPaths::DesktopLocation))) {
            // Name des Schreibtischs wie in Dolphins Orte-Leiste
            return QDir(path).dirName();
        }
        if (path == QDir::homePath()) {
            return QStringLiteral("Persönlicher Ordner");
        }
    }
    const QString name = m_url.fileName();
    return name.isEmpty() ? m_url.toDisplayString(QUrl::PreferLocalFile) : name;
}

QString SchieferFolder::folderIcon() const
{
    if (!m_url.isValid()) {
        return QStringLiteral("folder");
    }
    return KIO::iconNameForUrl(m_url);
}

QHash<int, QByteArray> SchieferFolder::roleNames() const
{
    return {
        {NameRole, QByteArrayLiteral("name")},
        {IconRole, QByteArrayLiteral("iconName")},
        {UrlRole, QByteArrayLiteral("url")},
        {IsDirRole, QByteArrayLiteral("isDir")},
        {DetailRole, QByteArrayLiteral("detail")},
    };
}

QVariant SchieferFolder::data(const QModelIndex &index, int role) const
{
    if (role < NameRole) {
        return KDirSortFilterProxyModel::data(index, role);
    }
    const KFileItem item = KDirSortFilterProxyModel::data(index, KDirModel::FileItemRole).value<KFileItem>();
    if (item.isNull()) {
        return {};
    }
    // Starter (.desktop) mit ihrem eigentlichen Namen und Symbol
    const bool desktopFile = item.isDesktopFile();
    switch (role) {
    case NameRole:
        if (desktopFile) {
            const QString n = KDesktopFile(item.localPath()).readName();
            if (!n.isEmpty()) {
                return n;
            }
        }
        return item.text();
    case IconRole:
        if (desktopFile) {
            const QString i = KDesktopFile(item.localPath()).readIcon();
            if (!i.isEmpty()) {
                return i;
            }
        }
        return item.iconName();
    case UrlRole:
        return item.url().toString();
    case IsDirRole:
        return item.isDir();
    case DetailRole:
        if (item.isDir()) {
            return QString();
        }
        if (desktopFile) {
            // Starter: Beschreibung statt „Desktop-Datei“
            const KDesktopFile f(item.localPath());
            const QString g = f.readGenericName();
            return g.isEmpty() ? f.readComment() : g;
        }
        return item.mimeComment();
    }
    return {};
}
