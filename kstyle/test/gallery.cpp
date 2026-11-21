// Test-Galerie für Schiefer: zeigt typische Bedienelemente.
//   retrogallery                       -> Fenster anzeigen
//   retrogallery --grab out.png        -> offscreen in PNG rendern (inkl. aufgeklapptem Menü)
//   Zusätze (ändern das Standardbild nicht):
//     --menu view     statt „File“ das Menü „View“ mit Optionsfeldern (exklusive Häkchen) daneben setzen
//     --busy out2.png Fortschrittsbalken „besetzt“; out2.png wird 400 ms nach out.png aufgenommen
//     --delay ms      Aufnahme erst nach ms (Standard 300)
#include <QAction>
#include <QActionGroup>
#include <QApplication>
#include <QCheckBox>
#include <QComboBox>
#include <QDial>
#include <QFormLayout>
#include <QGroupBox>
#include <QHBoxLayout>
#include <QHeaderView>
#include <QLabel>
#include <QLineEdit>
#include <QListWidget>
#include <QMainWindow>
#include <QMenu>
#include <QMenuBar>
#include <QPainter>
#include <QProgressBar>
#include <QPushButton>
#include <QRadioButton>
#include <QScrollBar>
#include <QSlider>
#include <QSpinBox>
#include <QStatusBar>
#include <QTabWidget>
#include <QTextEdit>
#include <QTimer>
#include <QToolBar>
#include <QToolButton>
#include <QtMath>
#include <QTreeWidget>
#include <QVBoxLayout>

static QWidget *controlsPage()
{
    auto *page = new QWidget;
    auto *grid = new QHBoxLayout(page);

    // Spalte 1: Knöpfe & Auswahl
    auto *col1 = new QVBoxLayout;
    auto *buttons = new QGroupBox(QStringLiteral("Knöpfe"));
    auto *bl = new QVBoxLayout(buttons);
    auto *def = new QPushButton(QStringLiteral("Standard"));
    def->setDefault(true);
    bl->addWidget(def);
    bl->addWidget(new QPushButton(QStringLiteral("Button")));
    auto *menuButton = new QPushButton(QStringLiteral("Menu Button"));
    auto *m = new QMenu(menuButton);
    m->addAction(QStringLiteral("Eins"));
    menuButton->setMenu(m);
    bl->addWidget(menuButton);
    auto *dis = new QPushButton(QStringLiteral("Deaktiviert"));
    dis->setEnabled(false);
    bl->addWidget(dis);
    auto *tb = new QToolButton;
    tb->setText(QStringLiteral("Werkzeug"));
    tb->setCheckable(true);
    tb->setChecked(true);
    bl->addWidget(tb);
    col1->addWidget(buttons);

    auto *choice = new QGroupBox(QStringLiteral("Auswahl"));
    auto *cl = new QVBoxLayout(choice);
    auto *c1 = new QCheckBox(QStringLiteral("Checkbox an"));
    c1->setChecked(true);
    cl->addWidget(c1);
    cl->addWidget(new QCheckBox(QStringLiteral("Checkbox aus")));
    auto *c3 = new QCheckBox(QStringLiteral("Teilweise"));
    c3->setTristate(true);
    c3->setCheckState(Qt::PartiallyChecked);
    cl->addWidget(c3);
    auto *r1 = new QRadioButton(QStringLiteral("Option A"));
    r1->setChecked(true);
    cl->addWidget(r1);
    cl->addWidget(new QRadioButton(QStringLiteral("Option B")));
    col1->addWidget(choice);
    col1->addStretch();
    grid->addLayout(col1);

    // Spalte 2: Eingaben
    auto *col2 = new QVBoxLayout;
    auto *inputs = new QGroupBox(QStringLiteral("Eingaben"));
    auto *fl = new QFormLayout(inputs);
    fl->addRow(QStringLiteral("Text:"), new QLineEdit(QStringLiteral("abc")));
    auto *combo = new QComboBox;
    combo->addItems({QStringLiteral("itemA"), QStringLiteral("itemB")});
    fl->addRow(QStringLiteral("ComboBox:"), combo);
    auto *ecombo = new QComboBox;
    ecombo->setEditable(true);
    ecombo->addItem(QStringLiteral("editierbar"));
    fl->addRow(QStringLiteral("Editierbar:"), ecombo);
    auto *spin = new QSpinBox;
    spin->setValue(42);
    fl->addRow(QStringLiteral("SpinBox:"), spin);
    auto *slider = new QSlider(Qt::Horizontal);
    slider->setValue(40);
    fl->addRow(QStringLiteral("Slider:"), slider);
    auto *ticks = new QSlider(Qt::Horizontal);
    ticks->setTickPosition(QSlider::TicksBelow);
    ticks->setValue(70);
    fl->addRow(QStringLiteral("Mit Skala:"), ticks);
    auto *progress = new QProgressBar;
    progress->setValue(60);
    fl->addRow(QStringLiteral("Fortschritt:"), progress);
    auto *dial = new QDial;
    dial->setValue(30);
    dial->setFixedSize(56, 56);
    fl->addRow(QStringLiteral("Drehregler:"), dial);
    col2->addWidget(inputs);

    auto *list = new QListWidget;
    for (int i = 0; i < 12; ++i) {
        list->addItem(QStringLiteral("item%1").arg(QChar('A' + i)));
    }
    list->setCurrentRow(1);
    list->setMaximumHeight(110);
    col2->addWidget(list);
    grid->addLayout(col2);

    // Spalte 3: Baum, Text, Scrollbalken
    auto *col3 = new QVBoxLayout;
    auto *tree = new QTreeWidget;
    tree->setHeaderLabels({QStringLiteral("Name"), QStringLiteral("Größe")});
    for (int i = 0; i < 3; ++i) {
        auto *it = new QTreeWidgetItem(tree, {QStringLiteral("Ordner %1").arg(i + 1), QStringLiteral("–")});
        new QTreeWidgetItem(it, {QStringLiteral("datei.txt"), QStringLiteral("4 KB")});
        it->setExpanded(i == 0);
    }
    tree->setMaximumHeight(130);
    col3->addWidget(tree);
    auto *text = new QTextEdit;
    text->setPlainText(QStringLiteral("Mehrzeiliger Text\n").repeated(12));
    text->setMaximumHeight(110);
    col3->addWidget(text);
    auto *hs = new QScrollBar(Qt::Horizontal);
    hs->setRange(0, 100);
    hs->setPageStep(30);
    hs->setValue(20);
    col3->addWidget(hs);
    col3->addStretch();
    grid->addLayout(col3);
    return page;
}

