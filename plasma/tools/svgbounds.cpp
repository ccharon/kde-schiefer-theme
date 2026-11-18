// svgbounds <datei.svg[z]> [muster]  – gibt Elementgrößen aus (wie Plasma sie sieht)
#include <QGuiApplication>
#include <QSvgRenderer>
#include <QFile>
#include <QRegularExpression>
#include <cstdio>
int main(int argc, char **argv) {
    QGuiApplication app(argc, argv);
    QSvgRenderer r(QString::fromLocal8Bit(argv[1]));
    QFile f(argv[1]); f.open(QIODevice::ReadOnly);
    QByteArray data = f.readAll();
    if (data.startsWith("\x1f\x8b")) data = qUncompress(QByteArray()); // not used
    QRegularExpression pat(argc > 2 ? argv[2] : ".*");
    // IDs via Renderer nicht auflistbar -> aus Kommandozeile lesen
    for (int i = 3; i < argc; ++i) {
        QRectF b = r.boundsOnElement(argv[i]);
        printf("%s=%gx%g\n", argv[i], b.width(), b.height());
    }
    return 0;
}
