import QtQuick

Item {
  id: root

  property var shell: null
  property var pluginRegistry: null
  property var manifest: null
  property var barWidgetRegistry: null
  property var service: null

  // Keep the mature interaction/launch/pinning implementation intact while
  // giving it a tighter macOS-like visual shell.
  DockPanelBase {
    id: dock
    shell: root.shell
    pluginRegistry: root.pluginRegistry
    manifest: root.manifest
  }
}
