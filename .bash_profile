
#------------------------------------------------------------
#   Command prompt
#------------------------------------------------------------
#export PS1='\u@\H:\w$'             #loggedin@machinename:~/
export PS1="\`pwd\` \$ "            #fullpath current folder $

#------------------------------------------------------------
#   Set Paths
#------------------------------------------------------------
export PATH="$PATH:/usr/local/bin/"
export PATH="/usr/local/git/bin:/sw/bin/:/usr/local/bin:/usr/local/:/usr/local/sbin:/usr/local/mysql/bin:$PATH"

#   Set Default Editor (change 'Nano' to the editor of your choice)
#   ----------------------------------------------------------/Users/jonasdeibe/.bash_profile
export EDITOR=/usr/bin/nano

#   Set default blocksize for ls, df, du
#   from this: http://hints.macworld.com/comment.php?mode=view&cid=24491
#   ------------------------------------------------------------
export BLOCKSIZE=1k

#   Add color to terminal
#   (this is all commented out as I use Mac Terminal Profiles)
#   from http://osxdaily.com/2012/02/21/add-color-to-the-terminal-in-mac-os-x/
#   ------------------------------------------------------------
export CLICOLOR=1
export LSCOLORS=ExFxBxDxCxegedabagacad

# Fix for Python ValueError: unknown locale: UTF-8
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

#------------------------------------------------------------
#   MAKE TERMINAL BETTER
#------------------------------------------------------------
alias cp='cp -iv'                           # Preferred 'cp' implementation
alias mv='mv -iv'                           # Preferred 'mv' implementation
alias mkdir='mkdir -pv'                     # Preferred 'mkdir' implementation
#alias ll='ls -alFG'
alias ll='ls -FGlAhp'                       # Preferred 'ls' implementation
alias ls='ls -F'                            # -F appends a character revealing the nature of a file, for example, * for an executable, or / for a directory. Regular files have no suffix.
alias less='less -FSRXc'                    # Preferred 'less' implementation
cd() { builtin cd "$@"; ll; }               # Always list directory contents upon 'cd'
alias cd..='cd ../'                         # Go back 1 directory level (for fast typers)
alias ..='cd ../'                           # Go back 1 directory level
alias ...='cd ../../'                       # Go back 2 directory levels
alias .3='cd ../../../'                     # Go back 3 directory levels
alias .4='cd ../../../../'                  # Go back 4 directory levels
alias .5='cd ../../../../../'               # Go back 5 directory levels
alias .6='cd ../../../../../../'            # Go back 6 directory levels
alias edit='code'                           # edit:         Opens any file in Visual studio code
alias f='open -a Finder ./'                 # f:            Opens current directory in MacOS Finder
alias ~="cd ~"                              # ~:            Go Home
alias c='clear'                             # c:            Clear terminal display
alias which='type -all'                     # which:        Find executables
alias path='echo -e ${PATH//:/\\n}'         # path:         Echo all executable Paths
alias show_options='shopt'                  # Show_options: display bash options settings
alias fix_stty='stty sane'                  # fix_stty:     Restore terminal settings when screwed up
alias cic='set completion-ignore-case On'   # cic:          Make tab-completion case-insensitive
mcd () { mkdir -p "$1" && cd "$1"; }        # mcd:          Makes new Dir and jumps inside
#trash () { command mv "$@" ~/.Trash ; }     # trash:        Moves a file to the MacOS trash
ql () { qlmanage -p "$*" >& /dev/null; }    # ql:           Opens any file in MacOS Quicklook Preview
alias DT='tee ~/Desktop/terminalOut.txt'    # DT:           Pipe content to file on MacOS Desktop
alias showFiles='defaults write com.apple.finder AppleShowAllFiles YES; killall Finder /System/Library/CoreServices/Finder.app'
alias hideFiles='defaults write com.apple.finder AppleShowAllFiles NO; killall Finder /System/Library/CoreServices/Finder.app'

