#!/usr/bin/env bash
set -e

echo "Setting up SSH configuration..."

# Create .ssh directory if it doesn't exist (only if not mounted)
if [ ! -d ~/.ssh ]; then
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
fi

# Try to set correct permissions for .ssh directory (may fail if mounted read-only, that's ok)
chmod 700 ~/.ssh 2>/dev/null || echo "Note: SSH directory permissions may be read-only (mounted from host)"

# Set correct permissions for SSH files (may fail if mounted read-only, that's ok)
if [ -d ~/.ssh ]; then
    # Fix permissions for all files in .ssh
    find ~/.ssh -type f -exec chmod 600 {} \; 2>/dev/null || true
    find ~/.ssh -type d -exec chmod 700 {} \; 2>/dev/null || true
    
    # Ensure config file has correct permissions if it exists
    if [ -f ~/.ssh/config ]; then
        chmod 600 ~/.ssh/config 2>/dev/null || true
    fi
    
    # Ensure known_hosts has correct permissions if it exists
    if [ -f ~/.ssh/known_hosts ]; then
        chmod 644 ~/.ssh/known_hosts 2>/dev/null || true
    fi
    
    # List contents for debugging
    echo "SSH directory contents:"
    ls -la ~/.ssh || echo "Could not list SSH directory"
else
    echo "Warning: SSH directory does not exist"
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
ssh -T git@github.com 2>&1 | head -1 || echo "SSH test completed (exit code is normal for test)"

echo "SSH setup complete!"

