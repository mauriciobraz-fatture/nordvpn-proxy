#!/bin/bash

. /app/date.sh --source-only

#Env
JSON_FILE=/tmp/servers_recommendations.json
JSON_FILE_SERVER_COUNTRIES=/tmp/servers_countries

# If no server was set, choose the best
if [[ ! -v SERVER ]]; then
    echo "$(adddate) INFO: SERVER has not been set, choosing best for you."
    QUERY_PARAM='?'
    if [ -z "$RANDOM_TOP" ]
        then
            QUERY_PARAM=$QUERY_PARAM'limit=1'
        else
            QUERY_PARAM=$QUERY_PARAM'limit='$RANDOM_TOP
    fi
    if [ -z "$COUNTRY" ]; 
        then
            echo "$(adddate) INFO: No country has been set. The default will be picked by NordVPN API."
        else
            echo "$(adddate) INFO: Your country setting will be used: ${COUNTRY^^}"

            # Fetch and resolve country ID directly from the API
            COUNTRY_CODE=$(curl --silent "https://api.nordvpn.com/v1/servers/countries" \
                | jq --raw-output --arg CODE "${COUNTRY^^}" '.[] | select(.code == $CODE) | .id')

            if [ -z "$COUNTRY_CODE" ]; then
                echo "$(adddate) ERROR: Unable to resolve country code for '${COUNTRY^^}'"
                echo "$(adddate) ERROR: Check country abbreviation or API availability."
                exit 1
            fi

            echo "$(adddate) INFO: Resolved country ID $COUNTRY_CODE for country ${COUNTRY^^}"

            # Add to query string used to fetch servers
            QUERY_PARAM="${QUERY_PARAM}&filters%5Bcountry_id%5D=${COUNTRY_CODE}"
    fi
    
    #Set filter based on OpenVPN with the correct protocol
    QUERY_PARAM=$QUERY_PARAM'&filters%5Bservers_technologies%5D%5Bidentifier%5D=openvpn_'$PROTOCOL

    #GET fastest server based on COUNTRY
    #https://api.nordvpn.com/v1/servers/recommendations?limit=10&filters=[country_id]=106
    curl -s $SERVER_RECOMMENDATIONS_URL$QUERY_PARAM -o $JSON_FILE

    NUMBER_OF_SERVERS="$(jq length $JSON_FILE)"
    DESIRED_SERVER_NUMBER="$(shuf -i 0-$(($NUMBER_OF_SERVERS - 1)) -n 1)"

    #Set vars
    export SERVER="$(jq -r '.['$DESIRED_SERVER_NUMBER'].hostname' $JSON_FILE)"
    export SERVERNAME="$(jq -r '.['$DESIRED_SERVER_NUMBER'].name' $JSON_FILE)"
    export LOAD="$(jq -r '.['$DESIRED_SERVER_NUMBER'].load' $JSON_FILE)"
    export UPDATED_AT="$(jq -r '.['$DESIRED_SERVER_NUMBER'].updated_at' $JSON_FILE)"
    export IP="$(jq -r '.['$DESIRED_SERVER_NUMBER'].station' $JSON_FILE)"
    echo "$(jq -r '.['$DESIRED_SERVER_NUMBER'].hostname' $JSON_FILE)"
    echo "$(jq -r '.['$DESIRED_SERVER_NUMBER'].hostname' $JSON_FILE)" > /tmp/nordvpn_hostname

# Otherwise, use the server that was specified
else
    echo "$(adddate) INFO: SERVER has been set to ${SERVER^^}"
    curl --silent https://api.nordvpn.com/server | jq '.[] | select(.domain == '\"$SERVER\"')' > $JSON_FILE

    #Set vars
    export SERVERNAME="$(jq -r '.name' $JSON_FILE)"
    export LOAD=$(curl -s $SERVER_STATS_URL$SERVER | jq -r '.[]')
    export UPDATED_AT=""
    export IP="$(jq -r '.ip_address' $JSON_FILE)"
    echo "$SERVER" > /tmp/nordvpn_hostname
fi