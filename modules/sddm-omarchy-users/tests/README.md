# Greeter regression checks

Render `tst_users.qml.in` into a temporary test directory, replacing `@themePath@`
with the `file://` URL of the built `omarchyUserTheme/share/sddm/themes/omarchy-users`
directory. Run with Qt 6 qmltestrunner, the SddmComponents QML import directory,
`QT_QPA_PLATFORM=offscreen`, and `QT_QUICK_BACKEND=software`.

The session-model stub deliberately returns no data for Qt.DisplayRole. SDDM
0.21 exposes NameRole at Qt.UserRole + 4; accepting every role here would mask
broken desktop routing. Also check the real greeter in `--test-mode`: Dan must
select Hyprland and Nathan must select Xfce Session, without authenticating.
