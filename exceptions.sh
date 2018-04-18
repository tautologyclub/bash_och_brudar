# EXTREME META-SCRIPTING

except:(){
    local res=$?
    set -e
    [[ "$res" = "0" ]] || eval $@
}

try:(){
    set +e
    eval $@
}

# Example usages:

# try:\
#     ls mydir
# except:\
#     mkdir mydir
