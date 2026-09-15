#include "clipboard.h"
#include <QGuiApplication>
#include <QClipboard>

Clipboard::Clipboard(QObject *parent) : QObject(parent) {
}

bool Clipboard::setText(const QString &text) {
    QClipboard *clipboard = QGuiApplication::clipboard();
    if (!clipboard) {
        return false;
    }
    clipboard->setText(text);
    return clipboard->text() == text;
}
