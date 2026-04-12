# Github

curl -sf "https://api.github.com/repos/pdewacht/brlaser/releases/latest" \
  | jq -r '.tag_name' \
  | sed 's/^v//'
