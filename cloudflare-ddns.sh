#!/bin/bash

# ==========================================
# Cloudflare Dynamic DNS Updater
# ==========================================

set -u

CONFIG="/etc/cloudflare-ddns.conf"

# Check configuration
if [ ! -f "$CONFIG" ]; then
    echo "ERROR: Configuration file not found: $CONFIG"
    exit 1
fi

# Load configuration
source "$CONFIG"

# Check required variables
if [ -z "${API_TOKEN:-}" ]; then
    echo "ERROR: API_TOKEN is not configured."
    exit 1
fi

if [ "${#RECORDS[@]}" -eq 0 ]; then
    echo "ERROR: No DNS records configured."
    exit 1
fi

# Get current public IPv4 address
CURRENT_IP=$(curl -4 -fsS --max-time 10 https://api.ipify.org)

if [ -z "$CURRENT_IP" ]; then
    echo "ERROR: Could not determine public IP."
    exit 1
fi

# Basic IPv4 validation
if ! [[ "$CURRENT_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: Invalid public IP returned: $CURRENT_IP"
    exit 1
fi

echo "Current public IP: $CURRENT_IP"
echo

# Process every configured DNS record
for RECORD_NAME in "${RECORDS[@]}"; do

    echo "Checking $RECORD_NAME..."

    # Determine Cloudflare zone
    ZONE_NAME=$(echo "$RECORD_NAME" | awk -F. '{print $(NF-1)"."$NF}')

    if [ -z "$ZONE_NAME" ]; then
        echo "ERROR: Could not determine zone for $RECORD_NAME"
        echo
        continue
    fi

    # Find Cloudflare Zone ID
    ZONE_RESPONSE=$(curl -fsS --max-time 10 \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" \
        "https://api.cloudflare.com/client/v4/zones?name=$ZONE_NAME")

    ZONE_ID=$(echo "$ZONE_RESPONSE" | jq -r '.result[0].id')

    if [ "$ZONE_ID" = "null" ] || [ -z "$ZONE_ID" ]; then
        echo "ERROR: Could not find Cloudflare zone: $ZONE_NAME"
        echo
        continue
    fi

    # Find the DNS record
    RECORD_RESPONSE=$(curl -fsS --max-time 10 \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" \
        "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=A&name=$RECORD_NAME")

    RECORD_ID=$(echo "$RECORD_RESPONSE" | jq -r '.result[0].id')
    DNS_IP=$(echo "$RECORD_RESPONSE" | jq -r '.result[0].content')

    if [ "$RECORD_ID" = "null" ] || [ -z "$RECORD_ID" ]; then
        echo "ERROR: DNS record not found: $RECORD_NAME"
        echo
        continue
    fi

    echo "Cloudflare IP: $DNS_IP"

    # Nothing to update
    if [ "$CURRENT_IP" = "$DNS_IP" ]; then
        echo "IP has not changed."
        echo
        continue
    fi

    echo "IP changed!"
    echo "Updating $RECORD_NAME: $DNS_IP -> $CURRENT_IP"

    # Update DNS record
    UPDATE_RESPONSE=$(curl -fsS --max-time 10 -X PUT \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{
            \"type\": \"A\",
            \"name\": \"$RECORD_NAME\",
            \"content\": \"$CURRENT_IP\",
            \"ttl\": 1,
            \"proxied\": true
        }" \
        "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID")

    SUCCESS=$(echo "$UPDATE_RESPONSE" | jq -r '.success')

    if [ "$SUCCESS" = "true" ]; then
        echo "Successfully updated $RECORD_NAME to $CURRENT_IP"
    else
        echo "ERROR: Cloudflare update failed for $RECORD_NAME"
        echo "$UPDATE_RESPONSE"
    fi

    echo
done
