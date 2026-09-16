# security/

## `ublue-bazzite-cosign.pub`

Vendored copy of `ublue-os/bazzite`'s cosign public key, used by
`.github/workflows/build.yml` to verify `ghcr.io/ublue-os/bazzite-nvidia`
(our `FROM` base) before building on top of it — so a compromised or
tampered base image fails the build instead of silently becoming part
of Rosaline OS.

Fetched from
<https://raw.githubusercontent.com/ublue-os/bazzite/main/cosign.pub> and
confirmed, byte-for-byte, to be the actual key used to sign the
published `ghcr.io/ublue-os/bazzite-nvidia:stable` image (decoded the
image's attached Rekor transparency-log entry directly and compared the
embedded public key). If ublue ever rotates their signing key, this
file needs updating to match, or the verify step in `build.yml` starts
failing on real, legitimate images.

If you retarget the Containerfile's `BASE_IMAGE` away from
`ublue-os/bazzite-nvidia`, update this file (or the verify step) to
match the new base's actual signing key -- don't just delete the
check.

## `cosign.pub` (repo root, not here)

Rosaline OS's own public key, used two ways:
- By anyone wanting to verify a published `ghcr.io/gangstapichu/rosaline-os`
  image by hand: `cosign verify --key cosign.pub --new-bundle-format=false ghcr.io/gangstapichu/rosaline-os:latest`
- Baked into the image itself at
  `system_files/etc/containers/policy.json` (as base64 `keyData`, since
  `policy.json` needs no external file reference) so that once a
  machine is running Rosaline OS, `bootc upgrade` / `podman pull`
  verify every subsequent update against it.

The matching private key is `secrets.SIGNING_SECRET` in the repo's
GitHub Actions secrets (a passphrase-protected cosign key; the
passphrase is `secrets.SIGNING_SECRET_PASSWORD`) -- it is not, and must
never be, committed here. See "Rotating the signing key" below if it's
ever lost or needs replacing.

## Known limitation: tag substitution

Cosign signatures only assert *repository* identity, not the specific
tag (`policy.json`'s `sigstoreSigned` requirement can only use
`matchRepository`/`exactRepository` for them -- see
`man containers-policy.json`). Verification confirms an image came from
`ghcr.io/gangstapichu/rosaline-os` and was signed with our key; it does
NOT confirm you received the specific tag you asked for over a
substitution of another signed tag from the same repo. This is a
limitation of cosign's identity model generally, not something specific
to our setup.

## Rotating the signing key

1. `cosign generate-key-pair` (needs a passphrase -- store it as
   `SIGNING_SECRET_PASSWORD`).
2. Replace `cosign.pub` at the repo root.
3. Recompute the `keyData` in
   `system_files/etc/containers/policy.json` (base64 of the new
   `cosign.pub`, no line breaks: `base64 -w0 cosign.pub`).
4. Replace the `SIGNING_SECRET` GitHub Actions secret with the new
   private key's contents.
5. Existing installs won't trust the new key until they update at
   least once more from an image signed with the *old* key that
   already carries the new `policy.json` -- i.e. ship the new
   `policy.json` in one release signed with the old key before
   retiring it, so upgraders pick up the new trust root before it's
   needed.
