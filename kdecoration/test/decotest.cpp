// Test der Schiefer-Dekoration (gebautes Plugin kdecoration/build/bin/schiefer.so) mit den
// Mock-Klassen aus den kdecoration-6.7.6-Autotests: echte KDecoration3-Bibliothek, kein KWin.
// Prüft: Motif-Eckgriffe (sectionUnderMouse, wie KWin sie liest) und Doppelklick auf den Menüknopf.
// Bauen/Starten: siehe CMakeLists.txt; anderes Plugin: SCHIEFER_DECO_PLUGIN=/pfad/schiefer.so
// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
#include "mockbridge.h"
#include "mocksettings.h"
#include "mockwindow.h"

#include <KDecoration3/Decoration>
#include <KDecoration3/DecorationButton>
#include <KDecoration3/DecorationSettings>
#include <KPluginFactory>
#include <KPluginMetaData>

#include <QDir>
#include <QGuiApplication>
#include <QSignalSpy>
#include <QStyleHints>
#include <QTemporaryDir>
#include <QTest>

static QString s_plugin;
static QString s_cfgDir;

static void writeRc(const QString &body)
{
    QFile f(s_cfgDir + QStringLiteral("/schieferrc"));
    QVERIFY(f.open(QIODevice::WriteOnly | QIODevice::Truncate));
    f.write(body.toUtf8());
}

struct Fixture {
    MockBridge bridge;
    std::shared_ptr<KDecoration3::DecorationSettings> settings;
    KDecoration3::Decoration *deco = nullptr;
    MockWindow *win = nullptr;
    MockSettings *ms = nullptr;

    explicit Fixture(int largeSpacing)
    {
        settings = std::make_shared<KDecoration3::DecorationSettings>(&bridge);
        ms = bridge.lastCreatedSettings();
        ms->setLargeSpacing(largeSpacing);
        auto factory = KPluginFactory::loadFactory(KPluginMetaData(s_plugin)).plugin;
        Q_ASSERT(factory);
        deco = factory->create<KDecoration3::Decoration>(nullptr, QVariantList({QVariantMap({{QStringLiteral("bridge"), QVariant::fromValue(&bridge)}})}));
        Q_ASSERT(deco);
        win = bridge.lastCreatedWindow();
        win->setWidth(400);
        win->setHeight(300);
        // Reihenfolge wie KWin (decorations/decorationbridge.cpp: create, setSettings, init)
        deco->create();
        deco->setSettings(settings);
        deco->init();
        deco->apply(deco->nextState()); // KWin übernimmt die Ränder mit dem nächsten Fensterzustand
    }
    ~Fixture()
    {
        delete deco;
    }
    Qt::WindowFrameSection at(qreal x, qreal y)
    {
        QHoverEvent e(QEvent::HoverMove, QPointF(x, y), QPointF(x, y), QPointF(x, y));
        QCoreApplication::sendEvent(deco, &e);
        return deco->sectionUnderMouse();
    }
    void mouse(QEvent::Type t, QPointF p, Qt::MouseButton b = Qt::LeftButton)
    {
        QMouseEvent e(t, p, p, b, t == QEvent::MouseButtonPress ? b : Qt::NoButton, Qt::NoModifier);
        QCoreApplication::sendEvent(deco, &e);
    }
    void click(QPointF p, Qt::MouseButton b = Qt::LeftButton)
    {
        mouse(QEvent::MouseButtonPress, p, b);
        mouse(QEvent::MouseButtonRelease, p, b);
    }
};

class DecoTest : public QObject
{
    Q_OBJECT
private Q_SLOTS:
    void init()
    {
        QFile::remove(s_cfgDir + QStringLiteral("/schieferrc"));
    }
    void corners_data();
    void corners();
    void cornersOff();
    void menuDoubleClick();
    void menuSingleClickDelayed();
    void menuRightClickImmediate();
    void menuDoubleClickOff();
    void menuKWinSettingWins();
};

