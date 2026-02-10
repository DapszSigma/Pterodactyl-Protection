#!/bin/bash

#############################################
# DAPSZ Protection v3.0 - Pterodactyl Edition
# DDoS Protection for Pterodactyl Panel & Wings
#############################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Must run as root (use sudo)${NC}" 
   exit 1
fi

clear
echo -e "${PURPLE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   ██████╗  █████╗ ██████╗ ███████╗███████╗                   ║
║   ██╔══██╗██╔══██╗██╔══██╗██╔════╝╚══███╔╝                   ║
║   ██║  ██║███████║██████╔╝███████╗  ███╔╝                    ║
║   ██║  ██║██╔══██║██╔═══╝ ╚════██║ ███╔╝                     ║
║   ██████╔╝██║  ██║██║     ███████║███████╗                   ║
║   ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚══════╝╚══════╝                   ║
║                                                               ║
║          DDoS Protection - Pterodactyl Edition                ║
║          Panel, Wings & Game Server Protection                ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

LOG_FILE="/var/log/dapsz-pterodactyl.log"
CONFIG_DIR="/etc/dapsz-protection"

log_event() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

show_menu() {
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     DAPSZ Protection - Pterodactyl Menu                ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}1)${NC}  Full Protection Installation"
    echo -e "${CYAN}2)${NC}  Protect Pterodactyl Panel (HTTP/HTTPS)"
    echo -e "${CYAN}3)${NC}  Protect Wings Daemon (8080)"
    echo -e "${CYAN}4)${NC}  Protect Game Server Ports (25565, 27015, etc.)"
    echo -e "${CYAN}5)${NC}  Enable CloudFlare Mode"
    echo -e "${CYAN}6)${NC}  Configure Rate Limiting"
    echo -e "${CYAN}7)${NC}  Setup Connection Limits"
    echo -e "${CYAN}8)${NC}  View Protection Status"
    echo -e "${CYAN}9)${NC}  Whitelist IP Address"
    echo -e "${CYAN}10)${NC} Emergency: Allow All Traffic"
    echo -e "${CYAN}11)${NC} Exit"
    echo ""
    echo -n "Enter choice [1-11]: "
}

