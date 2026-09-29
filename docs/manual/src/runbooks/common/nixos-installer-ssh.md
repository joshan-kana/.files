# Continue a NixOS installer over SSH

Use this when installing a physical machine or VM from a NixOS installer and it is easier to continue from another computer.

Confirm the installer has networking. If it does not, configure it first with NetworkManager:

```sh
ip -br addr
nmtui
```

Install your public GitHub SSH keys for the installer root account, then start OpenSSH:

```sh
sudo install -d -m 0700 /root/.ssh
curl -fsSL https://github.com/joshan-kana.keys \
  | sudo tee /root/.ssh/authorized_keys >/dev/null
sudo chmod 0600 /root/.ssh/authorized_keys
sudo systemctl start sshd
ip -br addr
```

If GitHub is unavailable, place an authorized public key in `/root/.ssh/authorized_keys` by another trusted method instead.

From the computer you are continuing the installation from:

```sh
ssh root@<installer-ip>
```

The installer is temporary, so repeat this setup after rebooting back into installation media. Once the installed NixOS system boots, use its normal declarative SSH configuration instead.
