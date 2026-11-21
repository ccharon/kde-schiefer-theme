// Test gallery for Schiefer: shows typical controls.
//   retrogallery                       -> show the window
//   retrogallery --grab out.png        -> render offscreen to PNG (including an open menu)
//   extras (do not change the default image):
//     --menu view     show the "View" menu with radio items (exclusive checks) instead of "File"
//     --busy out2.png busy progress bar; out2.png is captured 400 ms after out.png
//     --delay ms      capture after ms (default 300)
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

    // Column 1: buttons and choices
    auto *col1 = new QVBoxLayout;
    auto *buttons = new QGroupBox(QStringLiteral("Buttons"));
    auto *bl = new QVBoxLayout(buttons);
    auto *def = new QPushButton(QStringLiteral("Default"));
    def->setDefault(true);
    bl->addWidget(def);
    bl->addWidget(new QPushButton(QStringLiteral("Button")));
    auto *menuButton = new QPushButton(QStringLiteral("Menu Button"));
    auto *m = new QMenu(menuButton);
    m->addAction(QStringLiteral("One"));
    menuButton->setMenu(m);
    bl->addWidget(menuButton);
    auto *dis = new QPushButton(QStringLiteral("Disabled"));
    dis->setEnabled(false);
    bl->addWidget(dis);
    auto *tb = new QToolButton;
    tb->setText(QStringLiteral("Tool"));
    tb->setCheckable(true);
    tb->setChecked(true);
    bl->addWidget(tb);
    col1->addWidget(buttons);

    auto *choice = new QGroupBox(QStringLiteral("Choice"));
    auto *cl = new QVBoxLayout(choice);
    auto *c1 = new QCheckBox(QStringLiteral("Check box on"));
    c1->setChecked(true);
    cl->addWidget(c1);
    cl->addWidget(new QCheckBox(QStringLiteral("Check box off")));
    auto *c3 = new QCheckBox(QStringLiteral("Partial"));
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

    // Column 2: inputs
    auto *col2 = new QVBoxLayout;
    auto *inputs = new QGroupBox(QStringLiteral("Inputs"));
    auto *fl = new QFormLayout(inputs);
    fl->addRow(QStringLiteral("Text:"), new QLineEdit(QStringLiteral("abc")));
    auto *combo = new QComboBox;
    combo->addItems({QStringLiteral("itemA"), QStringLiteral("itemB")});
    fl->addRow(QStringLiteral("ComboBox:"), combo);
    auto *ecombo = new QComboBox;
    ecombo->setEditable(true);
    ecombo->addItem(QStringLiteral("editable"));
    fl->addRow(QStringLiteral("Editable:"), ecombo);
    auto *spin = new QSpinBox;
    spin->setValue(42);
    fl->addRow(QStringLiteral("SpinBox:"), spin);
    auto *slider = new QSlider(Qt::Horizontal);
    slider->setValue(40);
    fl->addRow(QStringLiteral("Slider:"), slider);
    auto *ticks = new QSlider(Qt::Horizontal);
    ticks->setTickPosition(QSlider::TicksBelow);
    ticks->setValue(70);
    fl->addRow(QStringLiteral("With scale:"), ticks);
    auto *progress = new QProgressBar;
    progress->setValue(60);
    fl->addRow(QStringLiteral("Progress:"), progress);
    auto *dial = new QDial;
    dial->setValue(30);
    dial->setFixedSize(56, 56);
    fl->addRow(QStringLiteral("Dial:"), dial);
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
    tree->setHeaderLabels({QStringLiteral("Name"), QStringLiteral("Size")});
    for (int i = 0; i < 3; ++i) {
        auto *it = new QTreeWidgetItem(tree, {QStringLiteral("Folder %1").arg(i + 1), QStringLiteral("-")});
        new QTreeWidgetItem(it, {QStringLiteral("file.txt"), QStringLiteral("4 KB")});
        it->setExpanded(i == 0);
    }
    tree->setMaximumHeight(130);
    col3->addWidget(tree);
    auto *text = new QTextEdit;
    text->setPlainText(QStringLiteral("Multi-line text\n").repeated(12));
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
    win.setWindowTitle(QStringLiteral("Schiefer Gallery"));
    auto *file = win.menuBar()->addMenu(QStringLiteral("&File"));
    file->addAction(QIcon::fromTheme(QStringLiteral("document-open")), QStringLiteral("&Open…"))->setShortcut(QKeySequence::Open);
    file->addAction(QIcon::fromTheme(QStringLiteral("document-save")), QStringLiteral("&Save"))->setShortcut(QKeySequence::Save);
    auto *chk = file->addAction(QStringLiteral("Save Automatically"));
    chk->setCheckable(true);
    chk->setChecked(true);
    file->addSeparator();
    auto *sub = file->addMenu(QStringLiteral("Open Recent"));
    sub->addAction(QStringLiteral("project.bip"));
    file->addAction(QStringLiteral("Disabled"))->setEnabled(false);
    file->addSeparator();
    file->addAction(QIcon::fromTheme(QStringLiteral("application-exit")), QStringLiteral("&Quit"))->setShortcut(QKeySequence::Quit);
    win.menuBar()->addMenu(QStringLiteral("&Edit"));
    // radio items in the menu (visible only with --menu view)
    auto *view = win.menuBar()->addMenu(QStringLiteral("&View"));
    auto *group = new QActionGroup(view);
    for (const auto &name : {QStringLiteral("Icons"), QStringLiteral("List"), QStringLiteral("Details")}) {
        auto *a = view->addAction(name);
        a->setCheckable(true);
        a->setActionGroup(group);
        a->setChecked(name == QStringLiteral("List"));
    }
    view->addSeparator();
    auto *dis1 = view->addAction(QStringLiteral("Disabled on"));
    auto *dis2 = view->addAction(QStringLiteral("Disabled off"));
    auto *group2 = new QActionGroup(view);
    for (auto *a : {dis1, dis2}) {
        a->setCheckable(true);
        a->setActionGroup(group2);
        a->setEnabled(false);
    }
    dis1->setChecked(true);
    view->addSeparator();
    view->addAction(QStringLiteral("Status bar"))->setCheckable(true);
    win.menuBar()->addMenu(QStringLiteral("&Help"));

    auto *toolbar = win.addToolBar(QStringLiteral("Tools"));
    toolbar->setToolButtonStyle(Qt::ToolButtonTextBesideIcon);
    toolbar->addAction(QIcon::fromTheme(QStringLiteral("document-new")), QStringLiteral("New"));
    toolbar->addAction(QIcon::fromTheme(QStringLiteral("document-open")), QStringLiteral("Open"));
    toolbar->addSeparator();
    auto *tog = toolbar->addAction(QIcon::fromTheme(QStringLiteral("view-preview")), QStringLiteral("Preview"));
    tog->setCheckable(true);
    tog->setChecked(true);

    auto *tabs = new QTabWidget;
    tabs->addTab(controlsPage(), QStringLiteral("Controls"));
    tabs->addTab(new QLabel(QStringLiteral("Second page")), QStringLiteral("Panes"));
    tabs->addTab(new QLabel(QStringLiteral("Third page")), QStringLiteral("Windows"));
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
        // second capture after 400 ms: the bar must move on even without animations
        QTimer::singleShot(700, [&] {
            win.grab().toImage().save(args.at(busyIdx + 1));
        });
    }
    win.show();
    const int delayIdx = args.indexOf(QStringLiteral("--delay")); // --delay ms: capture later (for example after a D-Bus reload)
    const int delay = delayIdx >= 0 && delayIdx + 1 < args.size() ? args.at(delayIdx + 1).toInt() : 300;
    QTimer::singleShot(delay, [&] {
        QImage shot = win.grab().toImage();
        // render the menu separately and place it to the right of the window
        shown->adjustSize();
        shown->ensurePolished();
        const QImage menu = shown->grab().toImage();
        // compose in logical units, image in device pixels (QT_SCALE_FACTOR=1.5 keeps the pixels unchanged)
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
            QTimer::singleShot(500, &app, &QApplication::quit); // wait for the second capture
        } else {
            app.quit();
        }
    });
    return app.exec();
}
