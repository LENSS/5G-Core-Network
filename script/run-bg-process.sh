#!/bin/bash 

# This script runs a given command in the background while maintaining a .pid file
# for all processes started by this script.  The .pid file is used to kill all 
# processes started by this script when the script is run with the -k or kill argument.
# Logs for all processes are written to a unique file in the logs directory.
# The -x or clean argument can be used to remove the .pid file and all log files.
# The script run by itself should display a table of all processes started by this script and their status.

# Example usage:

# Start a process in the background
# ./run-bg-process.sh -c "sleep 10" -n "sleep10"
# --> Returns the PID of the process

# Kill all processes started by this script
# ./run-bg-process.sh -k

# Kill a specific process started by this script
# ./run-bg-process.sh -k -n "sleep10"

# Kill all processes started by this script and remove the .pid file
# ./run-bg-process.sh -k -x

SCRIPT_DIR=$(dirname $(readlink -f $0))
LOG_DIR="$SCRIPT_DIR/.logs"

# Set default values
COMMAND=""
NAME=""
KILL=0
CLEAN=0
UPDATE=0
LOG_OUTPUT=0

# Status codes
STATUS_RUNNING=0
STATUS_EXITED=1
STATUS_FAILED=2

# Delimiter for .pid file
PID_FILE_DELIMITER=":"

# File names
PID_FILE_NAME=".pid"
LOG_FILE_NAME=".log"


# .pid file is in the format:
# PID:COMMAND:NAME:STATUS:LOG_FILE_NAME
# PID:COMMAND:NAME:STATUS:LOG_FILE_NAME
# etc.

# Job to check statuses of all processes once a second, use while loop to keep job running
# We give the job a name so we can kill it later
UPDATE_JOB_NAME="update_bg_processes"
UPDATE_JOB_LOG_FILE_NAME="$UPDATE_JOB_NAME.log"

# Helper Methods
check_status() {
    # if process still running, do nothing
    if [ $(ps -p $1 | wc -l) -eq 2 ]; then
        return
    else # if process exited, mark it as exited in .pid file
        kill_process $1
    fi
}

kill_process() {
    # If process exists, kill it
    if [ $(ps -p $1 | wc -l) -eq 2 ]; then
        # Kill process
        kill $1

        # Wait for process to exit
        while [ $(ps -p $1 | wc -l) -ne 1 ]; do
            sleep 0.1
        done
    fi

    D=$PID_FILE_DELIMITER
    COMMAND=$(cat $SCRIPT_DIR/$PID_FILE_NAME | grep $1 | cut -d $D -f 2) || ""
    NAME=$(cat $SCRIPT_DIR/$PID_FILE_NAME | grep $1 | cut -d $D -f 3) || ""
    LOG_FILE_NAME=$(cat $SCRIPT_DIR/$PID_FILE_NAME | grep $1 | cut -d $D -f 5) || ""

    # Mark process as exited in .pid file (4th column)
    # PID:COMMAND:NAME:STATUS_RUNNING:LOG_FILE_NAME -> PID:COMMAND:NAME:STATUS_EXITED:LOG_FILE_NAME
    sed -i "s/$1$D.*$D.*$D$STATUS_RUNNING$D.*/$1$D${COMMAND//\//\\/}$D${NAME//\//\\/}$D$STATUS_EXITED$D${LOG_FILE_NAME//\//\\/}/" $SCRIPT_DIR/$PID_FILE_NAME
}

exit_if_no_pid_file() {
    if [ ! -f $SCRIPT_DIR/$PID_FILE_NAME ]; then
        echo "No processes started by this script"
        exit 0
    fi
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --c)
      shift
      COMMAND=()
      while [[ "$#" -gt 0 ]]; do
        COMMAND+=("$1")
        shift
      done
      COMMAND="${COMMAND[@]}"
      if [ -z "$COMMAND" ]; then
        echo "No command given" >&2
        exit 1
      fi
      ;;
    -n)
        shift
        NAME="$1"
        shift
        ;;
    -k)
        KILL=1
        shift
        ;;
    -x)
        CLEAN=1
        shift
        ;;
    -l)
        LOG_OUTPUT=1
        shift
        ;;
    -u)
        UPDATE=1
        shift
        ;;
    -h)
        echo "Usage: run-bg-process.sh [-n NAME] [-k] [-x] [-c COMMAND]"   
        echo "  -c COMMAND: Command to run in the background (must be the last argument, everything after this will be considered part of the command)"
        echo "  -n NAME: Name of the process"
        echo "  -l: Print the output of the process to the terminal"
        echo "  -k: Kill all processes started by this script"
        echo "  -x: Kill all processes started by this script and remove the .pid file"
        exit 0
        ;;
    *)
      echo "Unknown parameter passed: $1" >&2
      exit 1
      ;;
  esac
