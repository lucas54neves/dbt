#!/usr/bin/env bash
set -e

echo "Setting up SSH configuration..."

# Create .ssh directory in container (not mounted)
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Copy SSH files from mounted host directory to container directory
# This allows us to set correct permissions in the container
if [ -d ~/.ssh-host ] && [ "$(ls -A ~/.ssh-host 2>/dev/null)" ]; then
    echo "Copying SSH files from host mount to container directory..."
    
    # Copy all files from mounted directory
    cp -r ~/.ssh-host/* ~/.ssh/ 2>/dev/null || true
    
    # Set correct permissions for all SSH files (now we can do this since they're copied)
    find ~/.ssh -type f -exec chmod 600 {} \;
    find ~/.ssh -type d -exec chmod 700 {} \;
    
    # Ensure known_hosts has correct permissions (644)
    if [ -f ~/.ssh/known_hosts ]; then
        chmod 644 ~/.ssh/known_hosts
    fi
    
    # Ensure config file has correct permissions (600)
    if [ -f ~/.ssh/config ]; then
        chmod 600 ~/.ssh/config
    fi
    
    echo "SSH files copied and permissions set correctly"
else
    echo "Warning: No SSH files found in mounted directory (~/.ssh-host)"
    echo "If you need SSH access, ensure your host ~/.ssh directory contains your keys"
fi

# List contents for debugging
echo "SSH directory contents:"
ls -la ~/.ssh || echo "Could not list SSH directory"

# Verify permissions
echo "Verifying SSH key permissions..."
if [ -f ~/.ssh/id_rsa ] || [ -f ~/.ssh/id_ed25519 ] || [ -f ~/.ssh/id_ecdsa ]; then
    for key in ~/.ssh/id_*; do
        if [ -f "$key" ] && [ ! -L "$key" ]; then
            perms=$(stat -c "%a" "$key" 2>/dev/null || stat -f "%OLp" "$key" 2>/dev/null || echo "unknown")
            echo "  $key: permissions $perms (should be 600)"
            if [ "$perms" != "600" ]; then
                echo "    WARNING: Incorrect permissions! Attempting to fix..."
                chmod 600 "$key"
            fi
        fi
    done
fi

# Configure git to use SSH for GitHub if not already configured
# Check if .gitconfig is mounted (read-only) - if so, configure locally in workspace
if ! git config --global --get url."git@github.com:".insteadOf > /dev/null 2>&1; then
    echo "Configuring git to use SSH for GitHub..."
    # Try global first, if it fails (mounted read-only), use local config
    if ! git config --global url."git@github.com:".insteadOf "https://github.com/" 2>/dev/null; then
        echo "Note: .gitconfig is mounted read-only, using local workspace config"
        git config url."git@github.com:".insteadOf "https://github.com/"
    fi
fi

# Verify git configuration
echo "Git configuration:"
git config --list | grep -E "(user\.|url\.)" | head -5 || echo "Git config not fully loaded"

# Test SSH connection to GitHub (non-blocking)
echo "Testing SSH connection to GitHub..."
if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    echo "✓ SSH connection to GitHub successful!"
elif ssh -T git@github.com 2>&1 | grep -q "Permission denied"; then
    echo "✗ SSH connection failed: Permission denied"
    echo "  This usually means:"
    echo "  1. Your SSH key is not added to your GitHub account"
    echo "  2. The SSH key permissions are incorrect"
    echo "  3. The SSH key passphrase is required"
    echo ""
    echo "  To debug, run: ssh -vT git@github.com"
else
    echo "SSH test completed (exit code is normal for test)"
fi

echo "SSH setup complete!"

