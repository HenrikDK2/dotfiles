#!/bin/bash

file="$ZED_FILE"
name=$(basename "${file%.*}")
ext="${file##*.}"
dir=$(dirname "$file")
base=$(basename "$file")
tmp=$(mktemp -d)

trap 'rm -rf "$tmp"' EXIT

echo "[running $base]"

run_local() {
    cd "$dir" || exit 1
    "$@"
}

run_meson() {
    local build_dir="$dir/build"
    local executable="$build_dir/FeatherBar"

    if [ ! -d "$build_dir" ]; then
        echo "[meson] configuring..."
        meson setup "$build_dir" || exit 1
    fi

    echo "[meson] building..."
    meson compile -C "$build_dir" || exit 1

    if [ ! -x "$executable" ]; then
        echo "Error: could not find executable: $executable"
        exit 1
    fi

    echo "[meson] running $executable"
    "$executable"
}

case "$ext" in
    c)
        if [ -f "$dir/meson.build" ]; then
            run_meson
        else
            mapfile -t files < <(
                find "$dir" -type f -name '*.c' -print
            )
            gcc "${files[@]}" -o "$tmp/$name" && "$tmp/$name"
        fi
        ;;

    cpp|cc|cxx)
        if [ -f "$dir/meson.build" ]; then
            run_meson
        else
            mapfile -t files < <(
                find "$dir" -type f \
                    \( -name '*.cpp' -o -name '*.cc' -o -name '*.cxx' \) \
                    -print
            )
            g++ "${files[@]}" -o "$tmp/$name" && "$tmp/$name"
        fi
        ;;

    rs)
        if [ -f "$dir/Cargo.toml" ]; then
            run_local cargo run --manifest-path "$dir/Cargo.toml"
        else
            rustc "$file" -o "$tmp/$name" && "$tmp/$name"
        fi
        ;;

    pas)
        fpc -Fu"$dir" -FE"$tmp" -FU"$tmp" "$file" >/dev/null 2>&1 &&
            "$tmp/$name"
        ;;

    py)
        PYTHONPATH="$dir${PYTHONPATH:+:$PYTHONPATH}" run_local python3 "$base"
        ;;

    js|mjs|cjs)
        run_local node "$base"
        ;;

    ts)
        if command -v tsx >/dev/null 2>&1; then
            run_local tsx "$base"
        elif command -v ts-node >/dev/null 2>&1; then
            run_local ts-node "$base"
        else
            echo "Error: neither tsx nor ts-node is installed"
            exit 1
        fi
        ;;

    rb)
        run_local ruby "$base"
        ;;

    php)
        run_local php "$base"
        ;;

    pl)
        PERL5LIB="$dir${PERL5LIB:+:$PERL5LIB}" run_local perl "$base"
        ;;

    swift)
        if [ -f "$dir/Package.swift" ]; then
            run_local swift run
        else
            mapfile -t files < <(
                find "$dir" -type f -name '*.swift' -print
            )
            swiftc "${files[@]}" -o "$tmp/$name" && "$tmp/$name"
        fi
        ;;

    dart)
        run_local dart run "$base"
        ;;

    lua)
        LUA_PATH="$dir/?.lua;$dir/?/init.lua;$dir/?/?.lua;;" \
            run_local lua "$base"
        ;;

    r|R)
        run_local Rscript "$base"
        ;;

    sh|bash)
        run_local bash "$base"
        ;;

    zsh)
        run_local zsh "$base"
        ;;

    hs)
        run_local runghc "$base"
        ;;

    jl)
        run_local julia "$base"
        ;;

    ex|exs)
        if [ -f "$dir/mix.exs" ]; then
            run_local mix run "$base"
        else
            run_local elixir "$base"
        fi
        ;;

    erl)
        run_local escript "$base"
        ;;

    scala)
        run_local scala "$base"
        ;;

    java)
        mapfile -t files < <(
            find "$dir" -type f -name '*.java' -print
        )
        javac -d "$tmp" "${files[@]}" &&
            java -cp "$tmp" "$name"
        ;;

    kt)
        mapfile -t files < <(
            find "$dir" -type f -name '*.kt' -print
        )
        kotlinc "${files[@]}" \
            -include-runtime \
            -d "$tmp/$name.jar" &&
            java -jar "$tmp/$name.jar"
        ;;

    kts)
        run_local kotlinc -script "$base"
        ;;

    cs)
        if compgen -G "$dir/*.csproj" >/dev/null; then
            run_local dotnet run
        else
            run_local dotnet script "$base"
        fi
        ;;

    *)
        echo "No runner for .$ext"
        exit 1
        ;;
esac
