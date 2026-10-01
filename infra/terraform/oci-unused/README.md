# ⚠️ UNUSED: Oracle Cloud (OCI) Always Free target

**Status: parked, not deployed.** Kept for reference only. Nothing here is wired into CI,
scripts or docs, and no OCI resources were ever created.

**Why it's parked:** Oracle Cloud signup requires a credit card for identity verification
("most users need a mobile phone number and a credit card to create an account").
This project must work with no card, so the cloud target moved to
[Azure for Students](../azure/), which needs only a school email.

**What it contains (tested, ready to use if a card ever becomes an option):**

- VCN, public subnet, internet gateway, route table and security list (SSH from one /32,
  HTTP/HTTPS open, Kubernetes API closed), plus a `VM.Standard.A1.Flex` instance
  (2 OCPU / 12 GB / 50 GB, Ubuntu 24.04 arm64) that installs k3s via cloud-init.
- Variable validations that reject anything beyond the Always Free allowance.
- Offline tests with a mocked provider: `tofu test` (5/5 passing on 2026-10-01).
- `oci.ps1`: a wrapper that reads credentials from `~/.oci/config` without printing them.

The multi-arch (amd64 + arm64) CI image built for this target is still in use. It costs
nothing extra, and it keeps arm64 hosts such as Raspberry Pi or Graviton possible.