void DecoTest::corners_data()
{
    QTest::addColumn<int>("largeSpacing");
    // KDecoration3-Ecke = 2 * largeSpacing: kleiner (8) und größer (60) als die Kerbe (b + t)
    QTest::newRow("Ecke kleiner als Kerbe") << 4;
    QTest::newRow("Ecke größer als Kerbe") << 30;
}

void DecoTest::corners()
{
    QFETCH(int, largeSpacing);
    Fixture f(largeSpacing);
    const qreal b = f.deco->borderLeft();
    const qreal C = f.deco->borderTop(); // = Rahmen + Titelhöhe = Lage der Kerben
    const qreal W = f.deco->size().width(), H = f.deco->size().height();
    qInfo() << "Rahmen" << b << "Kerbe bei" << C << "Größe" << W << H << "KDecoration3-Ecke" << 2 * largeSpacing;
    QVERIFY(b > 0 && C > b);
    struct P {
        qreal x, y;
        Qt::WindowFrameSection s;
    };
    const QList<P> pts = {
        // obere Kante
        {0, 0, Qt::TopLeftSection}, {C - 1, 0, Qt::TopLeftSection}, {C, 0, Qt::TopSection}, {C - 1, b - 1, Qt::TopLeftSection},
        {W - C, 0, Qt::TopRightSection}, {W - C - 1, 0, Qt::TopSection}, {W - 1, b - 1, Qt::TopRightSection},
        // linke Kante
        {0, C - 1, Qt::TopLeftSection}, {b - 1, C - 1, Qt::TopLeftSection}, {0, C, Qt::LeftSection}, {0, H - C - 1, Qt::LeftSection},
        {0, H - C, Qt::BottomLeftSection}, {b - 1, H - 1, Qt::BottomLeftSection},
        // rechte Kante
        {W - 1, C - 1, Qt::TopRightSection}, {W - b, C, Qt::RightSection}, {W - 1, H - C, Qt::BottomRightSection}, {W - 1, H - C - 1, Qt::RightSection},
        // untere Kante
        {C - 1, H - 1, Qt::BottomLeftSection}, {C, H - 1, Qt::BottomSection}, {W - C - 1, H - 1, Qt::BottomSection}, {W - C, H - b, Qt::BottomRightSection},
        // Titelzeile bleibt Titelzeile
        {W / 2, b + 2, Qt::TitleBarArea},
    };
    for (const auto &p : pts) {
        // jeweils von der Fenstermitte aus (frischer Zustand) und zweimal (Zustand bleibt)
        f.at(W / 2, H / 2);
        const auto got = f.at(p.x, p.y);
        if (got != p.s) {
            qWarning() << "bei" << p.x << p.y << "erwartet" << p.s << "bekommen" << got;
        }
        QCOMPARE(got, p.s);
    }
    // Loslassen außerhalb eines Knopfs: KDecoration3 bestimmt den Abschnitt neu – Motif-Ecke bleibt
    f.at(C - 1, 0);
    f.mouse(QEvent::MouseButtonRelease, QPointF(C - 1, 0));
    QCOMPARE(f.deco->sectionUnderMouse(), Qt::TopLeftSection);
}

void DecoTest::cornersOff()
{
    writeRc(QStringLiteral("[Decoration]\nMotifCorners=false\n"));
    Fixture f(4);
    const qreal C = f.deco->borderTop();
    const qreal b = f.deco->borderLeft();
    // KDecoration3 allein: Ecke 2 * 4 = 8 px ab Rahmen -> bei C - 1 schon obere Kante
    QCOMPARE(f.at(C - 1, 0), Qt::TopSection);
    QCOMPARE(f.at(b + 7, 0), Qt::TopLeftSection);
    // Schalter zur Laufzeit an: reconfigured (wie qdbus6 org.kde.KWin /KWin reconfigure)
    writeRc(QStringLiteral("[Decoration]\nMotifCorners=true\n"));
    Q_EMIT f.settings->reconfigured();
    f.at(200, 150);
    QCOMPARE(f.at(C - 1, 0), Qt::TopLeftSection);
}

