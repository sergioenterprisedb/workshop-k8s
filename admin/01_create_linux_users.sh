#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Error: This script must be run as root or with sudo."
    exit 1
fi

source ./config.sh

# Loop from 1 to the value of USER_COUNT
for (( i=1; i<=$TOTAL_USERS; i++ ))
do
    USERNAME="user$i"
    PASSWORD="password$i"

    # Check if the user already exists
    if id "$USERNAME" &>/dev/null; then
        echo "User $USERNAME already exists. Skipping..."
    else
        # Create user with a home directory
        useradd -m "$USERNAME"

        # docker group
        usermod -aG docker ${USERNAME}

        # Pipe the username:password pair into chpasswd
        echo "$USERNAME:$PASSWORD" | chpasswd
        echo "Successfully created $USERNAME."

        # Copy template to user
        echo "Copying source template ${SOURCE_CNP_PATH}/ to user /home/${USERNAME}"
        cp -r ${SOURCE_CNP_PATH}/ /home/${USERNAME}

        # Grant permissions
        chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}"

        # Profile
        kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
        sudo chmod a+r /etc/bash_completion.d/kubectl

        # profile config
        echo "alias k=kubectl" >> /home/${USERNAME}/.bash_profile
        echo 'complete -o default -F __start_kubectl k' >> /home/${USERNAME}/.bash_profile

        # Kubeconfig
        mkdir /home/${USERNAME}/.kube
        chown ${USERNAME}:${USERNAME} /home/${USERNAME}/.kube
        cp /usr/local/share/k8s/k3d-config /home/${USERNAME}/.kube/config
        chown ${USERNAME}:${USERNAME} /home/${USERNAME}/.kube/config
        echo "export KUBECONFIG=~/.kube/config" >> /home/${USERNAME}/.bash_profile
        
        # Set context
        echo "cd cnpg-hands-on && ./set_context.sh" >> /home/${USERNAME}/.bash_profile

        # Alias bat
        #echo "alias cat='bat -pp'" >> /home/${USERNAME}/.bash_profile
        echo "export PATH='$HOME/.cargo/bin:$PATH'" >> /home/${USERNAME}/.bashrc

        # Copy get files
        cp ${SOURCE_ADMIN_PATH}/get_clusters.sh /home/${USERNAME}/cnpg-hands-on/.
        cp ${SOURCE_ADMIN_PATH}/get_pods.sh /home/${USERNAME}/cnpg-hands-on/.

        # Alias gets
        echo "alias gc='/home/${USERNAME}/cnpg-hands-on/get_clusters.sh'" >> /home/${USERNAME}/.bash_profile
        echo "alias gp='/home/${USERNAME}/cnpg-hands-on/get_pods.sh'" >> /home/${USERNAME}/.bash_profile
        echo "alias gs='/home/${USERNAME}/cnpg-hands-on/get_status.sh'" >> /home/${USERNAME}/.bash_profile
        
        # Kubeconfig k3d
        echo "export KUBECONFIG=/usr/local/share/k8s/k3d-config" > /etc/profile.d/k3d.sh
        sudo chmod +x /etc/profile.d/k3d.sh

    fi

done

echo "Finished creating $TOTAL_USERS users."
