# DAPSZ Protection - Pterodactyl Edition

```
   ██████╗  █████╗ ██████╗ ███████╗███████╗
   ██╔══██╗██╔══██╗██╔══██╗██╔════╝╚══███╔╝
   ██║  ██║███████║██████╔╝███████╗  ███╔╝
   ██║  ██║██╔══██║██╔═══╝ ╚════██║ ███╔╝
   ██████╔╝██║  ██║██║     ███████║███████╗
   ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚══════╝╚══════╝
```

**DDoS Protection System untuk Pterodactyl Panel & Game Servers**

Sistem proteksi khusus untuk Pterodactyl Panel, Wings Daemon, dan Game Servers dengan optimasi untuk traffic gaming yang tinggi.

---

## 🎮 Apa itu Pterodactyl?

Pterodactyl adalah game server management panel open-source yang memungkinkan Anda untuk hosting game servers seperti:
- Minecraft (Java & Bedrock)
- Counter-Strike (CS:GO, CS2)
- Rust, ARK, Valheim
- FiveM (GTA V RP)
- Dan 100+ game lainnya

**Komponen Pterodactyl:**
- **Panel** - Web interface untuk management (Port 80/443)
- **Wings** - Daemon yang menjalankan game servers (Port 8080, 2022)
- **Game Servers** - Server game dengan berbagai port

---

## 🛡️ Fitur Protection

### **1. Panel Protection**
- **HTTP/HTTPS DDoS Protection**
  - Rate limiting: Max 20 requests/second per IP
  - Connection limit: 30 concurrent per IP
  - SYN flood protection
  
- **CloudFlare Mode** (Optional)
  - Hanya accept traffic dari CloudFlare IPs
  - Bypass CloudFlare = Blocked
  - Perfect untuk Panel dengan CDN

### **2. Wings Daemon Protection**
- **API Protection (Port 8080)**
  - Rate limit: 15 req/s per IP
  - Max 20 concurrent connections per IP
  - Token validation protection
  
- **SFTP Protection (Port 2022)**
  - Max 5 login attempts/minute
  - Max 10 concurrent per IP
  - Brute force prevention

### **3. Game Server Protection**
- **Protected Game Ports:**
  ```
  25565  - Minecraft Java
  19132  - Minecraft Bedrock (UDP)
  27015  - CS:GO, TF2, Garry's Mod
  7777   - ARK Survival, Rust
  28015  - Rust (RCON)
  30120  - FiveM (GTA V)
  22005  - Garry's Mod
  2456-2458 - Valheim
  9876   - Terraria
  10999  - Arma 3
  ```

- **Dynamic Port Range:** 25000-30000
  - TCP: Max 150 concurrent/IP
  - UDP: Max 300 concurrent/IP
  - Optimized for gaming traffic

### **4. Kernel Optimization**
- **BBR Congestion Control** - Better for gaming latency
- **Large Network Buffers** - Handle burst traffic
- **High Connection Tracking** - 5M concurrent connections
- **UDP Optimization** - Critical for game servers

### **5. Fail2Ban Integration**
- Panel brute force protection
- SFTP attack prevention
- Automatic IP banning
- Email alerts (optional)

---

## 📋 Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| OS | Ubuntu 18.04+ | Ubuntu 22.04/24.04 |
| RAM | 2GB | 4GB+ |
| CPU | 2 Cores | 4+ Cores |
| Pterodactyl | v1.0+ | Latest |
| Wings | v1.0+ | Latest |

---

## 🚀 Installation

### Method 1: Quick Install (Recommended)

```bash
wget https://raw.githubusercontent.com/DapszSigma/Pterodactyl-Protection/main/protection.sh
chmod +x protection.sh
sudo ./protection.sh
```

**Installation wizard will ask:**
- Whitelist IPs (your office/home IP)
- CloudFlare mode (y/n)
- Confirmation to proceed

**Installation time:** 2-3 minutes

### Method 2: Manual Menu

```bash
wget https://raw.githubusercontent.com/DapszSigma/Pterodactyl-Protection/main/protection.sh
chmod +x protection.sh
sudo ./protection.sh
```

Select option 1 for full installation.

---

## 🔧 Post-Installation Setup

