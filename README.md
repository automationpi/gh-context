# gh-context

A `kubectx`-style context switcher for GitHub CLI.

**Switch between multiple GitHub accounts/hosts with ease.** Perfect for developers who work across personal, work, and client GitHub accounts.

- **Contexts** are named pointers to `{hostname, user, transport, ssh_host_alias}`
- Switch instantly with `gh context use <name>`
- Bind repositories to contexts and optionally auto-apply on `cd`
- Works on top of official `gh auth switch` — never stores tokens itself

## Install

```bash
gh extension install automationpi/gh-context
```
Or manually:
```bash
git clone https://github.com/automationpi/gh-context.git
cd gh-context
chmod +x gh-context
# Add to PATH or symlink to ~/.local/bin/
```

## Quick Start

```bash
# Create a context from your current session
gh context new --from-current --name work

# Or specify explicitly  
gh context new --hostname github.com --user myuser --transport ssh --name personal

# Switch contexts
gh context use work

# See what's active
gh context current
gh context list

# Bind this repo to always use 'work' context
gh context bind work

# Optional: Auto-apply contexts when entering repos
gh context shell-hook >> ~/.bashrc
```

## Commands

| Command | Description |
|---------|-------------|
| `gh context list` | List all contexts with active indicator |
| `gh context current` | Show active context and repo bindings |
| `gh context new [options] --name <name>` | Create a new context |
| `gh context use <name>` | Switch to context |
| `gh context delete <name>` | Remove a context |
| `gh context bind <name>` | Bind current repo to context |
| `gh context unbind` | Remove repo binding |
| `gh context apply` | Apply repo's bound context |
| `gh context shell-hook` | Print shell integration code |
| `gh context auth-status` | Show authentication status for all contexts |

### Creating Contexts

**From current session:**
```bash
gh context new --from-current --name work
```

**Explicit configuration:**
```bash
gh context new \
  --hostname github.com \
  --user myusername \
  --transport ssh \
  --name personal
```

**Enterprise GitHub:**
```bash
gh context new \
  --hostname github.company.com \
  --user john.doe \
  --transport https \
  --name company
```

## How It Works

### Context Storage
- Contexts: `${XDG_CONFIG_HOME:-$HOME/.config}/gh/contexts/<name>.ctx`
- Active pointer: `${XDG_CONFIG_HOME:-$HOME/.config}/gh/contexts/active`
- Repo bindings: `<repo-root>/.ghcontext`

### Switching Process
When you run `gh context use <name>`:

1. **Validates authentication** for the target user/host
2. **Switches auth**: `gh auth switch --hostname <host> --user <user>`
3. **Configures Git**: `gh auth setup-git` 
4. **Refreshes tokens**: `gh auth refresh` (best effort)
5. **Updates active pointer**

### Repository Binding
```bash
# In your project directory
gh context bind work

# This creates .ghcontext containing "work"
# Now when you cd into this repo, you can auto-switch
```

### Shell Integration
Enable auto-context switching when entering bound repositories:

```bash
# Add to ~/.bashrc or ~/.zshrc
gh context shell-hook >> ~/.bashrc
source ~/.bashrc
```

Now when you `cd` into a repo with `.ghcontext`, it automatically applies that context.

## Examples

### Multi-Account Workflow
```bash
# Setup contexts
gh context new --from-current --name personal
gh context new --hostname github.company.com --user john.doe --name work

# Work on personal project
cd ~/personal-project
gh context bind personal
gh context use personal

# Switch to work project  
cd ~/work-project
gh context bind work
gh context use work

# Enable auto-switching
gh context shell-hook >> ~/.bashrc
```

### Enterprise + Personal
```bash
# Personal GitHub
gh context new --hostname github.com --user myuser --name personal

# Company GitHub Enterprise
gh context new --hostname github.company.com --user john.doe --name company

# Client GitHub Enterprise
gh context new --hostname github.client.com --user contractor --name client

gh context list
# Available contexts:
#   personal    (myuser@github.com, ssh)
#   company *   (john.doe@github.company.com, https)  
#   client      (contractor@github.client.com, https)
```

## Configuration Files

Context files are plain `KEY=VALUE` format:
```bash
# ~/.config/gh/contexts/work.ctx
HOSTNAME=github.company.com
USER=john.doe
TRANSPORT=https
SSH_HOST_ALIAS=
```

## Troubleshooting

### Check Authentication Status
Use the built-in diagnostics to see authentication status for all contexts:
```bash
gh context auth-status
```

This shows which contexts are properly authenticated and provides exact commands to fix issues.

### "No authentication found"
```bash
gh auth login --hostname <hostname> --username <username> --scopes repo,read:org
```

### "Authenticated as wrong user" / "Failed to switch to user"
This happens when GitHub CLI has credentials for multiple users on the same host. The extension will try to switch automatically, but if it fails:

```bash
# Check what users are authenticated
gh auth status

# Login as the specific user you need
gh auth login --hostname <hostname> --username <expected-user> --scopes repo,read:org

# Then try the context switch again
gh context use <context-name>
```

### Multiple Users on Same Host (github.com)
GitHub CLI can manage multiple users per hostname. When switching contexts:

1. **First time setup**: Each user must authenticate separately
   ```bash
   gh auth login --hostname github.com --username user1 --scopes repo,read:org
   gh auth login --hostname github.com --username user2 --scopes repo,read:org
   ```

2. **Context switching**: The extension automatically switches between authenticated users
   ```bash
   gh context new --hostname github.com --user user1 --name personal
   gh context new --hostname github.com --user user2 --name work
   gh context use work  # Switches to user2
   gh context use personal  # Switches to user1
   ```

### "Token may be expired"
```bash
gh auth refresh --hostname <hostname>
# Or re-authenticate
gh auth login --hostname <hostname> --username <username> --scopes repo,read:org
```

### Repository Access Issues
If you get "Repository not found" or authentication errors after switching contexts:

1. Verify the context is active: `gh context current`
2. Check authentication: `gh context auth-status`
3. Test access: `gh repo view owner/repo --hostname <hostname>`
4. If needed, refresh credentials: `gh auth refresh --hostname <hostname>`

### Shell Integration Not Working
If auto-context switching isn't working:

1. Make sure the shell hook is loaded: `gh context shell-hook >> ~/.bashrc && source ~/.bashrc`
2. Test in a repo with `.ghcontext`: `cd /path/to/repo && pwd`  
3. Check if `.ghcontext` exists: `cat .ghcontext`

### Clean Start (Reset Everything)
If you need to start fresh:
```bash
# Logout from all hosts
gh auth logout --hostname github.com

# Remove all contexts
rm -rf ~/.config/gh/contexts/

# Start over with authentication
gh auth login --hostname github.com --username <your-username>
gh context new --from-current --name <context-name>
```

## Roadmap

- [ ] `--json` output for scripting
- [ ] `--repo` flag to prefer repo binding over global context
- [ ] Context templates/inheritance
- [ ] Bulk operations on contexts
- [ ] Integration with popular Git workflows

## License

MIT License - see [LICENSE](LICENSE)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Submit a pull request

Built with ❤️ for developers juggling multiple GitHub accounts.