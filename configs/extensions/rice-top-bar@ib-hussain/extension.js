/**
 * This file is part of Hide Top Bar
 *
 * Copyright 2020 Thomas Vogt
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import * as Main from 'resource:///org/gnome/shell/ui/main.js';

import * as PanelVisibilityManager from './panelVisibilityManager.js';
import {TransparentPanelController} from './transparentPanel.js';
import * as Convenience from './convenience.js';
const DEBUG = Convenience.DEBUG;

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

const LOG_PREFIX = '[rice-top-bar@ib-hussain]';

function errorDetails(error) {
    return error?.stack ?? error?.message ?? String(error);
}

export default class RiceTopBarExtension extends Extension {
    constructor(metadata) {
        super(metadata);
        this._settings = null;
        this._panelVisibilityManager = null;
        this._transparentPanel = null;
    }

    enable() {
        DEBUG("enable()");
        console.log(`${LOG_PREFIX} enabling`);

        try {
            this._settings = this.getSettings();
            this._transparentPanel = new TransparentPanelController(LOG_PREFIX);
            this._panelVisibilityManager =
                new PanelVisibilityManager.PanelVisibilityManager(
                    this._settings,
                    Main.layoutManager.primaryIndex,
                );
            console.log(
                `${LOG_PREFIX} enabled; transparent panel style is active`);
        } catch (error) {
            console.error(
                `${LOG_PREFIX} enable failed: ${errorDetails(error)}`);
            this._panelVisibilityManager?.destroy();
            this._transparentPanel?.destroy();
            this._panelVisibilityManager = null;
            this._transparentPanel = null;
            this._settings = null;
            throw error;
        }
    }

    disable() {
        DEBUG("disable()");
        try {
            this._panelVisibilityManager?.destroy();
        } catch (error) {
            console.error(
                `${LOG_PREFIX} panel visibility cleanup failed: ` +
                errorDetails(error));
        }

        try {
            this._transparentPanel?.destroy();
        } catch (error) {
            console.error(
                `${LOG_PREFIX} transparent style cleanup failed: ` +
                errorDetails(error));
        }

        this._panelVisibilityManager = null;
        this._transparentPanel = null;
        this._settings = null;
        console.log(`${LOG_PREFIX} disabled`);
    }
}