### 1. Verify Installation

```bash
ptero-status
```

Expected output:
```
╔════════════════════════════════════════╗
║  Pterodactyl Protection Status         ║
╚════════════════════════════════════════╝

Server IP: 203.0.113.50
Active Connections: 47
Blocked IPs: 3

Panel: ✓ Running
Wings: ✓ Running

Fail2Ban Status: Active
```

### 2. Test Panel Access

Open browser: `http://YOUR_SERVER_IP`

If you can't access:
```bash
sudo ptero-whitelist YOUR_HOME_IP
```

### 3. Verify Game Server Ports

Test from game client or use:
```bash
sudo netstat -tlnp | grep -E "25565|27015|19132"
```

### 4. Check Firewall Rules

```bash
sudo iptables -L -n -v | head -50
```

Should show:
- DAPSZ-WHITELIST chain
- PANEL-PROTECTION chain
- WINGS-PROTECTION chain
- GAME-PROTECTION chain

---

## 🎮 Game Server Specific Configuration

### Minecraft Server

**Ports needed:**
- Java Edition: 25565 (TCP)
- Bedrock Edition: 19132 (UDP)

**Already protected by default!**

Optional: Increase connection limit for popular servers:
```bash
sudo iptables -R GAME-PROTECTION -p tcp --dport 25565 -m connlimit --connlimit-above 200 -j DROP
```

### CS:GO / CS2 Server

**Ports needed:**
- Game: 27015 (TCP/UDP)
- RCON: 27016 (TCP)
- SourceTV: 27020 (UDP)

**Already protected!**

Add SourceTV port:
```bash
sudo iptables -A GAME-PROTECTION -p udp --dport 27020 -j ACCEPT
sudo netfilter-persistent save
```

### Rust Server

**Ports needed:**
- Game: 28015 (TCP/UDP)
- RCON: 28016 (TCP)
- App Port: 28082 (TCP)

Protected by default. Add RCON:
```bash
sudo iptables -A GAME-PROTECTION -p tcp --dport 28016 -m connlimit --connlimit-above 10 -j DROP
sudo iptables -A GAME-PROTECTION -p tcp --dport 28016 -j ACCEPT
sudo netfilter-persistent save
```

### FiveM Server (GTA V)

**Ports needed:**
- Game: 30120 (TCP/UDP)
- TxAdmin: 40120 (TCP)

Game port protected. Add TxAdmin:
```bash
sudo iptables -A PANEL-PROTECTION -p tcp --dport 40120 -m connlimit --connlimit-above 10 -j REJECT
sudo iptables -A PANEL-PROTECTION -p tcp --dport 40120 -j ACCEPT
sudo netfilter-persistent save
```

### ARK Survival Evolved

**Ports needed:**
- Game: 7777 (UDP)
- Query: 27015 (UDP)
- RCON: 27020 (TCP)

Protected by default!

---

## 🌐 CloudFlare Integration

### When to Use CloudFlare Mode?

**Use CloudFlare Mode if:**
- ✅ Your Panel uses custom domain (panel.yourdomain.com)
- ✅ Domain is proxied through CloudFlare (Orange cloud)
- ✅ You want maximum DDoS protection
- ✅ You don't need direct IP access to Panel

**Don't use CloudFlare Mode if:**
- ❌ You access Panel via IP directly
- ❌ You use Let's Encrypt with HTTP challenge
- ❌ You have API integrations hitting direct IP

### Enable CloudFlare Mode

During installation, select **yes** when asked about CloudFlare mode.

Or manually:
```bash
sudo ./protection.sh
# Select option: 5) Enable CloudFlare Mode
```

### CloudFlare Settings

1. **DNS Settings:**
   - A record: `panel` → `YOUR_SERVER_IP` (Orange cloud ☁️)
   
2. **SSL/TLS Settings:**
   - Mode: Full (Strict) recommended
   
3. **Firewall Rules (Optional):**
   ```
   (http.request.uri.path contains "/admin") and (ip.geoip.country ne "YOUR_COUNTRY")
   Action: Block
   ```

4. **Rate Limiting:**
   - Already handled by iptables
   - CloudFlare provides additional layer

### Verify CloudFlare Mode

