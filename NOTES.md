# Security Limitations

Because the archive and its checksum file are both hosted on GitHub, an
attacker who can modify a release can also modify the checksum file. The
checksum therefore protects against accidental corruption and simple
tampering, but it is **not** a cryptographic guarantee of trust.

For stronger trust:

1. Sign the checksum file with a GPG key:

   ```bash
   gpg --armor --detach-sign csound7-linux-full.zip.sha256
   ```

2. Publish the signature (`csound7-linux-full.zip.sha256.asc`) alongside the
   release assets.
3. Add signature verification to this installer using a pinned public key.

