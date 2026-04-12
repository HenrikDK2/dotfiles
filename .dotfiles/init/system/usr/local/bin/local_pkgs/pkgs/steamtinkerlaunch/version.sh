# Github

curl -sf "https://api.github.com/repos/sonic2kk/steamtinkerlaunch/releases/latest" \
  | jq -r '.tag_name' \
  | sed 's/^v//'
