# Auxilliary shell helpers
HACKY_ALIASES=true      # Warning, unset this is you're not into hacky hacks

PANIC_MSG_PREFIX="*** Error: "
FILE_ASSERT_MAXSIZE_DFLT="$(echo 2^32 | bc)"

errcho()
# Usage:  Just like echo xyz, but to stderr
{
    echo "$*" 1>&2
}

panic()
# Panics and exits. Warning: don't use this in scripts you intend to source :)
# Usage:  panic <msg>
{
    echo -n "$PANIC_MSG_PREFIX" 1>&2
    errcho "$@"
    exit 1
}

require()
# Give up early rather than late! This function is so nice it should be a POSIX
# built-in. Usage:
#       require [-s|-x|-p] $app1 $app2 $app3 ...
#
# Flags:
#       -s|--sudo       Require that the program is in sudo:s $PATH.
#                       Note:  Pretty damn unsafe...
#       -x|--executable Require that the program is an executable, i.e. no shell
#                       functions, aliases etc. allowed.
#       -p|--path       Echo the required path(s) to stdout.
{
    local checker_prefix=""
    local checker="command -v"          # Default checker
    local return_cmdpath=/dev/null      # Default to not returning path
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--path)
                return_cmdpath=/dev/stdout
                shift ;;
            -x|--executable)
                checker=/usr/bin/which
                shift ;;
            -s|--sudo)
                checker_prefix=sudo
                checker=/usr/bin/which
                shift ;;
            -*) errcho "Unknown flag $1"
                return 1 ;;
             *) break ;;
        esac
    done

    for cmd in "$@" ; do
        eval $checker_prefix $checker "$cmd" > $return_cmdpath 2>/dev/null || {
            errcho "$cmd not found (using $checker_prefix $checker)"
            return 1
        }
    done
}

var_assert()
# Assert variable is set. Accepts list of variables, i.e. 'var_assert foo bar
# baz' checks if $foo, $bar and $baz are all set. With -n|--non-empty flag
# provided, also asserts the variables are non-nil.
#
# -- NOTE: kind of unsafe due to eval so only ever call this with actual string
#          literals!
{
    while [ "$#" -gt 0 ]; do
        case $1 in
            -n|--non-empty)  # require that variable be non-empty string
                local check_non_empty=1
                shift
                ;;
            -*) errcho "Unknown flag $1"
                return 1
                ;;
             *) break
                ;;
            esac
        done

    for var_name in "$@"; do
        if [ -n "$check_non_empty" ]; then
            eval var_val="\$$var_name" && test -n "$var_val"
        else
            declare -p "$var_name" >/dev/null 2>&1
        fi
    done
}

file_size()
#Usage:  file_size $filename
{
    stat -c %s "$1"
}

FILE_ASSERT_MAXSIZE_DFLT="$(echo 2^32 | bc)"
file_assert()
# Assert file(s) exists.
# Usage:
#       file_assert [-s MINSIZE|-S MAXSIZE] file1 file2 ...
{
    local actual_filesize minsize=0 maxsize=$FILE_ASSERT_MAXSIZE_DFLT
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--minsize) minsize=$2
                          shift; shift                  ;;
            -S|--maxsize) maxsize=$2
                          shift; shift                  ;;
                      -*) errcho "Unknown flag $key"
                          return 1                      ;;
                       *) break                         ;;
        esac
    done
    [[ "$#" -eq "0" ]] && errcho No file path provided! && return 1

    for file in "$@"; do
        test -e "$file" && {
            actual_filesize=$(file_size "$file")
            if [ "$actual_filesize" -lt "$minsize" ]; then
                errcho "'$file subceeds' min. size ($actual_filesize < $minsize)"; return 1
            elif [ "$actual_filesize" -gt "$maxsize" ]; then
                errcho "'$file' exceeds max. size ($actual_filesize > $maxsize)"; return 1
            fi
        } || {
            errcho "File $file does not exist!"
            return 1
        }
    done
}

with_pwd()
# Eval CMD with DIR as working directory. Usage:
#     with_pwd DIR CMD
{
    local prev_dir=$PWD
    cd "$1" && shift && eval "$@" || local ret=$?
    cd "$prev_dir"
    return $ret
}

random_string()
# A random "normal" string of length $1 (useful for file names and stuff where
# you might not want spaces or escape characters)
# Usage:  random_string $len
{
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w "$1" | head -n 1
}

random_file()
# Generate a random file of $1 bytes with name $2
# Usage:  random_file $name $size
{
    head -c "$2" < /dev/urandom > "$1"
}

cpwd()
# If you don't have a terminal that lets you navigate through stdout, this one's
# golden. But also, check out 'termite'. Best solution is to put
#
#     alias xclip='xclip -selection clipboard'
#
# in your .bashrc.
{
    require xclip
    pwd | xclip -selection clipboard
}

hex_to_dec()
# Usage:  hex_to_dec [0x]DEADBEEF
{
    printf "%d" "$1"
}

subdirs()
# List only subdirs
{
    ls "$@" -d */ || echo ""
}

pid_alive()
# For pinging processes -- errors out if $pid isn't alive and does nothing at
# all if it is.
# Usage:  pid_alive $pidlist || errcho "uh-oh"
{
    kill -s 0 "$@"
}

mountie()
# Because typing mount commands is really boring
{
    # Usage:  mountie [$dev]
    require sudo

    mpoint=/mnt/"$1"
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

umountie(){
    require sudo
    require mountie

    if [ -z "$LAST_MOUNTIE_POINT" ]; then
        errcho "Ambiguous mount point, sorry"
        return 1
    fi
    echo Unmounting "$LAST_MOUNTIE_POINT..."

    sudo umount "$LAST_MOUNTIE_POINT"
}

contains()
# Convenience for recursively greping
{
    grep -Rl "$@" 2>/dev/null
}


ff()
# Convenience for grepping for file names
{
    find 2>/dev/null | grep "$@"
    # echo hej
}


if [ -n $HACKY_ALIASES ]; then
    alias ll='ls -al'
    alias la='ls -A'
    alias ls='ls --color -h --group-directories-first'

    alias sharedir='python2 -c "import SimpleHTTPServer;SimpleHTTPServer.test()"'
    alias xclip='xclip -selection clipboard'

    alias ..='cd ..'
    alias ...='cd ../..'
    alias ....='cd ../../..'
    alias .....='cd ../../../..'

    require gio
    alias rm='gio trash'
    alias seetrash='ll ~/.local/share/Trash/files/'
    alias emptytrash='sudo /bin/rm -rf ~/.local/share/Trash/*'
fi
