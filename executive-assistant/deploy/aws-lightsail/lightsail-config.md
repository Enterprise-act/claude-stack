# AWS Lightsail Configuration for FSP Executive Assistant

## Instance Specifications

| Setting | Value |
|---------|-------|
| **Blueprint** | Ubuntu 22.04 LTS |
| **Instance Plan** | $20/month (2 GB RAM, 2 vCPUs, 60 GB SSD) |
| **Region** | us-east-1 (or closest to your team) |
| **Instance Name** | fsp-executive-assistant |

## Networking Setup

### Static IP
1. Go to Lightsail → Networking → Create static IP
2. Attach to your instance
3. Note the IP address for n8n webhook configuration

### Firewall Rules
Open these ports in Lightsail console → Instance → Networking:

| Port | Protocol | Description |
|------|----------|-------------|
| 22 | TCP | SSH access |
| 80 | TCP | HTTP (for Let's Encrypt) |
| 443 | TCP | HTTPS (future) |
| 8000 | TCP | API server |

## Quick Launch Commands

### 1. Create Instance (AWS CLI)
```bash
aws lightsail create-instances \
  --instance-names fsp-executive-assistant \
  --availability-zone us-east-1a \
  --blueprint-id ubuntu_22_04 \
  --bundle-id medium_2_0 \
  --tags key=Project,value=FSP-Assistant
```

### 2. Create Static IP
```bash
aws lightsail allocate-static-ip --static-ip-name fsp-assistant-ip
aws lightsail attach-static-ip \
  --static-ip-name fsp-assistant-ip \
  --instance-name fsp-executive-assistant
```

### 3. Open Firewall Ports
```bash
aws lightsail open-instance-public-ports \
  --instance-name fsp-executive-assistant \
  --port-info fromPort=8000,toPort=8000,protocol=TCP
```

## SSH Access

Download your SSH key from Lightsail console, then:
```bash
chmod 600 ~/Downloads/LightsailDefaultKey-us-east-1.pem
ssh -i ~/Downloads/LightsailDefaultKey-us-east-1.pem ubuntu@YOUR_STATIC_IP
```

## After SSH'ing In

Run the setup script:
```bash
curl -fsSL https://raw.githubusercontent.com/carrmjw/claude-stack/main/executive-assistant/deploy/aws-lightsail/setup.sh | bash
```

Then log out and back in (for Docker group permissions):
```bash
exit
ssh -i ~/Downloads/LightsailDefaultKey-us-east-1.pem ubuntu@YOUR_STATIC_IP
```