#------------------------------------------------------------
#   Visual studio from terminal
#------------------------------------------------------------
#code opens Visual Studio Code 
#code . opens current directory in Visual Studio Code 
#code somefile opens somefile in Visual Studio Code
code () {  
    if [[ $# = 0 ]]
    then
        open -a "Visual Studio Code"
    else
        [[ $1 = /* ]] && F="$1" || F="$PWD/${1#./}"
        open -a "Visual Studio Code" --args "$F"
    fi
}

#------------------------------------------------------------
#  Bash completions
#------------------------------------------------------------

# brew install bash-completion
if [ -f $(brew --prefix)/etc/bash_completion ]; then
. $(brew --prefix)/etc/bash_completion
fi

#------------------------------------------------------------
#  Docker
#------------------------------------------------------------

VM_NAME=default
if [ "$(docker-machine status $VM_NAME)" == "Running" ]; then
  echo "Setting environment variables for docker-machine $VM_NAME..."
  eval "$(docker-machine env $VM_NAME)"
fi


#------------------------------------------------------------
#   NETWORKING
#------------------------------------------------------------

alias myip='curl ip.appspot.com'                    # myip:         Public facing IP Address
alias netCons='lsof -i'                             # netCons:      Show all open TCP/IP sockets
alias flushDNS='dscacheutil -flushcache'            # flushDNS:     Flush out the DNS Cache
alias lsock='sudo /usr/sbin/lsof -i -P'             # lsock:        Display open sockets
alias lsockU='sudo /usr/sbin/lsof -nP | grep UDP'   # lsockU:       Display only open UDP sockets
alias lsockT='sudo /usr/sbin/lsof -nP | grep TCP'   # lsockT:       Display only open TCP sockets
alias ipInfo0='ipconfig getpacket en0'              # ipInfo0:      Get info on connections for en0
alias ipInfo1='ipconfig getpacket en1'              # ipInfo1:      Get info on connections for en1
alias openPorts='sudo lsof -i | grep LISTEN'        # openPorts:    All listening connections
alias showBlocked='sudo ipfw list'                  # showBlocked:  All ipfw rules inc/ blocked IPs

#   ii:  display useful host related informaton
#------------------------------------------------------------
ii() {
    echo -e "\nYou are logged on ${RED}$HOST"
    echo -e "\nAdditionnal information:$NC " ; uname -a
    echo -e "\n${RED}Users logged on:$NC " ; w -h
    echo -e "\n${RED}Current date :$NC " ; date
    echo -e "\n${RED}Machine stats :$NC " ; uptime
    echo -e "\n${RED}Current network location :$NC " ; scselect
    echo -e "\n${RED}Public facing IP Address :$NC " ;myip
    #echo -e "\n${RED}DNS Configuration:$NC " ; scutil --dns
    echo
}
#------------------------------------------------------------
#   PROCESS MANAGEMENT
#------------------------------------------------------------

#   findPid: find out the pid of a specified process
#------------------------------------------------------------
#       Note that the command name can be specified via a regex
#       E.g. findPid '/d$/' finds pids of all processes with names ending in 'd'
#       Without the 'sudo' it will only find processes of the current user
#------------------------------------------------------------
findPid () { lsof -t -c "$@" ; }
#   memHogsTop, memHogsPs:  Find memory hogs
#------------------------------------------------------------
alias memHogsTop='top -l 1 -o rsize | head -20'
alias memHogsPs='ps wwaxm -o pid,stat,vsize,rss,time,command | head -10'

#   cpuHogs:  Find CPU hogs
#------------------------------------------------------------
alias cpu_hogs='ps wwaxr -o pid,stat,%cpu,time,command | head -10'

#   topForever:  Continual 'top' listing (every 10 seconds)
#------------------------------------------------------------
alias topForever='top -l 9999999 -s 10 -o cpu'

#   ttop:  Recommended 'top' invocation to minimize resources
#------------------------------------------------------------
#       Taken from this macosxhints article
#       http://www.macosxhints.com/article.php?story=20060816123853639
#------------------------------------------------------------
alias ttop="top -R -F -s 10 -o rsize"

#   my_ps: List processes owned by my user:
#------------------------------------------------------------
my_ps() { ps $@ -u $USER -o pid,%cpu,%mem,start,time,bsdtime,command ; }


#------------------------------------------------------------
#   DEV MANAGEMENT
#------------------------------------------------------------


#------------------------------------------------------------
#
#
#
#------------------------------------------------------------
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm
