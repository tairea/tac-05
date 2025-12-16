# ADW Webhook Deployment Guide - Hetzner VPS

This guide shows how to deploy the ADW webhook server to a Hetzner VPS for production use.

## Prerequisites

- Hetzner VPS with Ubuntu 22.04+ (or similar)
- Domain name (optional but recommended for HTTPS)
- SSH access to the VPS
- GitHub repository with admin access

## Quick Deployment

### 1. Initial VPS Setup

SSH into your VPS:
```bash
ssh root@your-vps-ip
```

Update system and install dependencies:
```bash
# Update system
apt update && apt upgrade -y

# Install required packages
apt install -y git curl python3-pip nginx certbot python3-certbot-nginx

# Install uv (Python package manager)
curl -LsSf https://astral.sh/uv/install.sh | sh
source $HOME/.cargo/env

# Install GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
apt update
apt install -y gh

# Install Claude Code CLI
# Follow instructions at: https://docs.anthropic.com/en/docs/claude-code
# Typically: curl -fsSL https://download.anthropic.com/claude/install.sh | sh
```

### 2. Clone Repository

```bash
# Create app directory
mkdir -p /opt/adw
cd /opt/adw

# Clone your repository
git clone https://github.com/YOUR-USERNAME/YOUR-REPO.git .

# Alternatively, if using SSH:
# git clone git@github.com:YOUR-USERNAME/YOUR-REPO.git .
```

### 3. Configure Environment Variables

Create environment file:
```bash
nano /opt/adw/.env
```

Add your configuration:
```env
# GitHub Configuration
GITHUB_REPO_URL=https://github.com/YOUR-USERNAME/YOUR-REPO
GITHUB_PAT=ghp_your_github_personal_access_token

# Claude/Anthropic Configuration
ANTHROPIC_API_KEY=sk-ant-your_anthropic_api_key
CLAUDE_CODE_PATH=/root/.local/bin/claude

# Webhook Server Configuration
PORT=8001
```

Secure the file:
```bash
chmod 600 /opt/adw/.env
```

### 4. Authenticate GitHub CLI

```bash
gh auth login
# Follow prompts to authenticate
```

### 5. Set Up Systemd Service

Copy the service file:
```bash
cp /opt/adw/adws/deploy/adw-webhook.service /etc/systemd/system/
```

Reload systemd and start service:
```bash
systemctl daemon-reload
systemctl enable adw-webhook
systemctl start adw-webhook
```

Check status:
```bash
systemctl status adw-webhook
```

View logs:
```bash
journalctl -u adw-webhook -f
```

### 6. Configure Nginx Reverse Proxy (Recommended)

Copy nginx config:
```bash
cp /opt/adw/adws/deploy/nginx-adw-webhook.conf /etc/nginx/sites-available/adw-webhook
```

Edit the config:
```bash
nano /etc/nginx/sites-available/adw-webhook
```

Update `server_name` with your domain:
```nginx
server_name webhook.yourdomain.com;
```

Enable the site:
```bash
ln -s /etc/nginx/sites-available/adw-webhook /etc/nginx/sites-enabled/
nginx -t
systemctl reload nginx
```

### 7. Set Up HTTPS with Let's Encrypt (Recommended)

```bash
certbot --nginx -d webhook.yourdomain.com
```

Follow prompts to configure HTTPS.

### 8. Configure GitHub Webhook

1. Go to your GitHub repository
2. Navigate to: **Settings** → **Webhooks** → **Add webhook**
3. Configure:
   - **Payload URL**:
     - With domain: `https://webhook.yourdomain.com/gh-webhook`
     - Without domain: `http://YOUR-VPS-IP:8001/gh-webhook`
   - **Content type**: `application/json`
   - **Secret**: (optional but recommended - add webhook secret validation)
   - **Events**: Select individual events
     - ✅ Issues
     - ✅ Issue comments
   - **Active**: ✅ Checked
4. Click **Add webhook**

### 9. Test the Setup

Test the health endpoint:
```bash
curl http://localhost:8001/health
# or with domain:
curl https://webhook.yourdomain.com/health
```

Create a test issue with "adw_plan" in the body and watch the logs:
```bash
journalctl -u adw-webhook -f
```

## Without Domain (IP Only Setup)

If you don't have a domain, you can skip nginx and use the webhook directly:

1. Open firewall:
```bash
ufw allow 8001/tcp
```

2. Use IP in GitHub webhook:
```
http://YOUR-VPS-IP:8001/gh-webhook
```

**Note**: This is less secure (no HTTPS) but works for testing.

## Maintenance

### Update Code

```bash
cd /opt/adw
git pull
systemctl restart adw-webhook
```

### View Logs

```bash
# Real-time logs
journalctl -u adw-webhook -f

# Last 100 lines
journalctl -u adw-webhook -n 100

# Logs since today
journalctl -u adw-webhook --since today
```

### Restart Service

```bash
systemctl restart adw-webhook
```

### Stop Service

```bash
systemctl stop adw-webhook
```

## Troubleshooting

### Service won't start

```bash
# Check service status
systemctl status adw-webhook

# Check logs
journalctl -u adw-webhook -n 50

# Common issues:
# - Missing environment variables in .env
# - Wrong paths in service file
# - Claude Code CLI not installed
# - GitHub CLI not authenticated
```

### GitHub webhook shows errors

```bash
# Check webhook logs in GitHub:
# Settings → Webhooks → Edit → Recent Deliveries

# Check service logs
journalctl -u adw-webhook -f

# Test endpoint manually
curl http://localhost:8001/health
```

### Permission issues

```bash
# Ensure proper ownership
chown -R root:root /opt/adw
chmod 600 /opt/adw/.env

# Check service can access files
sudo -u root ls -la /opt/adw
```

## Security Best Practices

1. **Use HTTPS**: Always use a reverse proxy with SSL/TLS
2. **Firewall**: Only open necessary ports (80, 443, 22)
3. **Webhook Secret**: Add secret validation in GitHub webhook
4. **Token Permissions**: Use fine-grained GitHub tokens with minimal permissions
5. **Regular Updates**: Keep system and dependencies updated
6. **Monitoring**: Set up log monitoring and alerts
7. **Rate Limiting**: Consider adding rate limiting in nginx

## Advanced: Multiple Repositories

To handle multiple repositories:

1. Create separate environment files:
```bash
/opt/adw/.env.repo1
/opt/adw/.env.repo2
```

2. Create separate systemd services:
```bash
/etc/systemd/system/adw-webhook-repo1.service
/etc/systemd/system/adw-webhook-repo2.service
```

3. Use different ports (8001, 8002, etc.)

4. Configure separate nginx server blocks

## Monitoring Setup (Optional)

### Set up log rotation

Create `/etc/logrotate.d/adw-webhook`:
```
/var/log/adw-webhook/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
}
```

### Set up alerts

Install and configure monitoring tools:
- Prometheus + Grafana
- Uptime Kuma
- Simple curl-based health checks via cron

## Cost Optimization

- **Hetzner CX11**: ~€4/month (sufficient for low-medium traffic)
- **Anthropic API**: Pay per token usage
- **GitHub API**: Free for public repos, check rate limits

## Support

For issues:
- Check logs: `journalctl -u adw-webhook -f`
- Verify environment: `cat /opt/adw/.env`
- Test health: `curl http://localhost:8001/health`
- GitHub webhook deliveries: Check "Recent Deliveries" tab
