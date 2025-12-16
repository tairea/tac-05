#!/bin/bash
set -e

echo "======================================"
echo "ADW Webhook VPS Setup Script"
echo "======================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root"
    echo "Please run: sudo bash setup-vps.sh"
    exit 1
fi

# Configuration
APP_DIR="/opt/adw"
SERVICE_NAME="adw-webhook"
REPO_URL=""

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Step 1: Get repository URL
echo "Step 1: Repository Configuration"
echo "================================="
read -p "Enter your GitHub repository URL (https://github.com/username/repo): " REPO_URL
if [ -z "$REPO_URL" ]; then
    print_error "Repository URL is required"
    exit 1
fi
print_success "Repository URL set to: $REPO_URL"
echo ""

# Step 2: Update system
echo "Step 2: System Update"
echo "====================="
print_warning "Updating system packages..."
apt update && apt upgrade -y
print_success "System updated"
echo ""

# Step 3: Install dependencies
echo "Step 3: Installing Dependencies"
echo "==============================="

# Install basic tools
print_warning "Installing basic tools..."
apt install -y git curl python3-pip nginx certbot python3-certbot-nginx ufw
print_success "Basic tools installed"

# Install uv
if ! command -v uv &> /dev/null; then
    print_warning "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    source $HOME/.cargo/env
    print_success "uv installed"
else
    print_success "uv already installed"
fi

# Install GitHub CLI
if ! command -v gh &> /dev/null; then
    print_warning "Installing GitHub CLI..."
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    apt update
    apt install -y gh
    print_success "GitHub CLI installed"
else
    print_success "GitHub CLI already installed"
fi

echo ""

# Step 4: Clone repository
echo "Step 4: Repository Setup"
echo "========================"
if [ -d "$APP_DIR" ]; then
    print_warning "Directory $APP_DIR already exists. Do you want to remove it? (y/N)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        rm -rf "$APP_DIR"
        print_success "Removed existing directory"
    else
        print_error "Aborting. Please manually handle existing directory."
        exit 1
    fi
fi

print_warning "Cloning repository..."
mkdir -p "$APP_DIR"
git clone "$REPO_URL" "$APP_DIR"
print_success "Repository cloned to $APP_DIR"
echo ""

# Step 5: Configure environment
echo "Step 5: Environment Configuration"
echo "=================================="
print_warning "Creating .env file..."

read -p "Enter GITHUB_REPO_URL: " github_repo_url
read -p "Enter GITHUB_PAT (Personal Access Token): " github_pat
read -p "Enter ANTHROPIC_API_KEY: " anthropic_key
read -p "Enter CLAUDE_CODE_PATH [default: /root/.local/bin/claude]: " claude_path
claude_path=${claude_path:-/root/.local/bin/claude}
read -p "Enter PORT [default: 8001]: " port
port=${port:-8001}

cat > "$APP_DIR/.env" << EOF
# GitHub Configuration
GITHUB_REPO_URL=$github_repo_url
GITHUB_PAT=$github_pat

# Claude/Anthropic Configuration
ANTHROPIC_API_KEY=$anthropic_key
CLAUDE_CODE_PATH=$claude_path

# Webhook Server Configuration
PORT=$port
EOF

chmod 600 "$APP_DIR/.env"
print_success ".env file created and secured"
echo ""

# Step 6: GitHub authentication
echo "Step 6: GitHub CLI Authentication"
echo "=================================="
print_warning "You need to authenticate with GitHub CLI"
print_warning "Run: gh auth login"
echo ""
read -p "Press Enter when you're ready to authenticate..."
gh auth login
print_success "GitHub CLI authenticated"
echo ""

# Step 7: Claude Code CLI
echo "Step 7: Claude Code CLI"
echo "======================="
if ! command -v claude &> /dev/null; then
    print_warning "Claude Code CLI not found"
    print_warning "Please install it from: https://docs.anthropic.com/en/docs/claude-code"
    read -p "Press Enter after you've installed Claude Code CLI..."
fi

if command -v claude &> /dev/null; then
    print_success "Claude Code CLI is installed"
else
    print_error "Claude Code CLI still not found. Please install manually."
fi
echo ""

