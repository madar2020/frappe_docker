#!/bin/bash

function configureEnv() {
  if [ ! -f /home/frappe/frappe-bench/sites/common_site_config.json ]; then

    if [[ -z "$MARIADB_HOST" ]]; then
      echo "MARIADB_HOST is not set"
      exit 1
    fi

    if [[ -z "$REDIS_CACHE" ]]; then
      echo "REDIS_CACHE is not set"
      exit 1
    fi

    if [[ -z "$REDIS_QUEUE" ]]; then
      echo "REDIS_QUEUE is not set"
      exit 1
    fi

    if [[ -z "$REDIS_SOCKETIO" ]]; then
      echo "REDIS_SOCKETIO is not set"
      exit 1
    fi

    if [[ -z "$SOCKETIO_PORT" ]]; then
      echo "SOCKETIO_PORT is not set"
      exit 1
    fi

    envsubst '${MARIADB_HOST}
      ${REDIS_CACHE}
      ${REDIS_QUEUE}
      ${REDIS_SOCKETIO}
      ${SOCKETIO_PORT}' < /opt/frappe/common_site_config.json.template > /home/frappe/frappe-bench/sites/common_site_config.json
  fi
}

function checkConnection() {
  su frappe -c ". /home/frappe/frappe-bench/env/bin/activate \
    && python /home/frappe/frappe-bench/commands/check_connection.py"
}

function checkConfigExists() {
  COUNTER=0
  while [[ ! -e /home/frappe/frappe-bench/sites/common_site_config.json ]] && [[ $COUNTER -le 30 ]] ; do
      sleep 1
      (( COUNTER=COUNTER+1 ))
      echo "config file not created, retry $COUNTER"
  done

  if [[ ! -e /home/frappe/frappe-bench/sites/common_site_config.json ]]; then
    echo "timeout: config file not created"
    exit 1
  fi
}

if [[ ! -e /home/frappe/frappe-bench/sites/apps.txt ]]; then
  find /home/frappe/frappe-bench/apps -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -r > /home/frappe/frappe-bench/sites/apps.txt
fi

if [ "$1" = 'start' ]; then
  configureEnv
  checkConnection

  chown frappe:frappe /home/frappe/frappe-bench/sites/common_site_config.json

  if [[ -z "$WORKERS" ]]; then
    export WORKERS=2
  fi

  if [[ -z "$FRAPPE_PORT" ]]; then
    export FRAPPE_PORT=8000
  fi


  if [[ -z "$RUN_AS_ROOT" ]]; then
    su frappe -c ". /home/frappe/frappe-bench/env/bin/activate \
      && gunicorn -b 0.0.0.0:$FRAPPE_PORT \
      --worker-tmp-dir /dev/shm \
      --threads=4 \
      --workers $WORKERS \
      --worker-class=gthread \
      --log-file=- \
      -t 120 frappe.app:application --preload"
  else
    . /home/frappe/frappe-bench/env/bin/activate
    gunicorn -b 0.0.0.0:$FRAPPE_PORT \
      --worker-tmp-dir /dev/shm \
      --threads=4 \
      --workers $WORKERS \
      --worker-class=gthread \
      --log-file=- \
      -t 120 frappe.app:application --preload
  fi

elif [ "$1" = 'worker' ]; then
  checkConfigExists
  checkConnection
  # default WORKER_TYPE=default
  if [[ -z "$RUN_AS_ROOT" ]]; then
    su frappe -c ". /home/frappe/frappe-bench/env/bin/activate \
      && python /home/frappe/frappe-bench/commands/worker.py"
  else
    . /home/frappe/frappe-bench/env/bin/activate
    python /home/frappe/frappe-bench/commands/worker.py
  fi

elif [ "$1" = 'schedule' ]; then
  checkConfigExists
  checkConnection
  if [[ -z "$RUN_AS_ROOT" ]]; then
    su frappe -c ". /home/frappe/frappe-bench/env/bin/activate \
      && python /home/frappe/frappe-bench/commands/background.py"
  else
    . /home/frappe/frappe-bench/env/bin/activate
    python /home/frappe/frappe-bench/commands/background.py
  fi

elif [ "$1" = 'new' ]; then

  if [[ -z "$RUN_AS_ROOT" ]]; then
    su frappe -c ". /home/frappe/frappe-bench/env/bin/activate \
      && python /home/frappe/frappe-bench/commands/new.py"
    exit
  else
    . /home/frappe/frappe-bench/env/bin/activate
    python /home/frappe/frappe-bench/commands/new.py
  fi

elif [ "$1" = 'migrate' ]; then

  su frappe -c ". /home/frappe/frappe-bench/env/bin/activate \
    && python /home/frappe/frappe-bench/commands/migrate.py"
  exit

elif [ "$1" = 'doctor' ]; then

  su frappe -c ". /home/frappe/frappe-bench/env/bin/activate \
    && python /home/frappe/frappe-bench/commands/doctor.py"
  exit

elif [ "$1" = 'backup' ]; then

  if [[ -z "$RUN_AS_ROOT" ]]; then
    su frappe -c ". /home/frappe/frappe-bench/env/bin/activate \
      && python /home/frappe/frappe-bench/commands/backup.py"
    exit
  else
    . /home/frappe/frappe-bench/env/bin/activate
    python /home/frappe/frappe-bench/commands/backup.py
  fi

elif [ "$1" = 'console' ]; then

  if [[ -z "$2" ]]; then
    echo "Need to specify a sitename with the command:"
    echo "console <sitename>"
    exit 1
  fi

  if [[ -z "$RUN_AS_ROOT" ]]; then
    su frappe -c ". /home/frappe/frappe-bench/env/bin/activate \
      && python /home/frappe/frappe-bench/commands/console.py $2"
    exit
  else
    . /home/frappe/frappe-bench/env/bin/activate
    python /home/frappe/frappe-bench/commands/console.py "$2"
  fi

else

  exec su frappe -c "$@"

fi
