# UbuntuRicePack validation

Run the complete offline product validator from the repository root:

```bash
bash tests/validate-rice-product.sh
```

It checks shell syntax, generated helper scripts, theme XML/UI files, Nautilus
Python syntax and location, portable VS Code restoration, required Ubuntu
packages, verified/cached Nerd Fonts, Ptyxis configuration, wallpaper caching,
GNOME extension metadata and schemas, the dock logo invariant, top-bar
transparency, Ubuntu 25.04/26.04 release profiles, safe/idempotent Plucky APT
archive migration, and the autoinstall template.

Run the release compatibility regression independently with:

```bash
bash tests/validate-release-compat.sh
```

Validate a private generated autoinstall file separately:

```bash
bash tests/validate-autoinstall.sh installation/autoinstall-ready.yaml
```

Validate the tracked template, whose private placeholders are intentionally
unset:

```bash
bash tests/validate-autoinstall.sh \
    --template \
    installation/autoinstall.yaml
```

The validators are static and do not partition disks, install packages, or
change the current GNOME session.