done


# If update flag is set, check the status of all processes and update the .pid file
if [ $UPDATE -eq 1 ]; then
    exit_if_no_pid_file
    while true; do 
        # Check the status of all processes
        for pid in $(cat $SCRIPT_DIR/$PID_FILE_NAME | cut -d $PID_FILE_DELIMITER -f 1); do
            # if STATUS_RUNNING, check if process is still running
            # if STATUS_EXITED, do nothing
            # if STATUS_FAILED, do nothing
            status=$(cat $SCRIPT_DIR/$PID_FILE_NAME | grep $pid | cut -d $PID_FILE_DELIMITER -f 4)
            if [ $status -eq $STATUS_RUNNING ]; then
                check_status $pid
            fi
        done
        sleep 1
    done
fi

# If the -k or kill argument is given, check if a specific process was given
# Otherwise, kill all processes started by this script.

if [ $KILL -eq 1 ]; then
    exit_if_no_pid_file
    if [ -z "$NAME" ]; then
        echo "Killing all processes started by this script"
        for pid in $(cat $SCRIPT_DIR/$PID_FILE_NAME | cut -d $PID_FILE_DELIMITER -f 1); do
            kill_process $pid
        done
        
    else
        echo "Killing process $NAME"
        pid=$(cat $SCRIPT_DIR/$PID_FILE_NAME | grep $NAME | cut -d $PID_FILE_DELIMITER -f 1)
        if [ -z "$pid" ]; then
            echo "Process $NAME does not exist"
            exit 1
        fi
        kill_process $pid
    fi
    exit 0
fi

# If the -x or clean argument is given, but no -k or kill argument is given, be sure 
# there are no processes running before cleaning up.
# Otherwise, exit with an error.
if [ $CLEAN -eq 1 ]; then
    exit_if_no_pid_file
    if [ -z "$NAME"]; then
        echo "Cleaning up"
        # Check if there are any processes running by their status
        if [ $(cat $SCRIPT_DIR/.pid | cut -d $PID_FILE_DELIMITER -f 4 | grep -v $STATUS_EXITED | wc -l) -gt 0 ]; then
            echo "There are processes running.  Kill them before cleaning up."
            exit 1
        else 
            # Clean up by removing the .pid file and all log files
            rm $SCRIPT_DIR/$PID_FILE_NAME
            rm -rf $LOG_DIR
            exit 0
        fi
    else
        echo "Cleaning up process $NAME"
        # Check if there are any processes running by their status
        if [ $(cat $SCRIPT_DIR/.pid | grep $NAME | cut -d $PID_FILE_DELIMITER -f 4 | grep -v $STATUS_EXITED | wc -l) -gt 0 ]; then
            echo "Process $NAME is running.  Kill it before cleaning up."
            exit 1
        else 
            # Clean up by removing the .pid file and all log files
            sed -i "/$NAME/d" $SCRIPT_DIR/$PID_FILE_NAME
            rm $LOG_DIR/$NAME.log
            exit 0
        fi
    fi
fi

if [ $LOG_OUTPUT -eq 1 ]; then
    # if no name is given, exit with an error
    if [ -z "$NAME" ]; then
        echo "No name given"
        exit 1
    fi
    # if no log file exists for the given name, exit with an error
    if [ ! -f "$LOG_DIR/$NAME.log" ]; then
        echo "No log file exists for process $NAME"
        exit 1
    fi
    # if log file exists, tail the log file
    tail -f $LOG_DIR/$NAME$LOG_FILE_NAME
fi