# Step 8: Install systemd service
echo "Step 8: Systemd Service Setup"
echo "=============================="
print_warning "Installing systemd service..."

# Update service file with correct paths
sed -i "s|WorkingDirectory=.*|WorkingDirectory=$APP_DIR/adws|g" "$APP_DIR/adws/deploy/adw-webhook.service"
sed -i "s|EnvironmentFile=.*|EnvironmentFile=$APP_DIR/.env|g" "$APP_DIR/adws/deploy/adw-webhook.service"

cp "$APP_DIR/adws/deploy/adw-webhook.service" "/etc/systemd/system/$SERVICE_NAME.service"
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl start "$SERVICE_NAME"

print_success "Systemd service installed and started"
echo ""

# Step 9: Nginx setup (optional)
echo "Step 9: Nginx Setup (Optional)"
echo "=============================="
read -p "Do you want to set up Nginx reverse proxy? (y/N): " setup_nginx

if [[ "$setup_nginx" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    read -p "Enter your domain name (e.g., webhook.yourdomain.com): " domain_name

    if [ -z "$domain_name" ]; then
        print_warning "No domain provided, skipping Nginx setup"
    else
        # Update nginx config with domain
        sed -i "s|server_name .*|server_name $domain_name;|g" "$APP_DIR/adws/deploy/nginx-adw-webhook.conf"

        cp "$APP_DIR/adws/deploy/nginx-adw-webhook.conf" "/etc/nginx/sites-available/adw-webhook"
        ln -sf "/etc/nginx/sites-available/adw-webhook" "/etc/nginx/sites-enabled/adw-webhook"

        nginx -t && systemctl reload nginx
        print_success "Nginx configured for domain: $domain_name"

        # SSL setup
        read -p "Do you want to set up SSL with Let's Encrypt? (y/N): " setup_ssl
        if [[ "$setup_ssl" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            certbot --nginx -d "$domain_name"
            print_success "SSL certificate installed"
        fi
    fi
else
    print_warning "Skipping Nginx setup. Webhook will be accessible at http://SERVER-IP:$port"
fi
echo ""

# Step 10: Firewall
echo "Step 10: Firewall Configuration"
echo "================================"
read -p "Do you want to configure UFW firewall? (y/N): " setup_firewall

if [[ "$setup_firewall" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    ufw allow ssh
    ufw allow http
    ufw allow https
    if [[ ! "$setup_nginx" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        ufw allow "$port/tcp"
    fi
    echo "y" | ufw enable
    print_success "Firewall configured"
else
    print_warning "Skipping firewall configuration"
fi
echo ""

# Step 11: Test the setup
echo "Step 11: Testing Setup"
echo "======================"
print_warning "Testing webhook service..."
sleep 2

if systemctl is-active --quiet "$SERVICE_NAME"; then
    print_success "Service is running"

    print_warning "Testing health endpoint..."
    if curl -s http://localhost:$port/health > /dev/null; then
        print_success "Health endpoint responding"
    else
        print_error "Health endpoint not responding"
    fi
else
    print_error "Service is not running"
    echo "Check logs with: journalctl -u $SERVICE_NAME -n 50"
fi
echo ""

# Summary
echo "======================================"
echo "Setup Complete!"
echo "======================================"
echo ""
echo "Next Steps:"
echo ""
echo "1. Configure GitHub Webhook:"
if [[ "$setup_nginx" =~ ^([yY][eE][sS]|[yY])$ ]] && [ ! -z "$domain_name" ]; then
    echo "   - URL: https://$domain_name/gh-webhook"
else
    SERVER_IP=$(curl -s ifconfig.me)
    echo "   - URL: http://$SERVER_IP:$port/gh-webhook"
fi
echo "   - Content type: application/json"
echo "   - Events: Issues, Issue comments"
echo ""
echo "2. Test the webhook by creating an issue with 'adw_plan' in the body"
echo ""
echo "3. Monitor logs:"
echo "   journalctl -u $SERVICE_NAME -f"
echo ""
echo "4. Check service status:"
echo "   systemctl status $SERVICE_NAME"
echo ""
echo "5. Test health endpoint:"
echo "   curl http://localhost:$port/health"
echo ""

print_success "All done!"
