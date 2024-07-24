#!/bin/bash

log() {
    local level=$1
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*"
}

if [ $# -eq 0 ]; then
    log "ERROR" "Usage: $0 <directory>"
    exit 1
fi

DIR=$1

if [ ! -d "$DIR" ]; then
    log "ERROR" "'$DIR' is not a valid directory."
    exit 1
fi

LAST_IP_FOUND=false
LAST_IPV6_FOUND=false

if [ -f "$DIR/last_ip.txt" ]; then
    LAST_IP=$(cat "$DIR/last_ip.txt")
    log "INFO" "Last IPv4 read from file: $LAST_IP"
    LAST_IP_FOUND=true
else
    log "INFO" "File 'last_ip.txt' not found in directory '$DIR'."
fi

if [ -f "$DIR/last_ipv6.txt" ]; then
    LAST_IPV6=$(cat "$DIR/last_ipv6.txt")
    log "INFO" "Last IPv6 read from file: $LAST_IPV6"
    LAST_IPV6_FOUND=true
else
    log "INFO" "File 'last_ipv6.txt' not found in directory '$DIR'."
fi

CURRENT_IP=$(curl --silent --location "ipv4.wtfismyip.com")
log "INFO" "Current IPv4 fetched: $CURRENT_IP"

CURRENT_IPV6=$(curl --silent --location "ipv6.wtfismyip.com")
log "INFO" "Current IPv6 fetched: $CURRENT_IPV6"

if [ "$LAST_IP_FOUND" = false ]; then
    echo "$CURRENT_IP" > "$DIR/last_ip.txt"
    log "INFO" "Created 'last_ip.txt' with the current IP: $CURRENT_IP"
fi

if [ "$LAST_IPV6_FOUND" = false ]; then
    echo "$CURRENT_IPV6" > "$DIR/last_ipv6.txt"
    log "INFO" "Created 'last_ipv6.txt' with the current IPv6: $CURRENT_IPV6"
fi

IP_CHANGED=false
if [ "$CURRENT_IP" != "$LAST_IP" ]; then
    IP_CHANGED=true
    echo "$CURRENT_IP" > "$DIR/last_ip.txt"
    log "INFO" "IPv4 changed from $LAST_IP to $CURRENT_IP"
fi

if [ "$CURRENT_IPV6" != "$LAST_IPV6" ]; then
    IP_CHANGED=true
    echo "$CURRENT_IPV6" > "$DIR/last_ipv6.txt"
    log "INFO" "IPv6 changed from $LAST_IPV6 to $CURRENT_IPV6"
fi

if [ "$IP_CHANGED" = true ]; then
    TARGET_DIR="${DIR%/}/nginx/proxy_host"
    log "INFO" "Starting IP replacement in files in $TARGET_DIR/"
    
    for file in "$TARGET_DIR"/*.conf; do
        if [ -f "$file" ]; then
            log "INFO" "Processing file: $file"
            
            if [ -n "$LAST_IP" ] && [ "$CURRENT_IP" != "$LAST_IP" ]; then
                sed -i "s/$LAST_IP/$CURRENT_IP/g" "$file" 2>/tmp/sed_error.log
                if [ $? -eq 0 ]; then
                    log "INFO" "Successfully updated IPv4 in $file"
                else
                    log "ERROR" "Failed to update IPv4 in $file. See /tmp/sed_error.log for details."
                fi
            fi
            
            if [ -n "$LAST_IPV6" ] && [ "$CURRENT_IPV6" != "$LAST_IPV6" ]; then
                sed -i "s/$LAST_IPV6/$CURRENT_IPV6/g" "$file" 2>/tmp/sed_error.log
                if [ $? -eq 0 ]; then
                    log "INFO" "Successfully updated IPv6 in $file"
                else
                    log "ERROR" "Failed to update IPv6 in $file. See /tmp/sed_error.log for details."
                fi
            fi
        else
            log "INFO" "Skipping non-file: $file"
        fi
    done
    log "INFO" "IP replacement completed."
else
    log "INFO" "No IP change detected; no replacement needed."
fi