```bash
curl -I http://YOUR_SERVER_IP
# Should be blocked or timeout

curl -I https://panel.yourdomain.com
# Should work (200 OK)
```

---

## 📊 Monitoring & Management

### Quick Commands

```bash
# View protection status
ptero-status

# Whitelist an IP (allow all traffic)
sudo ptero-whitelist 192.168.1.100

# Unblock temporarily banned IP
sudo ptero-unblock 203.0.113.50
```

### Real-time Monitoring

**Active Connections:**
```bash
watch -n 1 'netstat -an | grep ESTABLISHED | wc -l'
```

**Top Connected IPs:**
```bash
watch -n 2 "netstat -ntu | awk '{print \$5}' | cut -d: -f1 | sort | uniq -c | sort -rn | head -15"
```

**Blocked IPs:**
```bash
watch -n 5 'iptables -L INPUT -n -v | grep DROP | wc -l'
```

**Game Server Connections:**
```bash
# Minecraft
netstat -an | grep :25565 | grep ESTABLISHED | wc -l

# CS:GO
netstat -an | grep :27015 | grep ESTABLISHED | wc -l
```

### Log Files

```bash
# Protection logs
tail -f /var/log/dapsz-pterodactyl.log

# Installation logs
tail -f /var/log/dapsz-pterodactyl-install.log

# Fail2Ban
tail -f /var/log/fail2ban.log

# Nginx (Panel access)
tail -f /var/log/nginx/access.log

# Wings
tail -f /var/log/pterodactyl/wings.log
```

### Fail2Ban Management

```bash
# View all jails
sudo fail2ban-client status

# View specific jail
sudo fail2ban-client status pterodactyl-panel

# Unban IP
sudo fail2ban-client set pterodactyl-panel unbanip 203.0.113.50

# Ban IP manually
sudo fail2ban-client set pterodactyl-panel banip 203.0.113.50
```

---

## ⚙️ Advanced Configuration

### Custom Port Protection

If your game uses custom port:

```bash
# TCP protection
sudo iptables -A GAME-PROTECTION -p tcp --dport YOUR_PORT -m state --state NEW -m recent --set --name CUSTOM
sudo iptables -A GAME-PROTECTION -p tcp --dport YOUR_PORT -m state --state NEW -m recent --update --seconds 1 --hitcount 50 --name CUSTOM -j DROP
sudo iptables -A GAME-PROTECTION -p tcp --dport YOUR_PORT -m connlimit --connlimit-above 100 -j DROP
sudo iptables -A GAME-PROTECTION -p tcp --dport YOUR_PORT -j ACCEPT

# UDP protection
sudo iptables -A GAME-PROTECTION -p udp --dport YOUR_PORT -m connlimit --connlimit-above 200 -j DROP
sudo iptables -A GAME-PROTECTION -p udp --dport YOUR_PORT -j ACCEPT

# Save
sudo netfilter-persistent save
```

### Adjust Rate Limits

**For high-traffic servers:**

```bash
# Edit kernel config
sudo nano /etc/sysctl.d/99-dapsz-pterodactyl.conf
```

Increase values:
```
net.netfilter.nf_conntrack_max = 10000000
net.core.netdev_max_backlog = 100000
```

Apply:
```bash
sudo sysctl -p /etc/sysctl.d/99-dapsz-pterodactyl.conf
```

**Increase connection limits:**
```bash
# Minecraft - Popular server
sudo iptables -R GAME-PROTECTION 1 -p tcp --dport 25565 -m connlimit --connlimit-above 300 -j DROP

# Panel - Heavy traffic
sudo iptables -R PANEL-PROTECTION 1 -p tcp --dport 80 -m connlimit --connlimit-above 100 -j REJECT
```

### Whitelist IP Ranges

For corporate networks:

```bash
# Whitelist subnet
sudo iptables -I DAPSZ-WHITELIST -s 192.168.1.0/24 -j ACCEPT

# Whitelist multiple IPs
sudo iptables -I DAPSZ-WHITELIST -s 10.0.0.1 -j ACCEPT
sudo iptables -I DAPSZ-WHITELIST -s 10.0.0.2 -j ACCEPT

# Save
sudo netfilter-persistent save
```