int main(int argc, char **argv)
{
    QApplication app(argc, argv);
    const QStringList args = app.arguments();
    const int grabIdx = args.indexOf(QStringLiteral("--grab"));

    QMainWindow win;
    win.setWindowTitle(QStringLiteral("Schiefer – Galerie"));
    auto *file = win.menuBar()->addMenu(QStringLiteral("&File"));
    file->addAction(QIcon::fromTheme(QStringLiteral("document-open")), QStringLiteral("&Öffnen …"))->setShortcut(QKeySequence::Open);
    file->addAction(QIcon::fromTheme(QStringLiteral("document-save")), QStringLiteral("&Speichern"))->setShortcut(QKeySequence::Save);
    auto *chk = file->addAction(QStringLiteral("Automatisch speichern"));
    chk->setCheckable(true);
    chk->setChecked(true);
    file->addSeparator();
    auto *sub = file->addMenu(QStringLiteral("Zuletzt geöffnet"));
    sub->addAction(QStringLiteral("projekt.bip"));
    file->addAction(QStringLiteral("Deaktiviert"))->setEnabled(false);
    file->addSeparator();
    file->addAction(QIcon::fromTheme(QStringLiteral("application-exit")), QStringLiteral("&Beenden"))->setShortcut(QKeySequence::Quit);
    win.menuBar()->addMenu(QStringLiteral("&Edit"));
    // Optionsfelder im Menü (nur sichtbar mit --menu view)
    auto *view = win.menuBar()->addMenu(QStringLiteral("&View"));
    auto *group = new QActionGroup(view);
    for (const auto &name : {QStringLiteral("Symbole"), QStringLiteral("Liste"), QStringLiteral("Details")}) {
        auto *a = view->addAction(name);
        a->setCheckable(true);
        a->setActionGroup(group);
        a->setChecked(name == QStringLiteral("Liste"));
    }
    view->addSeparator();
    auto *dis1 = view->addAction(QStringLiteral("Deaktiviert an"));
    auto *dis2 = view->addAction(QStringLiteral("Deaktiviert aus"));
    auto *group2 = new QActionGroup(view);
    for (auto *a : {dis1, dis2}) {
        a->setCheckable(true);
        a->setActionGroup(group2);
        a->setEnabled(false);
    }
    dis1->setChecked(true);
    view->addSeparator();
    view->addAction(QStringLiteral("Statusleiste"))->setCheckable(true);
    win.menuBar()->addMenu(QStringLiteral("&Help"));

    auto *toolbar = win.addToolBar(QStringLiteral("Werkzeuge"));
    toolbar->setToolButtonStyle(Qt::ToolButtonTextBesideIcon);
    toolbar->addAction(QIcon::fromTheme(QStringLiteral("document-new")), QStringLiteral("Neu"));
    toolbar->addAction(QIcon::fromTheme(QStringLiteral("document-open")), QStringLiteral("Öffnen"));
    toolbar->addSeparator();
    auto *tog = toolbar->addAction(QIcon::fromTheme(QStringLiteral("view-preview")), QStringLiteral("Vorschau"));
    tog->setCheckable(true);
    tog->setChecked(true);

    auto *tabs = new QTabWidget;
    tabs->addTab(controlsPage(), QStringLiteral("Controls"));
    tabs->addTab(new QLabel(QStringLiteral("Zweite Seite")), QStringLiteral("Panes"));
    tabs->addTab(new QLabel(QStringLiteral("Dritte Seite")), QStringLiteral("Windows"));
    win.setCentralWidget(tabs);
    win.statusBar()->showMessage(QStringLiteral("17 Items 1 Hidden"));
    win.resize(980, 600);

    if (grabIdx < 0 || grabIdx + 1 >= args.size()) {
        win.show();
        return app.exec();
    }

    const QString out = args.at(grabIdx + 1);
    QMenu *shown = file;
    const int menuIdx = args.indexOf(QStringLiteral("--menu"));
    if (menuIdx >= 0 && menuIdx + 1 < args.size() && args.at(menuIdx + 1) == QStringLiteral("view")) {
        shown = view;
    }
    const int busyIdx = args.indexOf(QStringLiteral("--busy"));
    if (busyIdx >= 0 && busyIdx + 1 < args.size()) {
        for (auto *bar : win.findChildren<QProgressBar *>()) {
            bar->setRange(0, 0);
        }
        // zweite Aufnahme nach 400 ms: der Balken muss sich auch ohne Animationen weiterbewegen
        QTimer::singleShot(700, [&] {
            win.grab().toImage().save(args.at(busyIdx + 1));
        });
    }
    win.show();
    const int delayIdx = args.indexOf(QStringLiteral("--delay")); // --delay ms: später aufnehmen (z. B. nach D-Bus-Neuladen)
    const int delay = delayIdx >= 0 && delayIdx + 1 < args.size() ? args.at(delayIdx + 1).toInt() : 300;
    QTimer::singleShot(delay, [&] {
        QImage shot = win.grab().toImage();
        // Menü separat rendern und rechts neben das Fenster setzen
        shown->adjustSize();
        shown->ensurePolished();
        const QImage menu = shown->grab().toImage();
        // in logischen Maßen zusammensetzen, Bild in Gerätepixeln (QT_SCALE_FACTOR=1.5: Pixel bleiben unverändert)
        const qreal dpr = shot.devicePixelRatio();
        const QSizeF ss = shot.deviceIndependentSize(), ms = menu.deviceIndependentSize();
        QImage sheet(qCeil((ss.width() + ms.width() + 24) * dpr), qCeil(std::max(ss.height(), ms.height() + 40) * dpr), QImage::Format_ARGB32);
        sheet.setDevicePixelRatio(dpr);
        sheet.fill(QColor(110, 138, 166));
        QPainter p(&sheet);
        p.drawImage(QPointF(0, 0), shot);
        p.drawImage(QPointF(ss.width() + 12, 30), menu);
        p.end();
        sheet.save(out);
        if (busyIdx >= 0) {
            QTimer::singleShot(500, &app, &QApplication::quit); // auf die zweite Aufnahme warten
        } else {
            app.quit();
        }
    });
    return app.exec();
}
