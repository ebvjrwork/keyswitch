# 🔑 keyswitch

A simple, self-installing SSH key management tool for developers who work with multiple accounts and contexts. Easily create, switch, and manage SSH keys for GitHub, GitLab, and other SSH services.

## ✨ Features

- **Zero Dependencies**: Pure Bash script that works on any Linux distro and macOS
- **One-Line Installation**: Install with a single curl command
- **Easy Key Management**: Create, switch, and view SSH keys with simple commands
- **SSH Agent Integration**: Seamlessly loads keys into ssh-agent
- **Backup & Restore**: Protect your SSH configuration with built-in backup tools
- **Cross-Platform**: Works on Linux and macOS out of the box

## 🚀 Quick Start

### Installation

Install keyswitch with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/github-switch/main/keyswitch.sh | sh
```

Or download and install manually:

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/github-switch/main/keyswitch.sh -o keyswitch.sh
chmod +x keyswitch.sh
./keyswitch.sh install
```

### Basic Usage

```bash
# Create a new SSH key for work
keyswitch create work

# View the public key (to add to GitHub)
keyswitch view work

# Load the key into ssh-agent
keyswitch set work

# List all your keys
keyswitch list

# Test the connection
keyswitch test work
```

## 📖 Commands

### `create <name>`

Create a new SSH key with the specified name.

```bash
keyswitch create personal
```

- Prompts for key type (ed25519 recommended, rsa for legacy)
- Option to add passphrase (leave blank for no passphrase)
- Stores key in `~/.ssh/keyswitch_<name>`

### `set <name>`

Load the specified SSH key into ssh-agent for the current session.

```bash
keyswitch set work
```

- Adds key to ssh-agent
- Key will be used for SSH connections
- Tracks last used timestamp

### `view <name>`

Display the public key and copy instructions.

```bash
keyswitch view personal
```

- Shows public key content
- Displays key fingerprint and metadata
- Provides links to add keys to GitHub, GitLab, etc.

### `list`

Show all managed SSH keys with their status.

```bash
keyswitch list
```

- Displays all keys with metadata
- Shows which keys are currently loaded in ssh-agent
- Includes creation date and last used information

### `test <name> [host]`

Test SSH connection using the specified key.

```bash
keyswitch test work git@github.com
```

Default host is `git@github.com` if not specified.

### `backup`

Create a timestamped backup of your entire `~/.ssh` directory.

```bash
keyswitch backup
```

- Backups stored in `~/keyswitch_backups/`
- Includes all SSH keys and configuration
- Timestamped for easy identification

### `restore`

Restore your `~/.ssh` directory from a previous backup.

```bash
keyswitch restore
```

- Lists available backups
- Creates safety backup before restoring
- Interactive confirmation required

## 💡 Common Workflows

### Setting Up Multiple GitHub Accounts

**Step 1: Create keys for each account**

```bash
# Personal GitHub account
keyswitch create github-personal

# Work GitHub account
keyswitch create github-work
```

**Step 2: Add public keys to GitHub**

```bash
# View personal key
keyswitch view github-personal
# Copy the output and add to https://github.com/settings/keys

# View work key
keyswitch view github-work
# Copy the output and add to your work GitHub account
```

**Step 3: Configure SSH for different hosts**

Add to your `~/.ssh/config`:

```
# Personal GitHub
Host github-personal
    HostName github.com
    User git
    IdentityFile ~/.ssh/keyswitch_github-personal
    IdentitiesOnly yes

# Work GitHub
Host github-work
    HostName github.com
    User git
    IdentityFile ~/.ssh/keyswitch_github-work
    IdentitiesOnly yes
```

**Step 4: Clone repositories using the appropriate host**

```bash
# Personal repo
git clone git@github-personal:username/personal-repo.git

# Work repo
git clone git@github-work:company/work-repo.git
```

### Quick Key Switching

If you prefer to use ssh-agent to switch between keys:

```bash
# Load work key for current session
keyswitch set work

# Verify it's loaded
keyswitch list

# Test connection
keyswitch test work

# When you need to switch, clear agent and load different key
ssh-add -D
keyswitch set personal
```

### Before Making SSH Changes

Always backup before making significant changes:

```bash
# Create backup
keyswitch backup

# Make your changes...

# If something goes wrong, restore
keyswitch restore
```

## 🔧 Requirements

- **Bash** 3.2 or later (pre-installed on Linux and macOS)
- **OpenSSH** (ssh-keygen, ssh-add, ssh)
- **ssh-agent** running (for the `set` command)

### Starting ssh-agent

If you get an error about ssh-agent not running, start it with:

```bash
eval $(ssh-agent)
```

To start ssh-agent automatically, add this to your `~/.bashrc` or `~/.zshrc`:

```bash
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval $(ssh-agent) > /dev/null
fi
```

## 📁 File Locations

- **Installed binary**: `/usr/local/bin/keyswitch` or `~/.local/bin/keyswitch`
- **SSH keys**: `~/.ssh/keyswitch_<name>` and `~/.ssh/keyswitch_<name>.pub`
- **Configuration**: `~/.ssh/.keyswitch_config`
- **Backups**: `~/keyswitch_backups/`

## 🛡️ Security Best Practices

1. **Use passphrases**: Add passphrases to your SSH keys for extra security
2. **Use ed25519**: Modern, secure, and fast (default recommendation)
3. **Regular backups**: Run `keyswitch backup` periodically
4. **Separate keys**: Use different keys for work and personal accounts
5. **Review loaded keys**: Run `ssh-add -l` to see what's in your agent
6. **Audit access**: Regularly review authorized keys on GitHub/GitLab

## 🔄 Uninstallation

To remove keyswitch:

```bash
# Remove the binary
sudo rm /usr/local/bin/keyswitch
# or
rm ~/.local/bin/keyswitch

# Optionally remove managed keys and config
# WARNING: This will delete your SSH keys!
rm ~/.ssh/keyswitch_*
rm ~/.ssh/.keyswitch_config

# Optionally remove backups
rm -rf ~/keyswitch_backups
```

## ❓ Troubleshooting

### "ssh-agent is not running"

Start ssh-agent:
```bash
eval $(ssh-agent)
```

### "Permission denied (publickey)"

1. Make sure you've added the public key to your service (GitHub/GitLab)
2. Verify the key is loaded: `ssh-add -l`
3. Test the connection: `keyswitch test <name>`

### Keys not showing up with `keyswitch list`

The config file might be corrupted. Check `~/.ssh/.keyswitch_config` or recreate your keys.

### "Bad owner or permissions" error

SSH requires specific permissions:
```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/keyswitch_*
chmod 644 ~/.ssh/keyswitch_*.pub
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

MIT License - see LICENSE file for details

## 🙏 Acknowledgments

Built for developers who manage multiple SSH keys across different work contexts.

---

**Made with ❤️ for the developer community**