# If the -c or command argument is given, run the command in the background
# Every flag after the -c argument is considered part of the command
if [ ! -z "$COMMAND" ]; then
    echo "Running command $COMMAND"
    # Create the log directory if it doesn't exist
    if [ ! -d "$LOG_DIR" ]; then
        mkdir $LOG_DIR
    fi

    # Create a .pid file if it doesn't exist
    if [ ! -f "$SCRIPT_DIR/$PID_FILE_NAME" ]; then
        touch $SCRIPT_DIR/$PID_FILE_NAME
    fi

    # If a name is given, check if a process with that name is already running
    # If a process with that name is already running, exit with an error
    if [ ! -z "$NAME" ]; then
        if [ $(cat $SCRIPT_DIR/$PID_FILE_NAME | grep $NAME | wc -l) -gt 0 ]; then
            echo "A process with the name $NAME is already running"
            exit 1
        fi
    else 
        # Create a name for the process if one is not given
        # random 10 character string
        NAME=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)
    fi

    # Run the command in the background
    # If a name is given, use the name as the log file name
    # Otherwise, use the PID as the log file name
    if [ ! -z "$NAME" ]; then
        $COMMAND > $LOG_DIR/$NAME$LOG_FILE_NAME 2>&1 &
    else
        $COMMAND > $LOG_DIR/$!$LOG_FILE_NAME 2>&1 &
    fi

    # Get the PID of the process
    PID=$!

    # Add the PID, command, name, and status to the .pid file
    COMMAND_STR=$(echo $COMMAND | sed 's/ /\\ /g')
    echo "$PID$PID_FILE_DELIMITER$COMMAND_STR$PID_FILE_DELIMITER$NAME$PID_FILE_DELIMITER$STATUS_RUNNING$PID_FILE_DELIMITER$NAME$LOG_FILE_NAME" >> $SCRIPT_DIR/$PID_FILE_NAME

    # Check if the update job is already running
    if [ $(cat $SCRIPT_DIR/$PID_FILE_NAME | grep $UPDATE_JOB_NAME | wc -l) -eq 0 ]; then
        # If the update job is not run it in the background
        $SCRIPT_DIR/run-bg-process.sh -u > $LOG_DIR/$UPDATE_JOB_LOG_FILE_NAME &
        UPDATE_JOB_PID=$!
        # Add the update job to the .pid file
        echo "$UPDATE_JOB_PID$PID_FILE_DELIMITER$SCRIPT_DIR/run-bg-process.sh -u$PID_FILE_DELIMITER$UPDATE_JOB_NAME$PID_FILE_DELIMITER$STATUS_RUNNING$PID_FILE_DELIMITER$UPDATE_JOB_LOG_FILE_NAME" >> $SCRIPT_DIR/$PID_FILE_NAME
    fi

    # Print tuple of PID, command, name, and log file name
    echo "( $PID, $COMMAND, $NAME, $LOG_DIR/$NAME$LOG_FILE_NAME ) - Process started"
    exit 0
fi

# If no arguments are given, display a table of all processes
# The table contains the PID, command, name, status, and log file name
if [ -z "$COMMAND" ] && [ -z "$NAME" ] && [ $KILL -eq 0 ] && [ $CLEAN -eq 0 ]; then
    # Check if the .pid file exists
    if [ -f "$SCRIPT_DIR/$PID_FILE_NAME" ]; then
        # Check if there are any processes running
        if [ $(cat $SCRIPT_DIR/$PID_FILE_NAME | wc -l) -gt 0 ]; then
            # Print the table header
            printf "%-10s %-20s %-10s %-20s" "PID" "NAME" "STATUS" "LOG FILE"
            echo ""
            # Print dashes for the table header
            printf "%-10s %-20s %-10s %-20s" "----------" "--------------------" "----------" "--------------------"
            echo ""
            # Print the table
            while read line; do
                PID=$(echo $line | cut -d $PID_FILE_DELIMITER -f 1)
                NAME=$(echo $line | cut -d $PID_FILE_DELIMITER -f 3)
                STATUS=$(echo $line | cut -d $PID_FILE_DELIMITER -f 4)
                STATUS_STR=""
                if [ $STATUS -eq 0 ]; then
                    STATUS_STR="Running"
                elif [ $STATUS -eq 1 ]; then
                    STATUS_STR="Exited"
                fi
                LOG_FILE=$(echo $line | cut -d $PID_FILE_DELIMITER -f 5)
                printf "%-10s %-20s %-10s %-20s" "$PID" "$NAME" "$STATUS_STR" "$LOG_FILE"
                echo ""
            done < $SCRIPT_DIR/$PID_FILE_NAME
        else
            echo "No processes running"
        fi
    else
        echo "No processes running"
    fi
fi

