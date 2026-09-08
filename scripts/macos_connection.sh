#!/usr/bin/env bash

UPSTREAM_IFACE=${1:-en0}
USB_IFACE=''
USB_IP=${2:-10.0.0.1}

for i in $(ifconfig -lu); do
  if ifconfig $i | grep -q "${USB_IP}" ; then USB_IFACE=$i; fi;
done

if [ -z "$USB_IFACE" ]
then
  echo "can't find usb interface with ip $USB_IP"
  exit 1
fi




















#Parse arguments 
while getopts "u:h:p:i:c:?" opt; do
    case "$opt" in
        u) USER="$OPTARG" ;;
        h) HOST="$OPTARG" ;;
        p) PORT="$OPTARG" ;;
        i) IDENTITY="$OPTARG" ;;
        c) COMMAND="$OPTARG" ;;
        \?|?) usage ;;
        *) usage ;;
    esac
done


# Validate required
if [[ -z "$USER" || -z "$HOST" ]]; then
    echo "Error: Both -u (user) and -h (host) are required."
    usage
fi


echo "sharing connecting from upstream interface $UPSTREAM_IFACE to usb interface $USB_IFACE ..."

sysctl -w net.inet.ip.forwarding=1
pfctl -e
echo "nat on ${UPSTREAM_IFACE} from ${USB_IFACE}:network to any -> (${UPSTREAM_IFACE})" | pfctl -f -







# Build the SSH command
SSH_CMD="ssh"

# Add port if not default
[[ "$PORT" != "22" ]] && SSH_CMD+=" -p $PORT"

# Add identity file if provided
[[ -n "$IDENTITY" ]] && SSH_CMD+=" -i $IDENTITY"

# Add user@host
SSH_CMD+=" $USER@$HOST"

# Add command if provided, else start interactive session
if [[ -n "$COMMAND" ]]; then
    SSH_CMD+=" \"$COMMAND\""
else
    # Use -t to force pseudo‑terminal allocation (useful for interactive)
    SSH_CMD="-t $SSH_CMD"
fi
