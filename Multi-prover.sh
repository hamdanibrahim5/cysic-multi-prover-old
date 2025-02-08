#!/bin/bash

echo "
  ___   _     ______   _____  _____  _____ 
 / _ \ | |    |  ___| /  __ \/  ___|/  ___|
/ /_\ \| |    | |_    | /  \/\ `--. \ `--. 
|  _  || |    |  _|   | |     `--. \ `--. \\
| | | || |____| |     | \__/\/\__/ //\__/ /
\_| |_/\_____/\_|      \____/\____/ \____/ 
                                           
Join our Telegram channel: https://t.me/cssurabaya
"

echo "Enter the number of prover nodes to run:"
read COUNT
declare -a REWARD_ADDRESSES
for ((i = 1; i <= COUNT; i++))
do
  echo "Enter reward address for prover $i (0x...):"
  read REWARD_ADDRESS
  REWARD_ADDRESSES+=("$REWARD_ADDRESS")  
done

# Download setup Prover from cysic 
curl -L https://github.com/cysic-labs/phase2_libs/releases/download/v1.0.0/setup_prover.sh -o ~/"setup_prover.sh"
chmod +x ~/setup_prover.sh
PROVER_DIR=~/cysic-prover
for ((i = 1; i <= COUNT; i++))
do  
  echo "Setting up prover with reward address: ${REWARD_ADDRESSES[$i-1]}"
  sleep 5
  bash ~/"setup_prover.sh" "${REWARD_ADDRESSES[$i-1]}"
  mkdir -p $PROVER_DIR/.cysic/assets/scroll/v1/params
  curl -L --retry 999 -C - https://circuit-release.s3.us-west-2.amazonaws.com/setup/params20 -o $PROVER_DIR/.cysic/assets/scroll/v1/params/params20
  curl -L --retry 999 -C - https://circuit-release.s3.us-west-2.amazonaws.com/setup/params24 -o $PROVER_DIR/.cysic/assets/scroll/v1/params/params24
  curl -L --retry 999 -C - https://circuit-release.s3.us-west-2.amazonaws.com/setup/params25 -o $PROVER_DIR/.cysic/assets/scroll/v1/params/params25
  sha256sum "$PROVER_DIR"/*.so "$PROVER_DIR/prover"
  FINAL_DIR="cysic-prover$((COUNT - i + 1))"
  mv "$PROVER_DIR" "$FINAL_DIR"
  sleep 15
done

# Install Supervisor
apt update && apt install -y supervisor

# Create Supervisor config 
echo '[unix_http_server]
file=/tmp/supervisor.sock   ; the path to the socket file

[supervisord]
logfile=/tmp/supervisord.log ; main log file; default $CWD/supervisord.log
logfile_maxbytes=50MB        ; max main logfile bytes b4 rotation; default 50MB
logfile_backups=10           ; # of main logfile backups; 0 means none, default 10
loglevel=info                ; log level; default info; others: debug,warn,trace
pidfile=/tmp/supervisord.pid ; supervisord pidfile; default supervisord.pid
nodaemon=false               ; start in foreground if true; default false
silent=false                 ; no logs to stdout if true; default false
minfds=1024                  ; min. avail startup file descriptors; default 1024
minprocs=200                 ; min. avail process descriptors;default 200
strip_ansi=true

[rpcinterface:supervisor]
supervisor.rpcinterface_factory=supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix:///tmp/supervisor.sock' > supervisord.conf

for ((i = 1; i <= COUNT; i++))
do
  FINAL_DIR="cysic-prover$((COUNT - i + 1))"
  echo "[program:cysic-prover$((COUNT - i + 1))]
command=bash -c \"sleep 15 && /$HOME/$FINAL_DIR/prover\"
numprocs=1
directory=/$HOME/$FINAL_DIR
priority=999
autostart=true
redirect_stderr=true
stdout_logfile=$HOME/$FINAL_DIR/cysic-prover.log
stdout_logfile_maxbytes=1GB
stdout_logfile_backups=1
environment=LD_LIBRARY_PATH=\"$HOME/$FINAL_DIR\",CHAIN_ID=\"534352\"" >> supervisord.conf
done

supervisord -c supervisord.conf

echo "Installation complete. Prover nodes are running under Supervisor."
echo "For checking logs, run: supervisorctl tail -f cysic-prover(Numberprover)"
