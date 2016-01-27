#Nix Zsh Utility Functions
A  collection of zsh functions to make using nix easier

## Installation
to install with antigen, add the following somewhere in your zshrc

    antigen bundle https:github.com/Adjective-Object/nix-zsh-utility.git

## Dependencies
 - pygmentize
 - jq
 - sed
 - python3


## Functions
### Nix Functions

 - `whichlink [program]` :  
    like `which`, but follows symlinks.
    useful for finding the  location of a program in the nix-store
 
 - `readtrail [path]` : reads all the nodes on a chain of symlinks

 - `whichtrail [program]` :  like `whichlink` but uses `readtrail` to find
    the original location

 - `nix-lookup [attribute-path]` :
    takes an attribute path (e.g. nixos.haskellPackages.text) and outputs 
    the corresponding location in the store (which may or may not exist)

 - `nix-show-size [path]` : find the total size of a given nix GC root path

 - `nix-show-all-sizes [path]` : show the sizes of all elements in a 
    given nix GC root path

 - `nix-env [args..]` : performs `nix-env [args..]` and `reshash`

 - `list-haskell-packages` : lists all installed packages under
    `nixos.pkgs.haskellngPackagesWithProf` by their corresponding pages 
    on hackage

 - `nixpaste [file]` : 
    Puts a file up on nixpaste and returns the url. 
    If run with no arguments, pipes stdin to nixpaste and retuns the 
    corresponding url

 - `audit-nix-packages` : 
    generates and HTML report on the nix packages under PATH
    PATH defaults to `$HOME/.nixpkgs/packages` and should not have 
    a trailing path.

 - `remove-store-paths [paths..]` :
    Removes the leading nix/store/.. from packagenames
    e.g.

        $ echo "/nix/store/1rvydf2fx07ang4q9s2ikd0w2l4npaw0-rfkill-0.5/bin/rfkill" | remove-store-paths
        nix://rfkill-0.5/bin/rfkill


### Composable Parts
 - `between` / `surround` :
    Prepend / appends text to a pipe stream

 - `shell-escape` : 
    Escape a UTF8 string to ascii for safe use in `sh` in a pipe stream

 - `percent-encode [string]` :
    Encodes a string for use in a url

 - `percent-decode [string]` :
    Decodes a url encoded string to make it human readable

 -  invert-case [strings..]` :
    inverts the case of the arguments

 - `force-success [command]` :
    Perform some command and exit without error, ignoring the exit
    code of the command
    


### Convenience
 - `gcam [message]` : 
    Commit and add all files in a directory with a given message

 - `fast-reset` / `fsr` : quickly resets a terminal buffer

 - `tree-json` : prints the directory structure of a path as json

 - `fix-history [command]` :
    sanatizes a corrupted zsh history



    





