/*
 * Schiefer: folder contents for the folder drawer
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
#include "schieferfolder.h"

#include <KDesktopFile>
#include <KDirLister>
#include <KDirModel>
#include <KFileItem>
#include <KIO/Global>
#include <KLocalizedString>

#include <QDir>
#include <QFile>
#include <QStandardPaths>

#include <pwd.h>

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
    // KDirModel reports changed files through dataChanged and deleted ones through rowsRemoved
    const auto dropCache = [this]() {
        m_desktopCache.clear();
    };
    connect(m_dirModel, &QAbstractItemModel::dataChanged, this, dropCache);
    connect(m_dirModel, &QAbstractItemModel::rowsRemoved, this, dropCache);
    connect(m_dirModel, &QAbstractItemModel::modelReset, this, dropCache);
}

// turn "~", "~/...", "~name/..." and relative paths (relative to the home folder) into a URL
static QUrl urlFromUserPath(const QString &input)
{
    QString path = input;
    if (path == QLatin1String("~") || path.startsWith(QLatin1String("~/"))) {
        path = QDir::homePath() + path.mid(1);
    } else if (path.startsWith(QLatin1Char('~'))) {
        const int slash = path.indexOf(QLatin1Char('/'));
        const QString user = path.mid(1, slash < 0 ? -1 : slash - 1);
        if (const passwd *pw = getpwnam(user.toLocal8Bit().constData()); pw && pw->pw_dir) {
            path = QFile::decodeName(pw->pw_dir) + (slash < 0 ? QString() : path.mid(slash));
        } else {
            // unknown user: treat as an ordinary (relative) name
            path = QDir::home().filePath(path);
        }
    } else if (QDir::isRelativePath(path)) {
        path = QDir::home().filePath(path);
    }
    return QUrl::fromLocalFile(QDir::cleanPath(path));
}

QUrl SchieferFolder::url() const
{
    return m_url;
}

void SchieferFolder::setUrl(const QUrl &rawUrl)
{
    QUrl url = rawUrl;
    // allow "~/..." and bare paths (QUrl then keeps the text unchanged as the path)
    if (url.scheme().isEmpty() && !url.isEmpty()) {
        url = urlFromUserPath(url.path());
    }
    if (url == m_url) {
        return;
    }
    m_url = url;
    m_desktopCache.clear();
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
            // name of the desktop folder as in the Dolphin places panel
            return QDir(path).dirName();
        }
        if (path == QDir::homePath()) {
            return i18nc("@label name of the home folder (~)", "Home Folder");
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

const SchieferFolder::DesktopInfo &SchieferFolder::desktopInfo(const KFileItem &item) const
{
    auto it = m_desktopCache.constFind(item.url());
    if (it == m_desktopCache.constEnd()) {
        const KDesktopFile f(item.localPath());
        const QString generic = f.readGenericName();
        // launchers: description instead of "desktop file"
        it = m_desktopCache.insert(item.url(), {f.readName(), f.readIcon(), generic.isEmpty() ? f.readComment() : generic});
    }
    return it.value();
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
    // launchers (.desktop) with their actual name and icon
    const bool desktopFile = item.isDesktopFile();
    switch (role) {
    case NameRole:
        if (desktopFile) {
            const QString &n = desktopInfo(item).name;
            if (!n.isEmpty()) {
                return n;
            }
        }
        return item.text();
    case IconRole:
        if (desktopFile) {
            const QString &i = desktopInfo(item).icon;
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
            return desktopInfo(item).detail;
        }
        return item.mimeComment();
    }
    return {};
}