detect_pterodactyl() {
    echo -e "${YELLOW}Detecting Pterodactyl installation...${NC}"
    
    PANEL_DETECTED=false
    WINGS_DETECTED=false
    
    # Check for Panel
    if [ -d "/var/www/pterodactyl" ] || systemctl is-active --quiet pteroq; then
        PANEL_DETECTED=true
        echo -e "${GREEN}✓ Pterodactyl Panel detected${NC}"
    fi
    
    # Check for Wings
    if systemctl is-active --quiet wings || [ -f "/usr/local/bin/wings" ]; then
        WINGS_DETECTED=true
        echo -e "${GREEN}✓ Wings daemon detected${NC}"
    fi
    
    if [ "$PANEL_DETECTED" = false ] && [ "$WINGS_DETECTED" = false ]; then
        echo -e "${YELLOW}⚠ Pterodactyl not detected. Continue anyway? (y/n)${NC}"
        read -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

install_dependencies() {
    echo -e "${YELLOW}Installing protection dependencies...${NC}"
    
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        iptables \
        iptables-persistent \
        netfilter-persistent \
        fail2ban \
        conntrack \
        ipset \
        nginx \
        apache2-utils > /dev/null 2>&1
    
    log_event "Dependencies installed"
    echo -e "${GREEN}✓ Dependencies installed${NC}"
}

configure_kernel() {
    echo -e "${YELLOW}Optimizing kernel for gaming & web traffic...${NC}"
    
    mkdir -p "$CONFIG_DIR"
    
    cat > /etc/sysctl.d/99-dapsz-pterodactyl.conf << 'EOF'
# DAPSZ Protection - Pterodactyl Optimization

# Network Security
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# SYN Flood Protection
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_max_syn_backlog = 16384

# Connection Tracking (High for game servers)
net.netfilter.nf_conntrack_max = 5000000
net.netfilter.nf_conntrack_tcp_timeout_established = 7200
net.netfilter.nf_conntrack_udp_timeout = 180
net.netfilter.nf_conntrack_generic_timeout = 120

# TCP/IP Stack
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_rfc1337 = 1

# Buffer Sizes (Important for game servers)
net.core.rmem_default = 262144
net.core.rmem_max = 268435456
net.core.wmem_default = 262144
net.core.wmem_max = 268435456
net.core.netdev_max_backlog = 50000
net.ipv4.tcp_rmem = 16384 524288 268435456
net.ipv4.tcp_wmem = 16384 524288 268435456
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384

# Congestion Control
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# UDP Optimization (Critical for game servers)
net.ipv4.udp_mem = 786432 1048576 26777216
EOF

    sysctl -p /etc/sysctl.d/99-dapsz-pterodactyl.conf > /dev/null 2>&1
    
    log_event "Kernel optimized for Pterodactyl"
    echo -e "${GREEN}✓ Kernel optimized${NC}"
}

protect_panel() {
    echo -e "${YELLOW}Configuring Panel protection (HTTP/HTTPS)...${NC}"
    
    # Panel usually runs on port 80/443 with Nginx
    
    # Protect against HTTP floods
    iptables -N PANEL-PROTECTION 2>/dev/null || iptables -F PANEL-PROTECTION
    
    # Rate limit new connections (Panel)
    iptables -A PANEL-PROTECTION -p tcp --dport 80 -m state --state NEW -m recent --set --name PANEL_HTTP
    iptables -A PANEL-PROTECTION -p tcp --dport 80 -m state --state NEW -m recent --update --seconds 1 --hitcount 20 --rttl --name PANEL_HTTP -j DROP
    
    iptables -A PANEL-PROTECTION -p tcp --dport 443 -m state --state NEW -m recent --set --name PANEL_HTTPS
    iptables -A PANEL-PROTECTION -p tcp --dport 443 -m state --state NEW -m recent --update --seconds 1 --hitcount 20 --rttl --name PANEL_HTTPS -j DROP
    
    # Connection limit per IP (Panel)
    iptables -A PANEL-PROTECTION -p tcp --dport 80 -m connlimit --connlimit-above 30 --connlimit-mask 32 -j REJECT --reject-with tcp-reset
    iptables -A PANEL-PROTECTION -p tcp --dport 443 -m connlimit --connlimit-above 30 --connlimit-mask 32 -j REJECT --reject-with tcp-reset
    
    # Allow HTTP/HTTPS
    iptables -A PANEL-PROTECTION -p tcp --dport 80 -j ACCEPT
    iptables -A PANEL-PROTECTION -p tcp --dport 443 -j ACCEPT
    
    # Apply chain to INPUT
    if ! iptables -C INPUT -j PANEL-PROTECTION 2>/dev/null; then
        iptables -I INPUT -j PANEL-PROTECTION
    fi
    
    log_event "Panel protection configured"
    echo -e "${GREEN}✓ Panel protected (ports 80, 443)${NC}"
}

protect_wings() {
    echo -e "${YELLOW}Configuring Wings daemon protection (port 8080)...${NC}"
    
    # Wings SFTP runs on 2022, API on 8080
    
    iptables -N WINGS-PROTECTION 2>/dev/null || iptables -F WINGS-PROTECTION
    
    # Protect Wings API (8080)
    iptables -A WINGS-PROTECTION -p tcp --dport 8080 -m state --state NEW -m recent --set --name WINGS_API
    iptables -A WINGS-PROTECTION -p tcp --dport 8080 -m state --state NEW -m recent --update --seconds 1 --hitcount 15 --rttl --name WINGS_API -j DROP
    iptables -A WINGS-PROTECTION -p tcp --dport 8080 -m connlimit --connlimit-above 20 --connlimit-mask 32 -j REJECT
    iptables -A WINGS-PROTECTION -p tcp --dport 8080 -j ACCEPT
    
    # Protect Wings SFTP (2022)
    iptables -A WINGS-PROTECTION -p tcp --dport 2022 -m state --state NEW -m recent --set --name WINGS_SFTP
    iptables -A WINGS-PROTECTION -p tcp --dport 2022 -m state --state NEW -m recent --update --seconds 60 --hitcount 5 --rttl --name WINGS_SFTP -j DROP
    iptables -A WINGS-PROTECTION -p tcp --dport 2022 -m connlimit --connlimit-above 10 --connlimit-mask 32 -j REJECT
    iptables -A WINGS-PROTECTION -p tcp --dport 2022 -j ACCEPT
    
    # Apply chain
    if ! iptables -C INPUT -j WINGS-PROTECTION 2>/dev/null; then
        iptables -I INPUT -j WINGS-PROTECTION
    fi
    
    log_event "Wings protection configured"
    echo -e "${GREEN}✓ Wings protected (ports 8080, 2022)${NC}"
}

protect_game_ports() {
    echo -e "${YELLOW}Configuring game server port protection...${NC}"
    
    iptables -N GAME-PROTECTION 2>/dev/null || iptables -F GAME-PROTECTION
    
    # Common game server ports
    GAME_PORTS=(
        "25565"  # Minecraft Java
        "19132"  # Minecraft Bedrock
        "27015"  # Source Games (CS:GO, TF2, etc)
        "7777"   # ARK, Rust
        "27016"  # Source RCON
        "28015"  # Rust
        "30120"  # FiveM
        "22005"  # Garry's Mod
        "2456"   # Valheim
        "2457"   # Valheim
        "2458"   # Valheim
        "9876"   # Terraria
        "10999"  # Arma 3
        "16567"  # Battlefield - Tambahin Aja Kalau ada yang kurang
    )
    
    echo -e "${CYAN}Protecting game server ports:${NC}"
    
    for port in "${GAME_PORTS[@]}"; do
        # TCP Protection
        iptables -A GAME-PROTECTION -p tcp --dport "$port" -m state --state NEW -m recent --set --name "GAME_TCP_$port"
        iptables -A GAME-PROTECTION -p tcp --dport "$port" -m state --state NEW -m recent --update --seconds 1 --hitcount 50 --rttl --name "GAME_TCP_$port" -j DROP
        iptables -A GAME-PROTECTION -p tcp --dport "$port" -m connlimit --connlimit-above 100 --connlimit-mask 32 -j DROP
        iptables -A GAME-PROTECTION -p tcp --dport "$port" -j ACCEPT
        
        # UDP Protection (Most game servers use UDP)
        iptables -A GAME-PROTECTION -p udp --dport "$port" -m state --state NEW -m recent --set --name "GAME_UDP_$port"
        iptables -A GAME-PROTECTION -p udp --dport "$port" -m state --state NEW -m recent --update --seconds 1 --hitcount 100 --rttl --name "GAME_UDP_$port" -j DROP
        iptables -A GAME-PROTECTION -p udp --dport "$port" -m connlimit --connlimit-above 200 --connlimit-mask 32 -j DROP
        iptables -A GAME-PROTECTION -p udp --dport "$port" -j ACCEPT
        
        echo -e "  ${GREEN}✓${NC} Port $port (TCP/UDP)"
    done
    
    # Dynamic port range for Pterodactyl (usually 25000-30000)
    echo -e "${CYAN}Protecting dynamic port range (25000-30000)...${NC}"
    
    # Less strict for dynamic range
    iptables -A GAME-PROTECTION -p tcp --dport 25000:30000 -m connlimit --connlimit-above 150 --connlimit-mask 32 -j DROP
    iptables -A GAME-PROTECTION -p tcp --dport 25000:30000 -j ACCEPT
    iptables -A GAME-PROTECTION -p udp --dport 25000:30000 -m connlimit --connlimit-above 300 --connlimit-mask 32 -j DROP
    iptables -A GAME-PROTECTION -p udp --dport 25000:30000 -j ACCEPT
    
    # Apply chain
    if ! iptables -C INPUT -j GAME-PROTECTION 2>/dev/null; then
        iptables -I INPUT -j GAME-PROTECTION
    fi
    
    log_event "Game server ports protected"
    echo -e "${GREEN}✓ Game servers protected${NC}"
}

enable_cloudflare_mode() {
    echo -e "${YELLOW}Configuring CloudFlare mode...${NC}"
    echo -e "${CYAN}This will only allow connections from CloudFlare IPs to Panel${NC}"
    
    # CloudFlare IP ranges
    CF_IPS=(
        "173.245.48.0/20"
        "103.21.244.0/22"
        "103.22.200.0/22"
        "103.31.4.0/22"
        "141.101.64.0/18"
        "108.162.192.0/18"
        "190.93.240.0/20"
        "188.114.96.0/20"
        "197.234.240.0/22"
        "198.41.128.0/17"
        "162.158.0.0/15"
        "104.16.0.0/13"
        "104.24.0.0/14"
        "172.64.0.0/13"
        "131.0.72.0/22"
    )
    
    # Create ipset for CloudFlare IPs
    ipset create cloudflare-ips hash:net -exist
    
    for ip in "${CF_IPS[@]}"; do
        ipset add cloudflare-ips "$ip" -exist
    done
    
    # Create CloudFlare chain
    iptables -N CLOUDFLARE-ONLY 2>/dev/null || iptables -F CLOUDFLARE-ONLY
    
    # Allow from CloudFlare IPs
    iptables -A CLOUDFLARE-ONLY -p tcp --dport 80 -m set --match-set cloudflare-ips src -j ACCEPT
    iptables -A CLOUDFLARE-ONLY -p tcp --dport 443 -m set --match-set cloudflare-ips src -j ACCEPT
    
    # Drop others to Panel
    iptables -A CLOUDFLARE-ONLY -p tcp --dport 80 -j DROP
    iptables -A CLOUDFLARE-ONLY -p tcp --dport 443 -j DROP
    
    echo -e "${GREEN}✓ CloudFlare mode enabled${NC}"
    echo -e "${YELLOW}⚠ Make sure your Panel is behind CloudFlare!${NC}"
    
    log_event "CloudFlare mode enabled"
}

configure_fail2ban() {
    echo -e "${YELLOW}Configuring Fail2Ban for Pterodactyl...${NC}"
    
    cat > /etc/fail2ban/jail.d/pterodactyl.conf << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[pterodactyl-panel]
enabled = true
port = http,https
filter = pterodactyl-panel
logpath = /var/log/nginx/access.log
maxretry = 10
findtime = 300

[pterodactyl-wings]
enabled = true
port = 8080
filter = pterodactyl-wings
logpath = /var/log/pterodactyl/wings.log
maxretry = 15
findtime = 600

[pterodactyl-sftp]
enabled = true
port = 2022
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 7200
EOF

    cat > /etc/fail2ban/filter.d/pterodactyl-panel.conf << 'EOF'
[Definition]
failregex = ^<HOST> -.*"(GET|POST|HEAD).*(admin/|api/).*HTTP.*" (4[0-9]{2}|5[0-9]{2})
ignoreregex =
EOF

    cat > /etc/fail2ban/filter.d/pterodactyl-wings.conf << 'EOF'
[Definition]
failregex = .*authentication failed.*<HOST>
            .*invalid token.*<HOST>
ignoreregex =
EOF

    systemctl enable fail2ban > /dev/null 2>&1
    systemctl restart fail2ban
    
    log_event "Fail2Ban configured"
    echo -e "${GREEN}✓ Fail2Ban configured${NC}"
}

create_base_firewall() {
    echo -e "${YELLOW}Creating base firewall rules...${NC}"
    
    # Flush existing
    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t mangle -F
    
    # Default policies
    iptables -P INPUT DROP
    iptables -P FORWARD ACCEPT  # Important for Docker/Wings
    iptables -P OUTPUT ACCEPT
    
    # Create main chains
    iptables -N DAPSZ-WHITELIST 2>/dev/null
    iptables -N DAPSZ-ATTACK 2>/dev/null
    
    # Whitelist chain (first)
    iptables -I INPUT 1 -j DAPSZ-WHITELIST
    
    # Loopback
    iptables -A INPUT -i lo -j ACCEPT
    
    # Established connections
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    
    # Drop invalid
    iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
    
    # Attack patterns
    iptables -A DAPSZ-ATTACK -p tcp --tcp-flags ALL NONE -j DROP
    iptables -A DAPSZ-ATTACK -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
    iptables -A DAPSZ-ATTACK -p tcp --tcp-flags ALL ALL -j DROP
    iptables -A DAPSZ-ATTACK -p tcp --tcp-flags FIN,RST FIN,RST -j DROP
    iptables -A INPUT -j DAPSZ-ATTACK
    
    # SYN flood protection
    iptables -N syn_flood 2>/dev/null
    iptables -A INPUT -p tcp --syn -j syn_flood
    iptables -A syn_flood -m limit --limit 2/s --limit-burst 6 -j RETURN
    iptables -A syn_flood -j DROP
    
    # ICMP limit
    iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s -j ACCEPT
    iptables -A INPUT -p icmp --icmp-type echo-request -j DROP
    
    # SSH protection
    iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --set --name SSH
    iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 --name SSH -j DROP
    iptables -A INPUT -p tcp --dport 22 -m connlimit --connlimit-above 5 -j REJECT
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    
    # DNS
    iptables -A INPUT -p udp --dport 53 -j ACCEPT
    iptables -A INPUT -p tcp --dport 53 -j ACCEPT
    
    # MySQL (for Panel database)
    iptables -A INPUT -p tcp --dport 3306 -s 127.0.0.1 -j ACCEPT
    iptables -A INPUT -p tcp --dport 3306 -j DROP
    
    # Redis (for Panel cache)
    iptables -A INPUT -p tcp --dport 6379 -s 127.0.0.1 -j ACCEPT
    iptables -A INPUT -p tcp --dport 6379 -j DROP
    
    log_event "Base firewall created"
    echo -e "${GREEN}✓ Base firewall configured${NC}"
}

full_protection() {
    echo -e "${GREEN}Installing full Pterodactyl protection...${NC}"
    echo ""
    
    detect_pterodactyl
    install_dependencies
    configure_kernel
    create_base_firewall
    protect_panel
    protect_wings
    protect_game_ports
    configure_fail2ban
    
    # Save rules
    netfilter-persistent save > /dev/null 2>&1
    
    create_helper_scripts
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     Pterodactyl Protection Installed Successfully!     ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Protected Services:${NC}"
    echo -e "  ✓ Panel (HTTP/HTTPS: 80, 443)"
    echo -e "  ✓ Wings (API: 8080, SFTP: 2022)"
    echo -e "  ✓ Game Servers (25565, 27015, 19132, etc.)"
    echo -e "  ✓ Dynamic Ports (25000-30000)"
    echo ""
    echo -e "${CYAN}Quick Commands:${NC}"
    echo -e "  ptero-status      - View protection status"
    echo -e "  ptero-whitelist   - Whitelist an IP"
    echo -e "  ptero-unblock     - Unblock an IP"
    echo ""
    
    log_event "Full protection installed successfully"
}

view_status() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     Pterodactyl Protection Status                      ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${YELLOW}System Information:${NC}"
    echo "Hostname: $(hostname)"
    echo "Server IP: $(hostname -I | awk '{print $1}')"
    echo "Load: $(uptime | awk -F'load average:' '{print $2}')"
    echo ""
    
    echo -e "${YELLOW}Services Status:${NC}"
    if systemctl is-active --quiet pteroq; then
        echo -e "  ${GREEN}✓${NC} Panel (pteroq): Running"
    else
        echo -e "  ${RED}✗${NC} Panel (pteroq): Not Running"
    fi
    
    if systemctl is-active --quiet wings; then
        echo -e "  ${GREEN}✓${NC} Wings: Running"
    else
        echo -e "  ${YELLOW}⚠${NC} Wings: Not Running"
    fi
    
    if systemctl is-active --quiet fail2ban; then
        echo -e "  ${GREEN}✓${NC} Fail2Ban: Active"
    else
        echo -e "  ${RED}✗${NC} Fail2Ban: Inactive"
    fi
    echo ""
    
    echo -e "${YELLOW}Network Statistics:${NC}"
    echo "Active Connections: $(netstat -an 2>/dev/null | grep ESTABLISHED | wc -l)"
    echo "SYN_RECV: $(netstat -an 2>/dev/null | grep SYN_RECV | wc -l)"
    echo "TIME_WAIT: $(netstat -an 2>/dev/null | grep TIME_WAIT | wc -l)"
    echo ""
    
    echo -e "${YELLOW}Top 10 Connected IPs:${NC}"
    netstat -ntu 2>/dev/null | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -rn | head -10
    echo ""
    
    echo -e "${YELLOW}Blocked IPs (Firewall):${NC}"
    iptables -L INPUT -n -v | grep DROP | wc -l
    echo ""
    
    echo -e "${YELLOW}Fail2Ban Banned:${NC}"
    fail2ban-client status 2>/dev/null | grep "Jail list" || echo "No jails active"
    echo ""
}