### Panel-Only Server

If server is ONLY for Panel (no game servers):

```bash
# Remove game protection
sudo iptables -D INPUT -j GAME-PROTECTION
sudo iptables -X GAME-PROTECTION

# Save
sudo netfilter-persistent save
```

### Wings-Only Server (Node)

If server is ONLY Wings node (no Panel):

```bash
# Remove panel protection
sudo iptables -D INPUT -j PANEL-PROTECTION
sudo iptables -X PANEL-PROTECTION

# Keep Wings + Game protection
# Already configured!
```

---

## 🐛 Troubleshooting

### Problem 1: Can't Access Panel

**Symptoms:** Browser shows "Connection refused" or timeout

**Solutions:**

```bash
# Check if Panel is running
sudo systemctl status pteroq nginx

# Check if port 80/443 blocked
sudo iptables -L INPUT -n -v | grep -E "80|443"

# Whitelist your IP
sudo ptero-whitelist YOUR_IP

# Temporarily allow all (EMERGENCY)
sudo iptables -I INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 443 -j ACCEPT
```

### Problem 2: Game Server Won't Start

**Symptoms:** Players can't connect to game server

**Solutions:**

```bash
# Check if Wings is running
sudo systemctl status wings

# Check game server port in Wings
sudo netstat -tlnp | grep YOUR_PORT

# Verify firewall allows port
sudo iptables -L GAME-PROTECTION -n -v | grep YOUR_PORT

# If port not in list, add it
sudo iptables -A GAME-PROTECTION -p tcp --dport YOUR_PORT -j ACCEPT
sudo iptables -A GAME-PROTECTION -p udp --dport YOUR_PORT -j ACCEPT
sudo netfilter-persistent save
```

### Problem 3: Wings Can't Connect to Panel

**Symptoms:** Wings shows "Failed to connect to panel"

**Solutions:**

```bash
# Check Wings API port
sudo iptables -L WINGS-PROTECTION -n -v | grep 8080

# If Panel and Wings on different servers
# Whitelist Panel's IP on Wings server
sudo ptero-whitelist PANEL_SERVER_IP

# Check Wings config
sudo nano /etc/pterodactyl/config.yml
# Verify api.host and token
```

### Problem 4: High Latency on Game Servers

**Symptoms:** Players experience lag despite good bandwidth

**Solutions:**

```bash
# Check if rate limits too strict
sudo iptables -L GAME-PROTECTION -n -v

# Increase UDP limits (gaming uses UDP)
sudo iptables -R GAME-PROTECTION -p udp --dport YOUR_PORT -m connlimit --connlimit-above 500 -j DROP

# Check kernel settings
sysctl net.ipv4.tcp_congestion_control
# Should show: bbr

# Restart Wings
sudo systemctl restart wings
```

### Problem 5: CloudFlare Mode Blocking Panel

**Symptoms:** Can't access Panel even with correct domain

**Solutions:**

```bash
# Verify CloudFlare IPs loaded
sudo ipset list cloudflare

# Check if your IP going through CloudFlare
curl -I https://panel.yourdomain.com
# Check for: CF-Ray header

# Temporarily disable CloudFlare mode
sudo iptables -F CLOUDFLARE-ONLY
sudo iptables -X CLOUDFLARE-ONLY

# Access Panel directly
http://YOUR_SERVER_IP
```

### Problem 6: Locked Out (Can't SSH)

**Symptoms:** SSH connection refused after installation

**Solutions:**

1. **Via VPS Console** (DigitalOcean, Vultr, etc):
   ```bash
   sudo iptables -F
   sudo iptables -P INPUT ACCEPT
   
   # Re-run setup with your IP whitelisted
   ```

2. **If SSH still works:**
   ```bash
   # Add your IP to whitelist
   sudo ptero-whitelist YOUR_IP
   ```

### Problem 7: Fail2Ban Banning Legitimate Users

**Symptoms:** Users getting banned incorrectly

**Solutions:**

```bash
# Unban IP
sudo fail2ban-client set pterodactyl-panel unbanip IP_ADDRESS

# Whitelist IP permanently
sudo nano /etc/fail2ban/jail.d/pterodactyl.conf

# Add under [DEFAULT]:
ignoreip = 127.0.0.1/8 YOUR_IP

# Restart Fail2Ban
sudo systemctl restart fail2ban
```

