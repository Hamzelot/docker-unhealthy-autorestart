#!/bin/bash
echo "Container started."

# Load env variables
blacklist=${BLACKLIST:-}
notify_blacklist=${NOTIFY_BLACKLIST:-}

# Check variables for presence and set default if not
if [[ -z $blacklist ]]; then
  blacklist=()
else
  IFS=' ' read -r -a blacklist <<< "$blacklist"
  echo `date` "Blacklisted Containers:"
  printf '%s\n' "${blacklist[@]}"
fi
if [[ -z $notify_blacklist ]]; then
  notify_blacklist=()
else
  IFS=' ' read -r -a notify_blacklist <<< "$notify_blacklist"
  echo `date` "Blacklisted Notifications:"
  printf '%s\n' "${notify_blacklist[@]}"
fi

while true; do
  # Check if the Docker service is available
  if ! ls /var/run/docker.sock &> /dev/null; then
    # If the Docker service is not available, print an error message
    >&2 echo `date` "Error: Docker service is not available"
    exit 1
  fi

  echo `date` "Checking for unhealthy containers"
  set -e
  
  # Get the names of all unhealthy containers
  unhealthy_containers=$(docker ps --filter "health=unhealthy" | tail -n +2 | awk '{print $NF}')

  # Restart each unhealthy container and send a message to Telegram
  for container in $unhealthy_containers; do
    # Skip blacklisted containers
    if [[ "${blacklist[*]}" == *"$container"* ]]; then
      echo `date` "The unhealthy Container $container was skipped"
      continue
    fi
    # Restart the container and check the exit code
    if ! docker restart "$container"; then
      >&2 echo `date` "Error: Failed to restart container $container"
    else
      echo `date` "The Container $container was restarted"
    fi
  done

  # If no unhealthy containers were found, print a message
  if [ -z "$unhealthy_containers" ]; then
    echo `date` "All containers are healthy, next check in $POLL_INTERVAL seconds"
  fi
  sleep $POLL_INTERVAL
done