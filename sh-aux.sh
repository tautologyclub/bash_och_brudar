# Auxilliary shell helpers

# Standard stuff
set -euo pipefail

errcho() {
# Usage:  Just like echo xyz, but to stderr
    echo "$*" 1>&2
}

silently() {
# Do whatever, quietly.
# Usage:    silently whatever_cmd
    eval "$*" > /dev/null 2>&1
}

require() {
# Give up early rather than late! This function is so nice it should be a POSIX
# built-in. Usage:
#       require [flags] $app1 $app2 $app3 ...
# Flags:
#   -x|--executable Require that the program is an executable (inside $PATH),
#                   i.e. no shell functions, aliases etc. allowed.
    local checker="command -v"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -x|--executable)
                checker=/usr/bin/which
                shift ;;
            -*) errcho "Unknown flag $1"
                return 1 ;;
             *) break ;;
        esac
    done

    for cmd in "$@" ; do
        silently "eval $checker $cmd" || {
            errcho "$cmd not found (using \"$checker\")"
            return 1
        }
    done
}

file_size() {
#Usage:  file_size $filename
    stat -c %s "$1" 2> /dev/null
}

num_in_range() {
# Test if number is within range (limits included). Omitting one limit will skip
# the check in that direction.
# Usage:    num_in_range $num $min:$max
#           num_in_range $num :$max
#           num_in_range $num $min:
    local num="$1" min max
    test -n "$1" && echo "$2" | silently grep : || {
        errcho "Malformed argument(s)"
        return 1
    }
    min=$(echo "$2" | grep -o "[0-9]*:" | tr -d :) || true
    max=$(echo "$2" | grep -o ":[0-9]*" | tr -d :) || true
    test -z "$min" || [[ $num -gt $((min-1)) ]] || return 1
    test -z "$max" || [[ $num -lt $((max+1)) ]] || return 1
}

file_assert() {
# Assert file(s) exists. Also checks that it's within limits with -s|-S params
# Usage:
#       file_assert [-s MINSIZE|-S MAXSIZE] file1 file2 ...
    local minsize=0 maxsize
    [[ "$#" -eq "0" ]] && {
        errcho No file path provided!
        return 1
    }
    while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--minsize)
            minsize=$2
            shift; shift                  ;;
        -S|--maxsize)
            maxsize=$2
            shift; shift                  ;;
        -*) errcho "Unknown flag $1"
            return 1                      ;;
         *) break                         ;;
    esac
    done

    for file in "$@"; do
        num_in_range "$(file_size $file) $minsize:$maxsize" || {
            errcho "File \"$file\" does not exist or not within size limits"
            return 1
        }
    done
}

with_pwd()
# Eval CMD with DIR as working directory. Usage:
#     with_pwd DIR CMD
{
    trap 'trap EXIT && popd' EXIT
    silently pushd "$PWD"
    cd "$1" && shift && eval "$@"
    silently popd
}

random_string()
# A random "normal" string of length $1 (useful for file names and stuff where
# you might not want spaces or escape characters). Omit argument for a 16 byte
# string.
# Usage:  random_string [$len]
{
    local len
    test -n "$1" && len="$1"|| len=16
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w "$len" | head -n 1
}

random_file() {
# Generate a random file of $1 bytes with name $2
# Usage:  random_file $name $size
    test -n "$1" && test -n "$2" || {
        errcho "Missing arguments"
        return 1
    }
    head -c "$2" < /dev/urandom > "$1"
}

subdirs() {
# List only subdirs
    ls "$@" -d ./*/ 2> /dev/null || echo -n ""
}

pid_alive() {
# For pinging processes -- errors out if $pid isn't alive and does nothing at
# all if it is.
# Usage:  pid_alive $pidlist || errcho "uh-oh"
    kill -s 0 "$@"
}

mountie() {
# Because typing mount commands is really boring
    # Usage:  mountie [$dev]
    local mpoint=/mnt/"$1"
    sudo mkdir -p "$mpoint"

    # Ensure moint point is empty, then mount (this works because ls $dir/*
    # errors out if $dir is empty -- mm, tasty hacks...)
    ls "$mpoint/*" > /dev/null 2>&1 && {
        echo "Mount point $mpoint not empty!"
        return 1
    }
    sudo mount /dev/"$1" "$mpoint" &&                           \
        echo "Mounted /dev/$1 on $mpoint" &&                  \
        export LAST_MOUNTIE_POINT=$mpoint
}

umountie() {
    if [ -z "$LAST_MOUNTIE_POINT" ]; then
        errcho "Ambiguous mount point, sorry"
        return 1
    fi
    echo Unmounting "$LAST_MOUNTIE_POINT..."

    sudo umount "$LAST_MOUNTIE_POINT"
}

ctl() {
# Usage: Faster way to call sudo systemctl
    local PREFIX=sudo
    case "$1" in
        -u)          PREFIX=""
                     shift ;;
        --help)      PREFIX="" ;;
        status)      PREFIX="" ;;
        list-*)      PREFIX="" ;;
        is-*)        PREFIX="" ;;
        show)        PREFIX="" ;;
        help)        PREFIX="" ;;
        cat)         PREFIX="" ;;
        show*)       PREFIX="" ;;
        get-default) PREFIX="" ;;
    esac

    $PREFIX systemctl "$@"
}

girl() {
# Convenience for recursively greping
    grep -IRl "$@" 2>/dev/null
}

ff() {
# Convenience for grepping for file names
    find "$PWD" 2>/dev/null | grep "$@"
}


if [ -n "$HACKY_ALIASES" ]; then
    alias ll='ls -al'
    alias la='ls -A'
    alias ls='ls --color -h --group-directories-first'

    alias sharedir='python2 -c "import SimpleHTTPServer;SimpleHTTPServer.test()"'
    alias xclip='xclip -selection clipboard'

    alias ..='cd ..'
    alias ...='cd ../..'
    alias ....='cd ../../..'
    alias .....='cd ../../../..'

    require gio && {
        alias rm='gio trash'
        alias seetrash='ll ~/.local/share/Trash/files/'
        alias emptytrash='sudo /bin/rm -rf ~/.local/share/Trash/*'
    }
fi
