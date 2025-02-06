#!/bin/bash

# Function to run commands and check for errors
run_command() {
    echo "Running: $1"
    eval "$1"
    if [ $? -ne 0 ]; then
        echo "Error executing: $1"
        exit 1
    fi
}

# Set hostname
set_hostname() {
    HOSTNAME="fs.karle.infra"
    run_command "sudo hostnamectl set-hostname $HOSTNAME"
    echo "Hostname set to $HOSTNAME"
}

# Install Samba
install_samba() {
    run_command "sudo zypper -n refresh"
    run_command "sudo zypper -n install samba"
    echo "Samba installed successfully"
}

# Configure firewall
configure_firewall() {
    run_command "sudo firewall-cmd --add-service=samba --permanent"
    run_command "sudo firewall-cmd --reload"
    echo "Firewall configured for Samba traffic"
}

# Create users and groups
create_users_and_groups() {
    # Users to create
    USERS=("tiit" "karle" "teet" "tuut" "piip" "kristi")
    
    # Create groups
    run_command "sudo groupadd juhatus || true"
    run_command "sudo groupadd tootajad || true"

    # Create users and add them to groups
    for USER in "${USERS[@]}"; do
        run_command "sudo useradd $USER || true"
        echo "$USER:password123" | sudo chpasswd
        
        if [[ "$USER" == "tiit" || "$USER" == "karle" || "$USER" == "teet" ]]; then
            run_command "sudo usermod -a -G juhatus $USER"
        fi

        run_command "sudo usermod -a -G tootajad $USER"
        run_command "echo 'password123' | sudo smbpasswd -a $USER --stdin"
    done

    echo "Users and groups created successfully"
}

# Create directories and set permissions
create_directories() {
    # Define directories, groups, and permissions
    DIRECTORIES=(
        "/srv/samba/Avalik:users:777"
        "/srv/samba/Juhatus:juhatus:770"
        "/srv/samba/Tootajad:tootajad:770"
    )

    for ENTRY in "${DIRECTORIES[@]}"; do
        IFS=":" read -r DIR GROUP PERM <<< "$ENTRY"
        run_command "sudo mkdir -p $DIR"
        run_command "sudo chown root:$GROUP $DIR"
        run_command "sudo chmod $PERM $DIR"
    done

    echo "Directories created and permissions set successfully"
}

# Configure Samba shares
configure_samba() {
    SAMBA_CONFIG="/etc/samba/smb.conf"

    sudo bash -c "cat > $SAMBA_CONFIG <<EOL
[global]
   workgroup = WORKGROUP
   server string = Desperado Ehitus File Server
   security = user
   map to guest = bad user

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
   valid users = @tootajad,@juhatus
   read only = no
EOL"

    echo "Samba configuration file updated at $SAMBA_CONFIG"

    # Restart Samba services to apply changes
    run_command "sudo systemctl restart smb nmb"
}

# Enable Samba services on boot and start them now
start_samba_services() {
    run_command "sudo systemctl enable smb nmb"
    run_command "sudo systemctl start smb nmb"
    echo "Samba services enabled and started successfully"
}

# Main function to execute all steps in order
main() {
    set_hostname
    install_samba
    configure_firewall
    create_users_and_groups
    create_directories
    configure_samba
    start_samba_services

    echo "Samba file server setup completed successfully!"
}

# Execute the main function
main

