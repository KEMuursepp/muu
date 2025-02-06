#!/bin/bash

# Exit on any error
set -e

echo "Starting Samba File Server Setup for Desperado Ehitus OÜ..."

# 1. Set hostname
sudo hostnamectl set-hostname fs.karle.infra

# 2. Install Samba
echo "Installing Samba..."
sudo zypper --non-interactive install samba

# 3. Configure firewall
echo "Configuring firewall..."
sudo firewall-cmd --add-service=samba --permanent
sudo firewall-cmd --reload

# 4. Create users
echo "Creating users..."
for user in tiit karle teet tuut piip kristi
do
    sudo useradd -m $user
    echo "${user}:Pass123!" | sudo chpasswd
done

# 5. Create groups
echo "Creating groups..."
sudo groupadd juhatus
sudo groupadd tootajad

# 6. Add users to groups
echo "Adding users to groups..."
# Add to juhatus (management)
for user in tiit karle teet
do
    sudo usermod -a -G juhatus $user
done

# Add all users to tootajad (workers)
for user in tiit karle teet tuut piip kristi
do
    sudo usermod -a -G tootajad $user
done

# 7. Create Samba users
echo "Creating Samba users..."
for user in tiit karle teet tuut piip kristi
do
    (echo "Pass123!"; echo "Pass123!") | sudo smbpasswd -a $user
done

# 8. Create shared directories
echo "Creating shared directories..."
sudo mkdir -p /srv/samba/{Avalik,Juhatus,Tootajad}

# 9. Set permissions
echo "Setting permissions..."
sudo chown root:users /srv/samba/Avalik
sudo chmod 777 /srv/samba/Avalik

sudo chown root:juhatus /srv/samba/Juhatus
sudo chmod 770 /srv/samba/Juhatus

sudo chown root:tootajad /srv/samba/Tootajad
sudo chmod 770 /srv/samba/Tootajad

# 10. Configure Samba
echo "Configuring Samba..."
cat << EOF | sudo tee -a /etc/samba/smb.conf
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

# 11. Enable and start Samba services
echo "Starting Samba services..."
sudo systemctl enable smb nmb
sudo systemctl start smb nmb

echo "Setup complete! Please test the following:"
echo "1. Windows network drive mapping: \\\\$(hostname -I | awk '{print $1}')\\"
echo "2. Test with different user accounts:"
echo "   - Management user (e.g., karle:Pass123!)"
echo "   - Regular worker (e.g., piip:Pass123!)"
echo "3. Verify access permissions for each share"