whitelist_ip() {
    echo -e "${YELLOW}Whitelist IP Address${NC}"
    echo ""
    read -p "Enter IP address to whitelist: " ip_addr
    
    if [ -z "$ip_addr" ]; then
        echo -e "${RED}No IP provided${NC}"
        return
    fi
    
    iptables -I DAPSZ-WHITELIST -s "$ip_addr" -j ACCEPT
    netfilter-persistent save > /dev/null 2>&1
    
    # Also whitelist in Fail2Ban
    fail2ban-client set pterodactyl-panel unbanip "$ip_addr" 2>/dev/null
    fail2ban-client set pterodactyl-wings unbanip "$ip_addr" 2>/dev/null
    
    echo -e "${GREEN}✓ IP $ip_addr whitelisted${NC}"
    log_event "IP $ip_addr whitelisted"
}

emergency_allow_all() {
    echo -e "${RED}⚠ EMERGENCY MODE: This will allow ALL traffic!${NC}"
    echo -e "${YELLOW}Use only if locked out or testing.${NC}"
    echo ""
    read -p "Continue? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo -e "${GREEN}Cancelled${NC}"
        return
    fi
    
    echo -e "${YELLOW}Flushing all firewall rules...${NC}"
    
    iptables -F
    iptables -X
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    
    systemctl stop fail2ban
    
    echo -e "${GREEN}✓ All traffic allowed (Protection disabled)${NC}"
    echo -e "${YELLOW}Re-run script to re-enable protection${NC}"
    
    log_event "Emergency mode: All traffic allowed"
}

