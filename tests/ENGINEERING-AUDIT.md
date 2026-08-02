# GNOME 48/50 extension engineering audit

## Scope

The supplied archive contained:

- `arch-dock-icon@ib-hussain`
- `dash-to-dock@micxgx.gmail.com`
- `hidetopbar@mathieu.bidon.ca`

Every source, schema, stylesheet, asset, and metadata file in those trees was
inspected and compared with its current upstream counterpart.

## Root-cause findings

### Show Applications logo

The old solution had multiple independent icon sources:

1. `arch-dock-icon` walked the Shell actor tree and assigned a `Gio.FileIcon`.
2. Its stylesheet also placed `arch-logo.png` behind Show Applications as a
   CSS `background-image`.
3. The supplied Dash-to-Dock still constructed GNOME's symbolic
   `view-app-grid-*` icon.

Ubuntu therefore had enough information to render the symbolic app-grid tile
and the Arch bitmap together. The result was the visible logo-on-tile overlay.

The supplied Dash-to-Dock had another unrelated Arch substitution:
`appIconIndicators.js` used an Arch bitmap instead of upstream
`media/glossy.svg`. That asset belongs to the optional Unity-style running-app
background, not to Show Applications, and could put an Arch logo behind
ordinary application icons.

### Top-bar transparency

The supplied Hide Top Bar source was the upstream extension version 124. It
controlled visibility/intellihide but contained no transparent-panel rule or
runtime transparency controller. The transparent Arch screenshot therefore
came from the active GNOME Shell theme, not from Hide Top Bar itself.

Relying on a theme alone was not reliable on Ubuntu because Yaru or another
Shell stylesheet can provide an opaque `#panel` background.

### Password failure

`Authentication token manipulation error` is a PAM return condition. In the
captured interaction it happened after two current-password prompts and before
any new-password prompt, so minimum length was not the failing stage.

The previous `pam_pwquality` override only changed quality enforcement and
could not repair current-token authentication, a duplicated/broken PAM stack,
account-database permissions, a read-only root filesystem, or a damaged
setuid `passwd` executable.

## Implemented products

### Rice Dock 1.0.0

Path:

```text
configs/extensions/rice-dock@ib-hussain/
```

Engineering base:

- Ubuntu Dock / Dash-to-Dock upstream version 106
- Ubuntu Dock branch commit
  `3e8c2a54192b29cbc20605ed278c6ca939d32a62`

Rice changes:

- one cross-distribution UUID;
- one logo file, `media/logo.png`;
- a directly constructed `St.Icon` with one `Gio.FileIcon`;
- no logo CSS background and no symbolic fallback under the bitmap;
- upstream `glossy.svg` restored for running-app effects;
- cross-distribution Rice defaults instead of Ubuntu-session-only defaults;
- conflict detection for Ubuntu Dock and upstream Dash-to-Dock;
- full compiled dock stylesheet plus its reviewed SCSS source;
- explicit lifecycle and exception messages in the GNOME Shell journal.

The extension keeps the upstream
`org.gnome.shell.extensions.dash-to-dock` schema so existing curated settings
remain usable.

### Rice Top Bar 1.0.0

Path:

```text
configs/extensions/rice-top-bar@ib-hussain/
```

Engineering base:

- Hide Top Bar release 126
- reviewed commit
  `aa7d51eb2ddb0ecba717e9c63ca9428a661b2722`

Rice changes:

- current Hide Top Bar intellihide behavior;
- a persistent `rice-transparent-panel` style class;
- explicit transparent styling for `#panel` and `#panelBox`;
- an inline transparent fallback that wins over an opaque Shell theme;
- preservation/restoration of prior inline actor styles;
- guarded lifecycle cleanup and journal diagnostics.

The extension intentionally retains the upstream
`org.gnome.shell.extensions.hidetopbar` schema so exported settings transfer
without migration.

### Password workflow

Path:

```text
scripts/09-set-local-password.sh
```

The helper never reads, accepts, stores, echoes, or journals a password. It
performs read-only diagnostics and opens the system's own privileged
interactive prompt. It also removes only the exact obsolete global
UbuntuRicePack pwquality drop-in, if an earlier revision created it.

No PAM rewrite occurs by default. For a locally damaged or duplicated Ubuntu
PAM stack, the explicit `--repair-pam` mode copies the active `passwd` and
`common-*` files into the per-user state backup directory and then invokes
Ubuntu's packaged-profile manager with `pam-auth-update --force`. This repair
is opt-in because a machine may legitimately contain administrator-managed PAM
modules.

## Conflict policy

Only these custom products are enabled:

```text
rice-dock@ib-hussain
rice-top-bar@ib-hussain
```

These are explicitly disabled:

```text
arch-dock-icon@ib-hussain
dash-to-dock@micxgx.gmail.com
hidetopbar@mathieu.bidon.ca
ubuntu-dock@ubuntu.com
```

This prevents duplicate docks, competing Show Applications actors, and
competing top-bar controllers.

## Validation performed

The deliverable passed:

- Bash syntax parsing for every shell script;
- ECMAScript-module syntax parsing for every custom-extension JavaScript file;
- metadata JSON validation;
- relative JavaScript import closure checks;
- strict GSettings schema compilation for both custom extensions;
- XML/UI well-formedness checks;
- a single-logo invariant check;
- a no-logo-as-CSS-background check;
- transparent CSS and inline-controller checks;
- retired-source absence checks.

The MacTahoe Metacity XML contained four unescaped `<` attribute values. They
were corrected to `&lt;` and the complete XML/UI set then parsed successfully.

## Runtime boundary

Static and build validation can be performed outside GNOME. A real Shell load
must be verified after installation by logging out and back in, then checking:

```bash
gnome-extensions info rice-dock@ib-hussain
gnome-extensions info rice-top-bar@ib-hussain
journalctl --user -b -o cat |
  grep -E '\[(rice-dock|rice-top-bar)@ib-hussain\]'
```

Both extension states must be `ACTIVE`, with no `Error:` field.
