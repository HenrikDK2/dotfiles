# Source shared shell config
source ~/.my_scripts/shared_shell_config.sh

if status is-interactive
    # Check if fisher is installed
    if type -q fisher;
        # Install nvm
        if not test -e ~/.config/fish/conf.d/nvm.fish; 
            fisher install jorgebucaran/nvm.fish
        end
    
        # Install autopair
        if not test -e ~/.config/fish/conf.d/autopair.fish; 
            fisher install jorgebucaran/autopair.fish
        end
    end

    # On login
    if test -z "$DISPLAY"; and test (tty) = /dev/tty1
        sway
    end

    clear
end