create_helper_scripts() {
    mkdir -p /usr/local/bin
    
    # Status
    cat > /usr/local/bin/ptero-status << 'EOF'
#!/bin/bash
echo "╔════════════════════════════════════════╗"
echo "║   Pterodactyl Protection Status        ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "Active Connections: $(netstat -an | grep ESTABLISHED | wc -l)"
echo "Blocked IPs: $(iptables -L INPUT -n | grep DROP | wc -l)"
echo ""
echo "Panel Status: $(systemctl is-active pteroq 2>/dev/null || echo 'Unknown')"
echo "Wings Status: $(systemctl is-active wings 2>/dev/null || echo 'Unknown')"
echo ""
fail2ban-client status 2>/dev/null | head -10
EOF
    chmod +x /usr/local/bin/ptero-status
    
    cat > /usr/local/bin/ptero-whitelist << 'EOF'
#!/bin/bash
if [ -z "$1" ]; then
    echo "Usage: ptero-whitelist <IP>"
    exit 1
fi
iptables -I DAPSZ-WHITELIST -s "$1" -j ACCEPT
netfilter-persistent save > /dev/null 2>&1
fail2ban-client unban "$1" 2>/dev/null
echo "✓ IP $1 whitelisted"
EOF
    chmod +x /usr/local/bin/ptero-whitelist
    
    cat > /usr/local/bin/ptero-unblock << 'EOF'
#!/bin/bash
if [ -z "$1" ]; then
    echo "Usage: ptero-unblock <IP>"
    exit 1
fi
iptables -D INPUT -s "$1" -j DROP 2>/dev/null
fail2ban-client unban "$1" 2>/dev/null
echo "✓ IP $1 unblocked"
EOF
    chmod +x /usr/local/bin/ptero-unblock
    
    log_event "Helper scripts created"
}

while true; do
    show_menu
    read choice
    
    case $choice in
        1) full_protection ;;
        2) create_base_firewall; protect_panel; netfilter-persistent save ;;
        3) protect_wings; netfilter-persistent save ;;
        4) protect_game_ports; netfilter-persistent save ;;
        5) enable_cloudflare_mode; netfilter-persistent save ;;
        6) echo "Rate limiting is included in full protection" ;;
        7) echo "Connection limits are included in full protection" ;;
        8) view_status ;;
        9) whitelist_ip ;;
        10) emergency_allow_all ;;
        11) echo -e "${GREEN}Exiting...${NC}" && exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}" ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done
