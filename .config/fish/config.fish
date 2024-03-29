# Source shared shell config
source ~/.my_scripts/shared_shell_config.sh

# Build directly from ram, if there is 24GB available.
set total_free_mem_bytes (free -b | awk '/^Mem/ { mem = $4 } /^Swap/ { swap = $4 } END { print mem + swap }')
set min_required_mem_bytes (math "24 * 1024 * 1024 * 1024") # 24GB

if test $total_free_mem_bytes -ge $min_required_mem_bytes
    set -x BUILDDIR /tmp/makepkg
else 
    set -e BUILDDIR
end



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
