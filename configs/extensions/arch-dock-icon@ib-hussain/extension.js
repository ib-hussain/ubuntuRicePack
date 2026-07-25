import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import St from 'gi://St';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

const DASH_TO_DOCK_SCHEMA = 'org.gnome.shell.extensions.dash-to-dock';

export default class RiceShowAppsIconExtension extends Extension {
    enable() {
        this._signals = [];
        this._patchedIcons = new Map();
        this._patchIdleId = 0;
        this._dockSettings = null;

        const iconFile = this._findIconFile();
        if (!iconFile) {
            console.error(`${this.uuid}: no supported icon was found in the icons directory`);
            return;
        }

        this._gicon = new Gio.FileIcon({file: iconFile});

        this._connect(Main.overview, 'showing', () => this._queuePatch());
        this._connect(Main.overview, 'shown', () => this._queuePatch());
        this._connect(Main.layoutManager, 'monitors-changed', () => this._queuePatch());
        this._connect(Main.extensionManager, 'extension-state-changed',
            () => this._queuePatch());

        const schemaSource = Gio.SettingsSchemaSource.get_default();
        if (schemaSource?.lookup(DASH_TO_DOCK_SCHEMA, true)) {
            this._dockSettings = new Gio.Settings({
                schema_id: DASH_TO_DOCK_SCHEMA,
            });
            this._connect(this._dockSettings, 'changed', () => this._queuePatch());
        }

        this._queuePatch();
    }

    disable() {
        if (this._patchIdleId) {
            GLib.Source.remove(this._patchIdleId);
            this._patchIdleId = 0;
        }

        for (const [object, signalId] of this._signals) {
            try {
                object.disconnect(signalId);
            } catch (error) {
                this._logError('failed to disconnect a signal', error);
            }
        }
        this._signals = [];

        this._restoreIcons();

        this._dockSettings = null;
        this._gicon = null;
        this._patchedIcons = null;
    }

    _findIconFile() {
        const iconsDirectory = this.dir.get_child('icons');
        const candidates = [
            'show-apps-logo.png',
            'show-apps-logo.svg',
            'arch-logo.png',
            'ubuntu-logo.png',
            'ubuntu-logo.svg',
        ];

        for (const filename of candidates) {
            const file = iconsDirectory.get_child(filename);
            if (file.query_exists(null))
                return file;
        }

        return null;
    }

    _connect(object, signal, callback) {
        if (!object)
            return;

        try {
            const signalId = object.connect(signal, callback);
            this._signals.push([object, signalId]);
        } catch (error) {
            this._logError(`failed to connect ${signal}`, error);
        }
    }

    _queuePatch() {
        if (!this._gicon || this._patchIdleId)
            return;

        this._patchIdleId = GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
            this._patchIdleId = 0;

            try {
                this._patchCurrentIcons();
            } catch (error) {
                this._logError('failed to patch the Show Applications icon', error);
            }

            return GLib.SOURCE_REMOVE;
        });
    }

    _patchCurrentIcons() {
        const icons = new Set();
        const dash = Main.overview?.dash;

        // GNOME's dash, Ubuntu Dock 105, and Dash-to-Dock 105 all expose
        // their current Show Applications actor through the active dash.
        this._collectIcons(dash?._showAppsIcon, icons);
        this._collectIcons(dash?.showAppsButton, icons);

        // Ubuntu Dock/Dash-to-Dock can create one dock per monitor. Only the
        // primary dash is exposed above, so inspect the Shell UI once for
        // additional actors that are strictly inside a "show-apps" widget.
        this._collectShowAppsIcons(Main.uiGroup, false, icons);

        for (const icon of icons)
            this._patchIcon(icon);
    }

    _collectIcons(actor, icons) {
        if (!actor)
            return;

        if (actor instanceof St.Icon)
            icons.add(actor);

        for (const child of this._getChildren(actor))
            this._collectIcons(child, icons);
    }

    _collectShowAppsIcons(actor, insideShowApps, icons) {
        if (!actor)
            return;

        const classes = this._getStyleClasses(actor);
        const isShowAppsActor = classes.some(styleClass =>
            styleClass === 'show-apps' || styleClass === 'show-apps-icon');
        const isInsideShowApps = insideShowApps || isShowAppsActor;

        if (isInsideShowApps && actor instanceof St.Icon)
            icons.add(actor);

        for (const child of this._getChildren(actor))
            this._collectShowAppsIcons(child, isInsideShowApps, icons);
    }

    _getChildren(actor) {
        try {
            return typeof actor.get_children === 'function'
                ? actor.get_children()
                : [];
        } catch (error) {
            return [];
        }
    }

    _getStyleClasses(actor) {
        try {
            const classes = actor.get_style_class_name?.() ?? '';
            return classes.split(/\s+/).filter(Boolean);
        } catch (error) {
            return [];
        }
    }

    _patchIcon(icon) {
        if (!this._patchedIcons.has(icon)) {
            const original = {
                gicon: this._readProperty(icon, 'get_gicon', 'gicon'),
                iconName: this._readProperty(icon, 'get_icon_name', 'icon_name'),
                destroySignalId: 0,
            };

            try {
                original.destroySignalId = icon.connect('destroy', () => {
                    this._patchedIcons?.delete(icon);
                });
            } catch (error) {
                this._logError('failed to watch a Show Applications icon', error);
            }

            this._patchedIcons.set(icon, original);
        }

        try {
            if (typeof icon.set_gicon === 'function')
                icon.set_gicon(this._gicon);
            else
                icon.gicon = this._gicon;
        } catch (error) {
            this._logError('failed to set a Show Applications icon', error);
        }
    }

    _restoreIcons() {
        for (const [icon, original] of this._patchedIcons ?? []) {
            try {
                if (original.destroySignalId)
                    icon.disconnect(original.destroySignalId);

                this._writeProperty(
                    icon, 'set_icon_name', 'icon_name', original.iconName);
                this._writeProperty(
                    icon, 'set_gicon', 'gicon', original.gicon);
            } catch (error) {
                this._logError('failed to restore a Show Applications icon', error);
            }
        }

        this._patchedIcons?.clear();
    }

    _readProperty(object, getter, property) {
        try {
            return typeof object[getter] === 'function'
                ? object[getter]()
                : object[property];
        } catch (error) {
            return null;
        }
    }

    _writeProperty(object, setter, property, value) {
        if (typeof object[setter] === 'function')
            object[setter](value);
        else
            object[property] = value;
    }

    _logError(message, error) {
        console.error(`${this.uuid}: ${message}: ${error?.stack ?? error}`);
    }
}
