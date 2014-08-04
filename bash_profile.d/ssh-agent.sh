_ID=$(id -un)
_SSH_AUTH_SOCK="/tmp/ssh-agent.$_ID.sock"
_SSH_PID_FILE="/tmp/ssh-agent.$_ID.pid"
_SSH_LOCK="/tmp/ssh-agent.$_ID.lock"

# Mutex lock to make this script running exclusively.
_count=0
while ! mkdir $_SSH_LOCK; do
  echo "Acquring ssh-agent lock."
  sleep 1
  let _count=_count+1
  if [[ $_count -gt 5 ]]; then
    echo Failed
    return
  fi
done

_SSH_AGENT_PID=$(cat $_SSH_PID_FILE 2>/dev/null)

# validate SSH_AUTH socket.
# validate pid of runing ssh-agent, use /proc/pid/fd to elimate pid=""
# /proc/pid/fd not work for mac, prefer lsof -p pid
if [ -S "$_SSH_AUTH_SOCK" ]; then

    # ssh-agent is already running now.
    export SSH_AUTH_SOCK=$_SSH_AUTH_SOCK
    export SSH_AGENT_PID=$_SSH_AGENT_PID
else
    # \todo kill ssh-agent use $_SSH_AUTH_SOCK
    # Remove $_SSH_AUTH_SOCK to avoid "bind: Address already in use"
    [[ -S "$_SSH_AUTH_SOCK" ]] && /bin/rm $_SSH_AUTH_SOCK

    # Spawn a new ssh-agent
    eval `ssh-agent -a $_SSH_AUTH_SOCK` >/dev/null
    if [[ -z $SSH_AGENT_PID ]]; then
        echo Failed to start ssh-agent.
    else
        # Save pid.
        echo $SSH_AGENT_PID >$_SSH_PID_FILE

        echo Trying to add keys.
        ssh-add
        for key in ~/.ssh/*.key; do
            ssh-add "$key"
        done
    fi
fi

rmdir $_SSH_LOCK

unset _SSH_AUTH_SOCK
unset _SSH_AGENT_PID
unset _SSH_PID_FILE
