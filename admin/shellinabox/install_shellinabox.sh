#!/bin/bash

yum install git openssl-devel pam-devel zlib-devel autoconf automake libtool
git clone https://github.com/shellinabox/shellinabox.git && cd shellinabox
autoreconf -i

# Config
CSS_FILE="/etc/shellinabox/options-enabled/black.css"
sudo mkdir -p /etc/shellinabox/options-enabled

sudo tee $CSS_FILE > /dev/null <<'EOF'
/* Terminal Background */
/* Deep Charcoal Background */
terminal, .ansi_background_default { 
    background-color: #2E3440 !important; 
}

/* Soft White Text */
terminal, .ansi_foreground_default { 
    color: #D8DEE9 !important; 
}

/* Selection Highlight */
::selection {
    background: #4C566A;
    color: #ECEFF4;
}
EOF

sudo tee /etc/systemd/system/shellinabox.service > /dev/null <<'EOF'
[Unit]
Description=Shellinabox Terminal Emulator
After=network.target

[Service]
# Replace 'username' with your actual linux user if you want to run as non-root
# User=username
# Group=username
#    --background=/var/run/shellinaboxd.pid \


ExecStart=/home/ec2-user/shellinabox/shellinaboxd \
    --port=4200 \
    --css=/etc/shellinabox/options-enabled/black.css \
    --service=/:LOGIN

# Basic security and reliability
Restart=on-failure
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable shellinabox.service
sudo systemctl start shellinabox.service
