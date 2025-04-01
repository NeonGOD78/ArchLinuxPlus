set -e

# Function to select and install the default editor
select_editor() {
    echo "Select your preferred text editor:"
    options=("nano" "vim" "neovim" "emacs")
    select editor in "${options[@]}"; do
        if [[ -n "$editor" ]]; then
            echo "Installing $editor..."
            if ! command -v $editor &> /dev/null; then
                pacman -S --noconfirm "$editor"
            fi
            echo "Setting $editor as default editor..."
            sed -i "/^EDITOR=/d" /etc/environment
            sed -i "/^VISUAL=/d" /etc/environment
            echo "EDITOR=$editor" >> /etc/environment
            echo "VISUAL=$editor" >> /etc/environment
            export EDITOR=$editor
            export VISUAL=$editor
            break
        else
            echo "Invalid selection, please try again."
        fi
    done
}

# Call the function
select_editor
