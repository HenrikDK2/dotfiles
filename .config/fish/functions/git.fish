function git --description "Git wrapper that ensures user identity is configured"
    set -l git_name (command git config --global user.name 2>/dev/null)
    set -l git_email (command git config --global user.email 2>/dev/null)

    if test -z "$git_name"; or test -z "$git_email"
        set_color yellow
        echo "Git identity is not fully configured."
        set_color normal

        if test -z "$git_name"
            read -P "  Username: " git_name
            if test -n "$git_name"
                command git config --global user.name "$git_name"
            end
        end

        if test -z "$git_email"
            read -P "  Email: " git_email
            if test -n "$git_email"
                command git config --global user.email "$git_email"
            end
        end

        set_color green
        echo "Git identity set: $git_name <$git_email>"
        set_color normal
        echo
    end

    command git $argv
end
