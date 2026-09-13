#!/bin/bash

file="$ZED_FILE"
name=$(basename "${file%.*}")
ext="${file##*.}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "[running $(basename "$file")]"

case "$ext" in
    c)          gcc "$file" -o "$tmp/$name" && "$tmp/$name" ;;
    cpp|cc|cxx) g++ "$file" -o "$tmp/$name" && "$tmp/$name" ;;
    rs)         rustc "$file" -o "$tmp/$name" && "$tmp/$name" ;;
    pas)        fpc "$file" -o"$tmp/$name" >/dev/null 2>&1 && "$tmp/$name" ;;

    py)         python3 "$file" ;;
    js|mjs|cjs) node "$file" ;;
    ts)         command -v tsx >/dev/null && tsx "$file" || ts-node "$file" ;;
    rb)         ruby "$file" ;;
    php)        php "$file" ;;
    pl)         perl "$file" ;;
    swift)      swift "$file" ;;
    dart)       dart run "$file" ;;
    lua)        lua "$file" ;;
    r|R)        Rscript "$file" ;;
    sh)         bash "$file" ;;
    bash)       bash "$file" ;;
    zsh)        zsh "$file" ;;
    hs)         runghc "$file" ;;
    jl)         julia "$file" ;;
    ex|exs)     elixir "$file" ;;
    erl)        escript "$file" ;;
    scala)      scala "$file" ;;

    java)
        javac -d "$tmp" "$file" && java -cp "$tmp" "$name"
        ;;

    kt)
        kotlinc "$file" -include-runtime -d "$tmp/$name.jar" &&
            java -jar "$tmp/$name.jar"
        ;;

    kts)        kotlinc -script "$file" ;;
    cs)         dotnet script "$file" ;;
    *)          echo "No runner for .$ext"; exit 1 ;;
esac
