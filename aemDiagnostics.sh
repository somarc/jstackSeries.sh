#!/bin/bash
# Comprehensive AEM diagnostic script

# Determine PID of the AEM process
pid=$(ps aux | grep -E "(author|publish|cq|aem).*\.jar" | grep -v grep | awk '{print $2}' | head -1)

if [ -z "$pid" ]; then
  echo >&2 "Error: Missing PID"
  echo >&2 "Usage: aemDiagnostics.sh [ <count> [ <delay> ] ]"
  echo >&2 "    Defaults: count = 10, delay = 1 (seconds)"
  exit 1
fi

echo "AEM process PID: $pid"

# Determine JAVA_HOME from the running Java process
JAVA_CMD=$(ps -p $pid -o args= | grep -oE "java[^ ]*")
JAVA_BIN=$(dirname $(dirname $(readlink -f $(which java))))/bin/

echo "Java command: $JAVA_CMD"
echo "Java binary directory: $JAVA_BIN"

# Determine AEM_JAR from the running Java process arguments
AEM_JAR=$(ps -p $pid -o args= | grep -E "(author|publish|cq|aem).*\.jar" | grep -oE "\-jar [^ ]*\.jar" | awk '{print $2}' | head -1)

if [ -z "$AEM_JAR" ]; then
  echo >&2 "Error: Unable to locate AEM JAR file"
  echo "Debugging information:"
  echo "Process arguments for PID $pid:"
  ps -p $pid -o args=
  exit 1
fi

echo "AEM JAR file: $AEM_JAR"

AEM_HOME=$(dirname "$AEM_JAR")

if [ -z "$AEM_HOME" ]; then
  echo >&2 "Error: Unable to determine AEM_HOME"
  exit 1
fi

count=${1:-10}  # defaults to 10 times
delay=${2:-1}   # defaults to 1 second

echo "Starting AEM diagnostic script with the following parameters:"
echo "PID: $pid"
echo "Count: $count"
echo "Delay: $delay seconds"
echo "JAVA_HOME: $(dirname $(dirname $JAVA_BIN))"
echo "AEM_HOME: $AEM_HOME"

DUMP_DIR=${AEM_HOME}/crx-quickstart/logs/diagnostics/$pid.$(date +%s.%N)
mkdir -p $DUMP_DIR
echo "Generating files under ${DUMP_DIR}"
DUMP_DIR=${DUMP_DIR:+${DUMP_DIR%/}/}

LOG_FILE="$DUMP_DIR/io_stats.log"

# Function to collect I/O stats for Linux
collect_io_stats_linux() {
    echo "Collecting I/O stats for Linux..."
    echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')" >> $LOG_FILE
    
    # Collect I/O statistics using iostat
    echo "I/O Statistics (iostat):" >> $LOG_FILE
    iostat >> $LOG_FILE
    
    # Collect virtual memory statistics using vmstat
    echo "Virtual Memory Statistics (vmstat):" >> $LOG_FILE
    vmstat >> $LOG_FILE
    
    # Collect system activity report using sar
    echo "System Activity Report (sar):" >> $LOG_FILE
    sar >> $LOG_FILE
    
    # Collect disk usage statistics using df
    echo "Disk Usage Statistics (df):" >> $LOG_FILE
    df -h >> $LOG_FILE
    
    echo "----------------------------------------" >> $LOG_FILE
}

# Function to collect I/O stats for macOS
collect_io_stats_macos() {
    echo "Collecting I/O stats for macOS..."
    echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')" >> $LOG_FILE
    
    # Collect I/O statistics using iostat
    echo "I/O Statistics (iostat):" >> $LOG_FILE
    iostat >> $LOG_FILE
    
    # Collect CPU statistics using top
    echo "CPU Statistics (top):" >> $LOG_FILE
    top -l 1 | head -n 10 >> $LOG_FILE
    
    # Collect disk usage statistics using df
    echo "Disk Usage Statistics (df):" >> $LOG_FILE
    df -h >> $LOG_FILE
    
    echo "----------------------------------------" >> $LOG_FILE
}

# Determine the OS and set the appropriate function to collect I/O stats
OS="$(uname)"
if [ "$OS" == "Linux" ]; then
    collect_io_stats=collect_io_stats_linux
elif [ "$OS" == "Darwin" ]; then
    collect_io_stats=collect_io_stats_macos
else
    echo "Unsupported operating system: $OS"
    exit 1
fi

# Capture jstack, top, and I/O stats
while [ $count -gt 0 ]
do
  timestamp=$(date +%s.%N)
  echo "Capturing jstack for PID $pid at $timestamp"
  echo "Executing command: ${JAVA_BIN}jstack -l $pid > ${DUMP_DIR}jstack.$pid.$timestamp"
  ${JAVA_BIN}jstack -l $pid > ${DUMP_DIR}jstack.$pid.$timestamp 2>${DUMP_DIR}jstack_error.$pid.$timestamp
  if [ $? -ne 0 ]; then
    echo "Error: Failed to capture jstack for PID $pid"
    cat ${DUMP_DIR}jstack_error.$pid.$timestamp
    exit 1
  fi
  
  echo "Capturing top output for PID $pid at $timestamp"
  echo "Executing command: top -pid $pid -l 1 > ${DUMP_DIR}top.$pid.$timestamp"
  top -pid $pid -l 1 > ${DUMP_DIR}top.$pid.$timestamp 2>${DUMP_DIR}top_error.$pid.$timestamp
  if [ $? -ne 0 ]; then
    echo "Error: Failed to capture top output for PID $pid"
    cat ${DUMP_DIR}top_error.$pid.$timestamp
    exit 1
  fi
  
  echo "Capturing I/O stats at $timestamp"
  $collect_io_stats
  
  echo "Sleeping for $delay seconds"
  sleep $delay
  let count--
  echo "Remaining iterations: $count"
  echo -n "."
done

# Check for JVM GC log flags and copy the log files if found
GC_LOG_FILES=()
if [[ $JAVA_CMD == *"-Xloggc"* ]]; then
    GC_LOG_FILES+=($(echo $JAVA_CMD | awk -F'-Xloggc:' '{print $2}' | awk '{print $1}'))
elif [[ $JAVA_CMD == *"-Xlog:gc"* ]]; then
    GC_LOG_FILES+=($(echo $JAVA_CMD | awk -F'-Xlog:gc:' '{print $2}' | awk -F'file=' '{print $2}' | awk -F':' '{print $1}'))
fi

if [ ${#GC_LOG_FILES[@]} -eq 0 ]; then
    # Dynamically locate the GC log files based on the PID and "gc" prefix
    GC_LOG_FILES=($(ls $AEM_HOME | grep "gc-$pid-.*\.log"))
fi

if [ ${#GC_LOG_FILES[@]} -gt 0 ]; then
    echo "Found GC log files: ${GC_LOG_FILES[@]}"
    for GC_LOG_FILE in "${GC_LOG_FILES[@]}"; do
        cp $AEM_HOME/$GC_LOG_FILE $DUMP_DIR
        echo "GC log file $GC_LOG_FILE copied to $DUMP_DIR"
    done
else
    echo "No GC log files found."
fi

echo "AEM diagnostic script completed."