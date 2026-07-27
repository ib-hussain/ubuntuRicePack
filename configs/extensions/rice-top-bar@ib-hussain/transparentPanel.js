// Force a genuinely transparent GNOME panel while preserving any inline style
// that another extension installed before Rice Top Bar.

import * as Main from 'resource:///org/gnome/shell/ui/main.js';

const TRANSPARENT_STYLE = [
    'background-color: rgba(0, 0, 0, 0)',
    'box-shadow: none',
].join('; ');

function errorDetails(error) {
    return error?.stack ?? error?.message ?? String(error);
}

export class TransparentPanelController {
    constructor(logPrefix) {
        this._logPrefix = logPrefix;
        this._states = [];

        try {
            this._apply(Main.layoutManager.panelBox, 'panelBox');
            this._apply(Main.panel, 'panel');
            Main.panel.add_style_class_name('rice-transparent-panel');
        } catch (error) {
            this.destroy();
            throw error;
        }
    }

    _apply(actor, name) {
        if (!actor)
            throw new Error(`GNOME Shell ${name} actor is unavailable`);

        const previousStyle = actor.get_style?.() ?? null;
        const combinedStyle = previousStyle
            ? `${previousStyle}; ${TRANSPARENT_STYLE}`
            : TRANSPARENT_STYLE;

        actor.set_style(combinedStyle);
        this._states.push({
            actor,
            name,
            previousStyle,
            appliedStyle: actor.get_style?.() ?? combinedStyle,
        });

        console.log(
            `${this._logPrefix} applied transparent inline style to ${name}`);
    }

    destroy() {
        try {
            Main.panel?.remove_style_class_name('rice-transparent-panel');
        } catch (error) {
            console.warn(
                `${this._logPrefix} could not remove panel style class: ` +
                errorDetails(error));
        }

        for (const state of this._states.splice(0).reverse()) {
            try {
                const currentStyle = state.actor.get_style?.() ?? null;
                if (currentStyle !== state.appliedStyle) {
                    console.warn(
                        `${this._logPrefix} ${state.name} inline style changed ` +
                        'after enable; leaving the newer style intact');
                    continue;
                }

                state.actor.set_style(state.previousStyle);
            } catch (error) {
                console.error(
                    `${this._logPrefix} could not restore ${state.name} style: ` +
                    errorDetails(error));
            }
        }
    }
}
