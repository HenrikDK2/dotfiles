# Source shared shell config
source ~/.my_scripts/shared_shell_config.sh

if status is-interactive
    if type -q fisher;
        if not test -e ~/.config/fish/functions/nvm.fish; 
            fisher install jorgebucaran/nvm.fish
        end
    
         # Install nvm
        if not test -e ~/.config/fish/functions/_autopair_tab.fish; 
            fisher install fisher install jorgebucaran/autopair.fish
        end

        clear
    end
   
    # On login
    if test -z "$DISPLAY"; and test (tty) = /dev/tty1
        sway
    end
end
