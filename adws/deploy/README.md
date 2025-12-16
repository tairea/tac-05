# ADW Webhook Deployment Files

This directory contains deployment files for running the ADW webhook on a VPS.

## Quick Start

### Automated Setup (Recommended)

SSH into your VPS and run:

```bash
# Download and run the setup script
curl -fsSL https://raw.githubusercontent.com/YOUR-USERNAME/YOUR-REPO/main/adws/deploy/setup-vps.sh | sudo bash
```

Or if you've already cloned the repo:

```bash
cd /opt/adw/adws/deploy
sudo bash setup-vps.sh
```

The script will:
- Install all dependencies (uv, gh, nginx, etc.)
- Clone your repository
- Set up environment variables
- Configure systemd service
- Optionally set up Nginx reverse proxy with SSL
- Configure firewall

### Manual Setup

See [DEPLOYMENT.md](../DEPLOYMENT.md) for detailed manual setup instructions.

## Files

- **setup-vps.sh** - Automated setup script
- **adw-webhook.service** - Systemd service file
- **nginx-adw-webhook.conf** - Nginx reverse proxy configuration

## Configuration

After deployment, your webhook will be available at:

- **With domain**: `https://webhook.yourdomain.com/gh-webhook`
- **Without domain**: `http://YOUR-VPS-IP:8001/gh-webhook`

## GitHub Webhook Setup

1. Go to your GitHub repository
2. Settings → Webhooks → Add webhook
3. Configure:
   - **Payload URL**: Your webhook URL (see above)
   - **Content type**: `application/json`
   - **Events**: Select "Issues" and "Issue comments"
   - **Active**: Checked
4. Save webhook

## Monitoring

```bash
# View service status
systemctl status adw-webhook

# View logs in real-time
journalctl -u adw-webhook -f

# Test health endpoint
curl http://localhost:8001/health
```

## Updating

```bash
cd /opt/adw
git pull
systemctl restart adw-webhook
```

## Troubleshooting

### Service won't start
```bash
# Check logs
journalctl -u adw-webhook -n 50

# Check configuration
cat /opt/adw/.env

# Verify paths
which uv
which claude
```

### GitHub webhook fails
- Check webhook delivery logs in GitHub (Settings → Webhooks → Recent Deliveries)
- Verify firewall allows incoming connections
- Test endpoint: `curl http://localhost:8001/health`

### Permission errors
```bash
# Fix ownership
chown -R root:root /opt/adw
chmod 600 /opt/adw/.env
```

## Support

For detailed instructions, see [DEPLOYMENT.md](../DEPLOYMENT.md)
