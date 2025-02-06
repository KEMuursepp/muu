#!/bin/bash
set -e

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Exiting."
    exit 1
fi

# Variables
YOURNAME="karle"
HOSTNAME="fs.${YOURNAME}.infra"
SMB_PASS="123456"  # Default password for Samba users

echo "Setting hostname to ${HOSTNAME}..."
hostnamectl set-hostname ${HOSTNAME}
hostnamectl

echo "Installing Samba and Expect if not already installed..."
zypper -n in samba expect

echo "Enabling and starting Samba services..."
systemctl enable smb nmb
systemctl start smb nmb

echo "Adding Samba service to the firewall..."
firewall-cmd --add-service=samba --permanent
firewall-cmd --reload

#############################
# Create Users and Groups
#############################

# Function to create a user if it does not exist
create_user() {
    local username="$1"
    if id "$username" &>/dev/null; then
        echo "User $username already exists. Skipping."
    else
        echo "Creating user $username..."
        useradd -m "$username"
    fi
}

# Users to create
for user in tiit karle teet tuut piip kristi; do
    create_user "$user"
done

# Function to create a group if it does not exist
create_group() {
    local groupname="$1"
    if getent group "$groupname" > /dev/null; then
        echo "Group $groupname already exists. Skipping."
    else
        echo "Creating group $groupname..."
        groupadd "$groupname"
    fi
}

# Create groups
create_group juhatus
create_group tootajad

# Add all users into the 'tootajad' group
echo "Adding all users to group 'tootajad'..."
for user in tiit karle teet tuut piip kristi; do
    usermod -a -G tootajad "$user"
done

# Add executives only into the 'juhatus' group (assuming tiit, karle and teet are executives)
echo "Adding executive users to group 'juhatus'..."
for user in tiit karle teet; do
    usermod -a -G juhatus "$user"
done

#############################
# Configure Samba Users
#############################

# Function to set Samba password using expect
smb_set_password() {
    local user="$1"
    expect <<EOF
spawn smbpasswd -a $user
expect "New SMB password:"
send "$SMB_PASS\r"
expect "Retype new SMB password:"
send "$SMB_PASS\r"
expect eof
EOF
}

echo "Adding Samba users and setting passwords..."
for user in tiit karle teet tuut piip kristi; do
    smb_set_password "$user"
done

#############################
# Create Directories and Set Permissions
#############################

echo "Creating shared directories..."
mkdir -p /srv/samba/Avalik /srv/samba/Juhatus /srv/samba/Tootajad

echo "Configuring /srv/samba/Avalik (public share)..."
chown root:users /srv/samba/Avalik
chmod 777 /srv/samba/Avalik

echo "Configuring /srv/samba/Juhatus (executives only)..."
chown root:juhatus /srv/samba/Juhatus
chmod 770 /srv/samba/Juhatus

echo "Configuring /srv/samba/Tootajad (employees and executives)..."
chown root:tootajad /srv/samba/Tootajad
chmod 770 /srv/samba/Tootajad

#############################
# Configure Samba Shares
#############################

echo "Backing up existing /etc/samba/smb.conf..."
cp /etc/samba/smb.conf /etc/samba/smb.conf.bak

echo "Appending share definitions to /etc/samba/smb.conf..."
cat >> /etc/samba/smb.conf <<EOF

[Avalik]
   path = /srv/samba/Avalik
   read only = no
   browsable = yes

[Juhatus]
   path = /srv/samba/Juhatus
   valid users = @juhatus
   read only = no

[Tootajad]
   path = /srv/samba/Tootajad
   valid users = @tootajad @juhatus
   read only = no
EOF

echo "Restarting Samba services..."
systemctl restart smb nmb

echo "Samba file server setup completed successfully."
