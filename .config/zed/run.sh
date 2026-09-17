#!/bin/bash

file="$ZED_FILE"
name="${file##*/}"
name="${name%.*}"
ext="${file##*.}"
dir="${file%/*}"
[ "$dir" = "$file" ] && dir=.
base="${file##*/}"
tmp=$(mktemp -d)

trap 'rm -rf "$tmp"' EXIT

echo "[running $base]"

run_local() {
    cd "$dir" || exit 1
    "$@"
}

run_meson() {
    local build_dir="$dir/build"
    local executable

    if ! meson setup --reconfigure "$build_dir" >/dev/null 2>&1; then
        echo "[meson] configuring..."
        rm -rf "$build_dir"
        meson setup "$build_dir" || exit 1
    fi

    echo "[meson] building..."
    meson compile -C "$build_dir" || exit 1

    executable=$(meson introspect --targets "$build_dir" |
        jq -r '[.[] | select(.type == "executable") | .filename[0]] | first')

    if [ -z "$executable" ] || [ ! -x "$executable" ]; then
        echo "Error: could not find executable"
        exit 1
    fi

    echo "[meson] running $executable"
    "$executable"
}

run_compiled() {
    local compiler="$1"
    local pattern="$2"
    local output="$tmp/$name"
    local files=()

    if [ -f "$dir/meson.build" ]; then
        run_meson
        return
    fi

    while IFS= read -r -d '' file; do
        files+=("$file")
    done < <(find "$dir" -type f \( $pattern \) -print0)

    "$compiler" "${files[@]}" -o "$output" && "$output"
}

case "$ext" in
    c)
        run_compiled gcc '-name *.c'
        ;;

    cpp|cc|cxx)
        run_compiled g++ '-name *.cpp -o -name *.cc -o -name *.cxx'
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
            run_compiled swiftc '-name *.swift'
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
        run_compiled javac '-name *.java'
        ;;

    kt)
        local_jar="$tmp/$name.jar"
        files=()
        while IFS= read -r -d '' file; do
            files+=("$file")
        done < <(find "$dir" -type f -name '*.kt' -print0)
        kotlinc "${files[@]}" -include-runtime -d "$local_jar" &&
            java -jar "$local_jar"
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
