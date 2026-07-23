import Gio from 'gi://Gio';
import St from 'gi://St';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

export default class RiceArchShowAppsIconExtension extends Extension {
    enable() {
        this._iconFile = this.dir.get_child('icons').get_child('arch-logo.png');
        this._gicon = new Gio.FileIcon({file: this._iconFile});
        this._signalIds = [];

        // Patch once now (covers the icon already on screen, e.g. in the dash)
        this._patchAll();

        // Re-patch only when the overview is shown/hidden, since that's the
        // only time the "Show Apps" icon actually gets created/recreated.
        // This replaces the old 750ms full-tree-walk polling loop, which
        // was the cause of the periodic Shell freezes.
        const overviewShownId = Main.overview.connect('showing', () => this._patchAll());
        const overviewHiddenId = Main.overview.connect('hidden', () => this._patchAll());
        this._signalIds.push([Main.overview, overviewShownId]);
        this._signalIds.push([Main.overview, overviewHiddenId]);

        // Dash-to-Dock rebuilds its "Show Apps" button when its settings
        // change (position, icon size, etc). If dash-to-dock is installed,
        // listen for that too so the icon survives dock reconfiguration.
        if (Main.overview.dash && Main.overview.dash._showAppsIcon) {
            const dash = Main.overview.dash;
            const dashId = dash.connect('notify::visible', () => this._patchAll());
            this._signalIds.push([dash, dashId]);
        }
    }

    disable() {
        for (const [obj, id] of this._signalIds)
            obj.disconnect(id);
        this._signalIds = [];
    }

    _patchAll() {
        try {
            this._walk(Main.uiGroup);
        } catch (e) {
        }

        try {
            this._walk(Main.layoutManager.uiGroup);
        } catch (e) {
        }
    }

    _walk(actor) {
        if (!actor)
            return;

        this._maybePatch(actor);

        let children = [];
        try {
            if (typeof actor.get_children === 'function')
                children = actor.get_children();
        } catch (e) {
            children = [];
        }

        for (const child of children)
            this._walk(child);
    }

    _styleClass(actor) {
        try {
            if (typeof actor.get_style_class_name === 'function')
                return actor.get_style_class_name() || '';
        } catch (e) {
        }

        return '';
    }

    _hasShowAppsParent(actor) {
        let current = actor;

        for (let i = 0; i < 7 && current; i++) {
            const klass = this._styleClass(current).toLowerCase();

            if (klass.includes('show-apps') || klass.includes('showapps'))
                return true;

            try {
                current = current.get_parent();
            } catch (e) {
                current = null;
            }
        }

        return false;
    }

    _iconName(actor) {
        try {
            if (typeof actor.get_icon_name === 'function')
                return actor.get_icon_name() || '';
        } catch (e) {
        }

        try {
            return actor.icon_name || '';
        } catch (e) {
            return '';
        }
    }

    _maybePatch(actor) {
        if (!(actor instanceof St.Icon))
            return;

        const name = this._iconName(actor).toLowerCase();
        const parentMatch = this._hasShowAppsParent(actor);

        const nameMatch =
            name.includes('view-app-grid') ||
            name.includes('applications-all') ||
            name.includes('applications-system') ||
            name.includes('start-here');

        if (!parentMatch && !nameMatch)
            return;

        try {
            actor.set_gicon(this._gicon);
        } catch (e) {
            try {
                actor.gicon = this._gicon;
            } catch (e2) {
            }
        }

        try {
            actor.set_icon_size(48);
        } catch (e) {
        }
    }
}

