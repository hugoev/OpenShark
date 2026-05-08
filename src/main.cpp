#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QtQuickControls2/QQuickStyle>

#include "AppController.h"
#include "models/PacketListModel.h"
#include "models/InterfaceListModel.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName("OpenShark");
    app.setApplicationVersion("0.1.0");
    app.setOrganizationName("OpenShark");

    QQuickStyle::setStyle("Basic");

    qmlRegisterType<PacketListModel>   ("OpenShark", 1, 0, "PacketListModel");
    qmlRegisterType<InterfaceListModel>("OpenShark", 1, 0, "InterfaceListModel");

    AppController controller;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("appController", &controller);

    const QUrl url(QStringLiteral("qrc:/qt/qml/OpenShark/qml/main.qml"));
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed,
        &app,    []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection
    );
    engine.load(url);

    return app.exec();
}