static QPointF menuButtonCenter(Fixture &f)
{
    const qreal b = f.deco->borderLeft();
    const qreal t = f.deco->borderTop() - b;
    return QPointF(b + t / 2, b + t / 2);
}

void DecoTest::menuSingleClickDelayed()
{
    Fixture f(4);
    QSignalSpy menu(f.win, &MockWindow::menuRequested), close(f.win, &MockWindow::closeRequested);
    const QPointF p = menuButtonCenter(f);
    QCOMPARE(f.at(p.x(), p.y()), Qt::TitleBarArea);
    f.click(p);
    QTest::qWait(50);
    QCOMPARE(menu.count(), 0); // noch nicht: wartet auf einen möglichen zweiten Klick
    QTest::qWait(QGuiApplication::styleHints()->mouseDoubleClickInterval() + 50);
    QCOMPARE(menu.count(), 1);
    QCOMPARE(close.count(), 0);
}

void DecoTest::menuDoubleClick()
{
    Fixture f(4);
    QSignalSpy menu(f.win, &MockWindow::menuRequested), close(f.win, &MockWindow::closeRequested);
    const QPointF p = menuButtonCenter(f);
    f.at(p.x(), p.y());
    f.click(p);
    QTest::qWait(QGuiApplication::styleHints()->mouseDoubleClickInterval() / 3);
    f.click(p);
    QTest::qWait(QGuiApplication::styleHints()->mouseDoubleClickInterval() + 50);
    QCOMPARE(close.count(), 1);
    QCOMPARE(menu.count(), 0);
}

void DecoTest::menuRightClickImmediate()
{
    Fixture f(4);
    QSignalSpy menu(f.win, &MockWindow::menuRequested);
    const QPointF p = menuButtonCenter(f);
    f.at(p.x(), p.y());
    f.click(p, Qt::RightButton);
    QTest::qWait(20);
    QCOMPARE(menu.count(), 1);
}

void DecoTest::menuDoubleClickOff()
{
    writeRc(QStringLiteral("[Decoration]\nDoubleClickClose=false\n"));
    Fixture f(4);
    QSignalSpy menu(f.win, &MockWindow::menuRequested), close(f.win, &MockWindow::closeRequested);
    const QPointF p = menuButtonCenter(f);
    f.at(p.x(), p.y());
    f.click(p);
    QTest::qWait(20);
    QCOMPARE(menu.count(), 1); // sofort wie bei KDecoration3
    f.click(p);
    QTest::qWait(QGuiApplication::styleHints()->mouseDoubleClickInterval() + 50);
    QCOMPARE(menu.count(), 2);
    QCOMPARE(close.count(), 0);
}

void DecoTest::menuKWinSettingWins()
{
    // KWin-Einstellung CloseOnDoubleClickOnMenu: KDecoration3 übernimmt (Menü nur bei langem Druck)
    Fixture f(4);
    f.ms->setCloseOnDoubleClickOnMenu(true);
    QTest::qWait(10); // Einstellung kommt per QueuedConnection beim Knopf an
    QSignalSpy menu(f.win, &MockWindow::menuRequested), close(f.win, &MockWindow::closeRequested);
    const QPointF p = menuButtonCenter(f);
    f.at(p.x(), p.y());
    f.click(p);
    QTest::qWait(30);
    f.click(p);
    QTest::qWait(QGuiApplication::styleHints()->mouseDoubleClickInterval() + 50);
    QCOMPARE(close.count(), 1);
    QCOMPARE(menu.count(), 0);
}

int main(int argc, char **argv)
{
    QTemporaryDir dir;
    s_cfgDir = dir.path();
    qputenv("XDG_CONFIG_HOME", dir.path().toUtf8());
    qputenv("QT_QPA_PLATFORM", "offscreen");
    QGuiApplication app(argc, argv);
    s_plugin = qEnvironmentVariable("SCHIEFER_DECO_PLUGIN", QStringLiteral(SCHIEFER_DECO_PLUGIN_DEFAULT));
    DecoTest t;
    return QTest::qExec(&t, argc, argv);
}

#include "decotest.moc"
