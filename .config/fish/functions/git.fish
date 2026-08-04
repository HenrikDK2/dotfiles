function git --description "Git wrapper that ensures user identity is configured"
    set -l git_name (command git config --global user.name 2>/dev/null)
    set -l git_email (command git config --global user.email 2>/dev/null)

    if test -z "$git_name"; or test -z "$git_email"
        set -l result (yad \
            --title="Git Configuration" \
            --text="Git identity is not fully configured." \
            --width=500 \
            --height=100 \
            --form \
            --field="Username" "$git_name" \
            --field="Email" "$git_email")

        # User cancelled
        test $status -ne 0; and return 1

        set -l values (string split "|" "$result")
        set git_name $values[1]
        set git_email $values[2]

        if test -n "$git_name"
            command git config --global user.name "$git_name"
        end

        if test -n "$git_email"
            command git config --global user.email "$git_email"
        end
    end

    command git $argv
end