---

## 📈 Performance Optimization

### For High-Traffic Servers (100+ concurrent players)

```bash
# Edit kernel config
sudo nano /etc/sysctl.d/99-dapsz-pterodactyl.conf
```

Add/modify:
```
# Massive connection tracking
net.netfilter.nf_conntrack_max = 10000000

# Huge buffers
net.core.rmem_max = 536870912
net.core.wmem_max = 536870912
net.ipv4.tcp_rmem = 16384 1048576 536870912
net.ipv4.tcp_wmem = 16384 1048576 536870912

# More backlog
net.core.netdev_max_backlog = 100000

# UDP optimization (critical!)
net.ipv4.udp_mem = 1572864 2097152 52428800
```

Apply:
```bash
sudo sysctl -p /etc/sysctl.d/99-dapsz-pterodactyl.conf
```

### For Multiple Game Servers

Disable individual port protection, use range only:

```bash
# Remove individual game ports
sudo iptables -F GAME-PROTECTION

# Keep only dynamic range
sudo iptables -A GAME-PROTECTION -p tcp --dport 25000:30000 -m connlimit --connlimit-above 200 -j DROP
sudo iptables -A GAME-PROTECTION -p tcp --dport 25000:30000 -j ACCEPT
sudo iptables -A GAME-PROTECTION -p udp --dport 25000:30000 -m connlimit --connlimit-above 400 -j DROP
sudo iptables -A GAME-PROTECTION -p udp --dport 25000:30000 -j ACCEPT

sudo netfilter-persistent save
```

---

## 🔄 Maintenance

### Backup Configuration

```bash
# Manual backup
sudo tar -czf /root/pterodactyl-protection-backup-$(date +%Y%m%d).tar.gz \
  /etc/Pterodactyl-Protection/ \
  /etc/fail2ban/jail.d/pterodactyl.conf \
  /etc/sysctl.d/99-dapsz-pterodactyl.conf

# Backup firewall
sudo iptables-save > /root/iptables-backup-$(date +%Y%m%d).rules
```

### Update Protection

```bash
# Re-run installer
wget https://raw.githubusercontent.com/DapszSigma/Pterodactyl-Protection/main/protection.sh
chmod +x protection.sh
sudo ./protection.sh
```

### Restore from Backup

```bash
# Restore files
sudo tar -xzf /root/pterodactyl-protection-backup-YYYYMMDD.tar.gz -C /

# Restore firewall
sudo iptables-restore < /root/iptables-backup-YYYYMMDD.rules
sudo netfilter-persistent save

# Restart services
sudo systemctl restart fail2ban wings pteroq
```

---

## 🆘 Emergency Recovery

### penghapusan lengkap

```bash
# Stop services
sudo systemctl stop fail2ban

# Flush firewall
sudo iptables -F
sudo iptables -X
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT
sudo netfilter-persistent save

# Remove files
sudo rm -rf /etc/dapsz-protection
sudo rm /etc/fail2ban/jail.d/pterodactyl.conf
sudo rm /etc/sysctl.d/99-dapsz-pterodactyl.conf
sudo rm /usr/local/bin/ptero-*

# Restore defaults
sudo sysctl -p
```

---

## 📞 Support

### Getting Help

- GitHub Issues: https://github.com/DapszSigma/Pterodactyl-Protection/issues
- Documentation: `/root/pterodactyl-protection-info.txt`

### Reporting Issues

Include:
- OS version: `cat /etc/os-release`
- Pterodactyl version
- Error logs: `/var/log/dapsz-pterodactyl.log`
- Firewall rules: `iptables -L -n -v`

---

## 📄 License

MIT License - Free for personal and commercial use

---

## 🙏 Credits

- Pterodactyl Panel: https://pterodactyl.io
- Dapsz Protection Team
- Community contributors

---

**Version:** 3.0 - Pterodactyl Edition  
**Last Updated:** 2025-02-10  
**Tested with:** Pterodactyl v1.11+, Wings v1.11+

---

**🎮 Happy Hosting! Lindungi server Anda!**
