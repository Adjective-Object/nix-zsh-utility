#!/usr/bin/env zsh
# nix/nixos helper functions for zsh
# Written by Remy Goldschmidt (github.com/taktoa)
# Packaged with permission by Maxwell Huang-Hobbs

# ZSH-specific definitions
if [[ -z "${BASH}" ]]; then
    # Fix the "help" command
    unalias run-help &>/dev/null || true
    autoload run-help
    alias help='run-help'
    setopt interactivecomments
fi

fast-reset () {
    echo -e '\0033\0143'
}

alias fsr="fast-reset"

gcam () {
    usage() {
        echo "Usage: gcam <commit-message>\n"
        echo "Commit and add all files in repository; "
        echo "i.e.: git commit -am '<commit-message>'"
    }
    if (( $# != 1 )) || [[ -z "${1}" ]]; then usage; return -1; fi
    git commit -am "${1}"
}

maketemp () {
    usage() {
        echo "Usage: maketemp <template>\n"
        echo " Makes a temp file with the given temple (e.g.: tmp.XXXX)"
    }
    if (( $# != 1 )); then usage; return -1; fi
    mktemp -p /tmp $1
}

between () {
    usage () {
        echo "Usage: between <prepended> <appended>"
        echo ""
        echo "Prepend / append text to a pipe stream"
    }
    if (( $# != 2 )); then usage; return -1; fi
    cat <(echo -ne "$1") - <(echo -ne "$2")
}

alias surround='between'

nix-show-size () {
    usage () {
        echo "Usage: nix-show-size <path>\n"
        echo "Find the total size of the given Nix GC root path."
    }
    if (( $# != 1 )); then usage; return -1; fi

    local TMPFILE
    TMPFILE=$(maketemp show-size.XXXX)
    nix-store --query --tree "$1" \
        | sed 's:^[-+| ]*/:/:g'   \
        | awk '{print $1}'        \
        | sort | uniq > $TMPFILE
    sed -i 's:^:nix-store --query --size :g' $TMPFILE
    awk '{s+=$1} END {printf "%.0f", s}' $TMPFILE
    local SIZE_BYTES
    SIZE_BYTES=$(awk '{s+=$1} END {printf "%.0f", s}' $TMPFILE)
    rm $TMPFILE
    echo "Size in bytes: $SIZE_BYTES"
}

nix-show-all-sizes () {
    usage() {
        echo "Usage: nix-show-all-sizes <path>\n"
        echo "Find the total size of the given Nix GC root path."
    }
    if (( $# != 1 )); then usage; return -1; fi
    local NIX_DIR
    NIX_DIR="/nix/var/nix/profiles/per-user/$USER/profile-*-link"
    for x in "$NIX_DIR"; do
        echo -n "$x $(nix-show-size $x)"
    done
}

nix-env () {
    /usr/bin/env nix-env "$@"
    rehash
}

readtrail () {
    usage () {
        echo "Usage: readtrail <path>\n"
        echo "Outputs all the nodes along a chain of symbolic links"
    }
    if (( $# != 1 )) || [[ ! -L $1 ]]; then usage; return -1; fi
    local PATH=$1
    while [[ -L $PATH ]] && [[ "$PATH" != "$(readlink $PATH)" ]]; do
        echo $PATH
        PATH="$(readlink $PATH)"
    done
    echo $PATH
}

whichlink () {
    usage () {
        echo "Usage: whichlink <command>\n"
        echo "Runs readlink -f on the output of which (e.g.: pancakes)"
    }
    if (( $# != 1 )); then usage; return -1; fi
    readlink -f $(which $1)
}

whichtrail () {
    usage() {
    echo "Usage: whichtrail <command>\n"
    echo "Runs readtrail on the output of which"
}
    if (( $# != 1 )); then usage; return -1; fi
    readtrail $(which $1)
}

nix-lookup () {
    usage() {
        echo "Usage: nix-lookup <expression-path-under-pkgs>"
        echo "Shows the directory for the given attribute path."
    }
    if [ $# -ne 1 ]; then usage; return -1; fi
    EXPR="\"\${(import <nixpkgs> {}).pkgs.$1}\""
    nix-instantiate --eval -E "${EXPR}" | sed 's:"::g'
    return 0
}

list-haskell-packages () {
    # lists haskell packages installed through nix
    # by their corresponding hackage links
    local PREFIX="nixos.pkgs.haskellngPackagesWithProf"
    local TEMPFILE="$(mktemp)"
    nix-env -qaPA "$PREFIX" \
        | sed "s: [ ]*: :g; s:$PREFIX\.::g" > $TEMPFILE
    local ATTRTEMP HACKTEMP NAMETEMP
    ATTRTEMP="$(mktemp)"
    HACKTEMP="$(mktemp)"
    NAMETEMP="$(mktemp)"
    cut -d ' ' -f 1 $TEMPFILE > $ATTRTEMP
    cut -d ' ' -f 2 $TEMPFILE > $NAMETEMP
    rm $TEMPFILE
    cp $ATTRTEMP $HACKTEMP
    sed -i 's|^|https://hackage.haskell.org/package/|g' $HACKTEMP
    paste -d ' ' $ATTRTEMP $HACKTEMP $NAMETEMP | column -t | sort | less -S
    rm $ATTRTEMP $HACKTEMP $NAMETEMP
}

view-core () {
    local FILE="$1"
    local TYPE="unknown"
    function view-check () {
        if echo "$FILE" | grep ".*\.$1" &>/dev/null; then TYPE="$2"; fi
    }
    view-check '1\.gz' "manpage"
    view-check 'info'  "info"
    view-check 'xml'   "xml"
    view-check 'json'  "json"
    unset view-check
    if [[ "$TYPE" = "unknown" ]]; then
        case "$(pygmentize -N $FILE)" in
            text)     true;;
            resource) true;;
            *)        TYPE="pygmentize";;
        esac
    fi
    local PYGMENTIZE="-O style=emacs"
    local VIEWOPTS="--colors --vertical-compact"
    case $TYPE in
        manpage)    man $FILE;;
        info)       info -f $FILE;;
        json)       cat $FILE | jq '.' | pygmentize $PYGMENTIZE -s -l json;;
        xml)        view-xml $VIEWOPTS $FILE;;
        pygmentize) pygmentize $PYGMENTIZE $FILE;;
        *)          echo "Unknown file type";;
    esac
}

view () {
    usage() {
        echo "Usage: view <file>"
        echo "displays a file in a less buffer with pygmentize"
    }
    if (( $# != 1 ));   then usage;  return -1; fi
 
    view-core "$@" | less
}

shell-escape () {
    # takes a string in a pipeline and escapes the contents
    # so they are safe for using in `sh`
    local SED_FLAGS
    local UCONV_FLAGS
    local PARALLEL_FLAGS
    if [ "${1}" = "-0" ]; then
        SED_FLAGS="-z"
        UCONV_FLAGS=""
        PARALLEL_FLAGS="-0"
    fi
    sed ${SED_FLAGS} 's/^/"/g;s/$/"/g' \
        | uconv ${UCONV_FLAGS} -f utf-8 -t ascii --callback escape-c \
        | parallel ${PARALLEL_FLAGS} eval echo -E \"{}\" \;
}

run-nixpaste () {
    curl -F 'text=<-' http://nixpaste.lbr.uno
}

nixpaste () {
    if (( $# == 0 )); then
        run-nixpaste
    elif (( $# == 1 )) && [[ -f "$1" ]]; then
        run-nixpaste < "$1"
    else
        echo "Usage: nixpaste [FILE]"
        echo "If FILE is not provided, input will be read from stdin."
    fi
}

run-json-strip-trailing-commas () {
    cat -                                   \
        | sed 's|\t|\\u0009|g'              \
        | tr '\n' '\t'                      \
        | sed 's|,\([[:space:]]*\)\]|\1]|g' \
        | sed 's|,\([[:space:]]*\)\}|\1}|g' \
        | tr '\t' '\n'                      \
        | sed 's|TAB|\t|g'
}

json-strip-trailing-commas () {
    if (( $# == 0 )); then
        run-json-strip-trailing-commas
    elif (( $# == 1 )) && [[ -f "$1" ]]; then
        cat "$1" | run-json-strip-trailing-commas
    else
        echo "Usage: json-strip-trailing-commas [FILE]"
        echo "Removes trailing commas in JSON arrays and objects."
        echo "If FILE is not provided, input will be read from stdin."
    fi
}

tree-json () {
    tree -J "$@" | json-strip-trailing-commas
}

audit-nix-packages () {
    usage () {
        echo "Usage: audit-nix-packages [PATH]"
        echo "Generates an HTML report on the Nix packages under PATH."
        echo "PATH defaults to '\$HOME/.nixpkgs/packages'"
        echo "PATH should not have a trailing slash."
    }

    if (( $# == 0 )); then
        NIX_ROOT="${HOME}/.nixpkgs/packages" # No trailing /
    elif (( $# == 1 )) && [[ -d "${1}" ]]; then
        NIX_ROOT="${1}"
    else
        usage
    fi

    URL_ROOT="file://${NIX_ROOT}"

    tree -H "${URL_ROOT}" --noreport --prune -P 'default[.]nix' "${NIX_ROOT}" \
        | grep -v 'default.nix'
    
}

percent-encode () {
    usage () {
        echo "Usage: percent-encode <string>"
        echo "Encodes a string for use in a url"
    }
    if (( $# != 1 ));   then usage;  return -1; fi

    python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "${1}"
}

percent-decode () {
    usage () {
        echo "Usage: percent-decode <string>"
        echo "Decodes a url encoded string for use in a url"
    }
    if (( $# != 1 ));   then usage;  return -1; fi


    python3 -c "import urllib.parse, sys; print(urllib.parse.unquote(sys.argv[1]))" "${1}"
}

invert-case () {
    tr -s '[a-z][A-Z]' '[A-Z][a-z]';
}

remove-store-paths () {
    sed -r 's|/nix/store/[[:alnum:]]{32}-|nix://|g';
}

read-custom-zsh () {
    echo "READ ~/.custom.zsh PLEASE" >&1 >&2
}

# A reminder to use the tools in here.
alias truss='read-custom-zsh'
alias dtruss='read-custom-zsh'
alias dtrace='read-custom-zsh'

strace-open () {
    strace -e trace=open "${@}"
}

json-string-array-print () {
    jq -r 'map(. + "\n") | add'
}

resolve-paths () {
    cat | parallel 'exists () { [ -e "$1" ] && readlink -f "$1"; }; exists {};'
}

force-success () {
    eval "${1} &>/dev/null || true"
}

fix-history () {
    sed -i ':a; N; $!ba; s/\\\n\n:/\n:/g;' ~/.zsh_history
}

## process-strace () {
##     STRACE_OPEN__ACCESS_MODES=(
##         'O_RDONLY'
##         'O_WRONLY'
##         'O_RDWR'
##         'O_READ'
##         'O_WRITE'
##         'O_EXEC'
##         'O_ACCMODE'
##     )
##  
##     STRACE_OPEN__OPEN_TIME_FLAGS=(
##         'O_CREAT'
##         'O_EXCL'
##         'O_NONBLOCK'
##         'O_NOCTTY'
##         'O_IGNORE_CTTY'
##         'O_NOLINK'
##         'O_NOTRANS'
##         'O_TRUNC'
##         'O_SHLOCK'
##         'O_EXLOCK'
##     )
##  
##     STRACE_OPEN__OPERATING_MODES=(
##         'O_APPEND'
##         'O_NONBLOCK'
##         'O_NDELAY'
##         'O_ASYNC'
##         'O_FSYNC'
##         'O_SYNC'
##         'O_NOATIME'
##     )
##  
##     strace-open-modes () {
##         echo -n "${STRACE_OPEN__ACCESS_MODES} "
##         echo -n "${STRACE_OPEN__OPEN_TIME_FLAGS} "
##         echo -n "${STRACE_OPEN__OPERATING_MODES}"
##     }
##  
##     STRACE_OPEN_PATH_RX='"\([^"]\+\)"'
##     STRACE_OPEN_MODE_RX="\($(strace-open-modes | sed 's: :\\|:g')\)"
##  
##     STRACE_OPEN_RX="open(${STRACE_OPEN_PATH_RX}, ${STRACE_OPEN_MODE_RX})"
##  
##     cat strace.txt \
##         | sed -n "/^[0-9]\+[[:space:]]\+${STRACE_OPEN_RX}.*$/p; s|^[0-9]\+[[:space:]]\+${STRACE_OPEN_RX}.*$|lol|g"
## #        | grep "^[0-9]\+[[:space:]]\+${STRACE_OPEN_RX}.*$" \
## #        | sed "s|^[0-9]\+[[:space:]]\+${STRACE_OPEN_RX}.*$|lol|g"
##     
##     ACCESS_MODE_RX='O_\(\)[A-Z]\+'
##     
## #    cat strace.txt \
## #        | sed 's|^[0-9]* open(${PATH_REGEX}, [A-Z_|]*)[ ]*= \([-0-9]*\)[ ]*.*$|\1\t\2|g' \
## #        | sed -r 's|([^\t]+)\t([^\t]+)|{ "path": "\1", "value": "\2" },|g' \
## #        | surround '[' 'null ]'
##     
## #        | jq 'map(objects | select(.value != "-1") | .path)' \
## #        | json-string-array-print \
## #        | xargs -n 1 basename \
## #        | sort -u \
## #        | egrep -v '^.*[.](nix|pm|drv|patch|diff|sh)$' \
## #        | grep -v '^lib'
## }
