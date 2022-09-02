#!/bin/bash -e

function help_menu() {
    printf "\
  TODO
"
}

function send_discord_alert() {
    if [[ ! -z ${USER_ID} ]]; then
        #Whitespace here is messed up, but presents the correct notification formatting
        #TODO: Fix needing to add explicit whitespace/formatting for $content
        content="
<@${USER_ID}>
**Alert:** $NODE_NAME - $ext_ip"
    else
        content="**Alert:** $NODE_NAME - $ext_ip"
    fi
    json=$(jq -n '
    {
        "username": $username,
        "content": $content,
        "embeds": [
            {
                "color": $color,
                "fields": [
                    {
                        "name": "Device",
                        "value": $device
                    },
                    {
                        "name": "Mount Point",
                        "value": $mount_point
                    },
                    {
                        "name": "Disk Space Used",
                        "value": $disk_used
                    },
                    {
                        "name": "Remaining Disk Space",
                        "value": $disk_avail
                    },
                                        {
                        "name": "Disk Percent Used",
                        "value": $disk_percent_used
                    },
                                        {
                        "name": "Disk Percent Remaining",
                        "value": $disk_percent_left
                    }
                ]
            }
        ]
    }' \
    --arg username "$BOT_NAME" \
    --arg ext_ip "$ext_ip" \
    --arg content "$content" \
    --arg color "$COLOR" \
    --arg disk_used "${disk_used}/${disk_size}" \
    --arg disk_percent_used "${disk_percent_used}%" \
    --arg disk_percent_left "${disk_percent_left}%" \
    --arg disk_avail "$disk_avail" \
    --arg device "$device" \
    --arg mount_point "$mount_point" 2>/dev/null)

    if [[ $LOG == "True" ]]; then
        echo "TODO"
    fi

    curl \
       -H "Content-Type: application/json" \
       -d "${json}" \
       $WEBHOOK_URL
}

COLOR='15022389'

# getopt boilerplate for argument parsing
OPTS=$(getopt -o b:d:ln:p:s:u:w:h --long botname:,discord_webhook:,log,nodename:,percent:,space:,user:,webhook:,help \
            -n 'Storage Notifier' -- "$@")

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

eval set -- "$OPTS"

#Handle argument parsing/assignment
while true; do
case "$1" in
    -b | --botname ) BOT_NAME="$2"; shift 2 ;;
    -d | --device ) DEVICE="$2"; shift 2 ;;
    -l | --log ) LOG="True"; shift ;;
    -n | --nodename ) NODE_NAME="$2"; shift 2 ;;
    -p | --percent ) SPACELEFT_THRESHOLD_PERCENT="$2"; shift 2 ;;
    -s | --space ) SPACELEFT_THRESHOLD_INT="$2"; shift 2 ;;
    -u | --user ) USER_ID="$2"; shift 2 ;;
    -w | --webhook ) WEBHOOK_URL="$2"; shift 2 ;;
    -h | --help ) HELP_MENU="True"; shift ;;
    -- ) shift; break ;;
    * ) break ;;
esac
done

# Check dependencies
if [[ ! $(which jq bc curl) ]]; then
    printf "Error: Dependencies are missing. Please ensure the following packages are installed:\njq\nbc\ncurl\n"
    exit 1
fi

# Check to display help menu
if [[ ! -z $HELP_MENU ]]; then
    help_menu
    exit 0
fi

# Check thresholds
printf "Checking Devices\n"
if [[ ! -z $SPACELEFT_THRESHOLD_INT && ! -z $SPACELEFT_THRESHOLD_PERCENT ]]; then
    printf "Error: Do not select both a space and percentage threshold\n"
    exit 1
elif [[ ! -z $SPACELEFT_THRESHOLD_INT ]]; then
    ext_ip=$(curl -s ifconfig.me)
    for device in ${DEVICE[@]}; do
        disk_size=$(df -h | grep "$device" | awk '{print $2}')
        disk_used=$(df -h | grep "$device" | awk '{print $3}')
        disk_avail=$(df | grep "$device" | awk '{print $4}' | awk '{print $1/1000/1000 "G"}')
        disk_percent_used=$(df -h | grep "$device" | awk '{print $5}' | cut -d % -f 1)
        mount_point=$(df | grep "$device" | awk '{print $6}')
        if [[ $disk_avail < $SPACELEFT_THRESHOLD_INT ]]; then
            send_discord_alert
        fi
    done
elif [[ ! -z $SPACELEFT_THRESHOLD_PERCENT ]]; then
    ext_ip=$(curl -s ifconfig.me)
    for device in ${DEVICE[@]}; do
        disk_size=$(df -h | grep "$device" | awk '{print $2}')
        disk_used=$(df -h | grep "$device" | awk '{print $3}')
        disk_avail=$(df | grep "$device" | awk '{print $4}' | awk '{print $1/1000/1000 "G"}')
        disk_percent_used=$(df -h | grep "$device" | awk '{print $5}' | cut -d % -f 1)
        disk_percent_left=$(echo "100 - ${disk_percent_used}" | bc)
        mount_point=$(df | grep "$device" | awk '{print $6}')
        if [[ $disk_percent_left < $SPACELEFT_THRESHOLD_PERCENT ]]; then
            send_discord_alert
        fi
    done
fi

printf "Done Checking Devices\n"

exit 0