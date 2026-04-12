Drop any extra local patches in this directory as `*.patch`.

The build script applies them in lexical order after upstream `makepkg --nobuild` has prepared the source tree.

Patch policy:

- keep this directory small
- only carry patches for a concrete problem you can reproduce
- prefer upstreamed fixes when available