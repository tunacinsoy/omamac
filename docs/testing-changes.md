# Testing a branch

For contributors: run a branch of omamac on a Mac before it is merged.

[← Back to the README](../README.md)

Put the branch in the URL and in `OMAMAC_REF`:

```bash
curl -fsSL https://raw.githubusercontent.com/tunacinsoy/omamac/<branch>/boot.sh | OMAMAC_REF=<branch> bash
```

Run it only in a test VM, never on the Mac you develop on. The full flow, the tests and the merge gate are in [CONTRIBUTING.md](../CONTRIBUTING.md).
