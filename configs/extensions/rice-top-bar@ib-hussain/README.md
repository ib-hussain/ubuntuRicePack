# Rice Top Bar

Rice Top Bar combines Hide Top Bar 126 with a deterministic transparent-panel
controller for Ibrahim's GNOME rice.

The original Hide Top Bar extension only moves and hides the panel; it does not
make the panel transparent. On Arch, transparency came from the MacTahoe Shell
theme. Rice Top Bar keeps that CSS and also applies a reversible inline style to
GNOME Shell's `panel` and `panelBox` actors. This makes the result independent
of Ubuntu's theme load order.

Settings remain in `org.gnome.shell.extensions.hidetopbar`, so the exported
Hide Top Bar preferences continue to apply.

## Logs

```bash
journalctl --user -b -o cat | grep -F '[rice-top-bar@ib-hussain]'
```

## Upstream and license

- Upstream: https://gitlab.gnome.org/tuxor1337/hidetopbar
- Reviewed upstream release: 126
- Rice Top Bar release: 1.0.0

Hide Top Bar is GPL-3.0-or-later. See `COPYING.txt`.
