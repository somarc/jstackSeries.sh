- [Linux - aemDiagnostics.sh](#aemdiagnostics)
- [Linux Java - jstackSeries.sh](#jstackseriessh)
- [Linux AEM - jstackSeriesAEM.sh](#jstackseriesaemsh)
- [MS Windows - Powershell Script - jstackSeries_powershell.ps1](#ms-windows---powershell-script)
<!-- toc -->

# aemDiagnostics.sh

### AEM Diagnostic Script
#### Overview
This comprehensive AEM (Adobe Experience Manager) diagnostic script is designed to gather various diagnostic information about an AEM instance running on a Linux system. It identifies the AEM process, determines the JAVA_HOME and AEM JAR file, and collects various system statistics and logs to help diagnose issues with the AEM instance.

#### Prerequisites
The script requires ps, grep, awk, dirname, readlink, which, iostat, vmstat, sar, and df commands to be available on the system.
Ensure that the script has execute permissions. You can set the execute permission using the following command:
chmod +x aemDiagnostics.sh

#### Usage
` ./aemDiagnostics.sh [ <count> [ <delay> ] ] `

- count (optional): The number of times to collect diagnostic information. Defaults to 10 if not provided.
- delay (optional): The delay in seconds between each collection of diagnostic information. Defaults to 1 second if not provided.

#### Example
`./aemDiagnostics.sh 5 2`

This command will run the diagnostic script 5 times with a 2-second delay between each run.

#### Script Details

##### Determine PID of the AEM Process
The script identifies the PID of the AEM process by searching for processes that match certain keywords (author, publish, cq, aem) and contain a .jar file.

`pid=$(ps aux | grep -E "(author|publish|cq|aem).*\.jar" | grep -v grep | awk '{print $2}' | head -1)`

##### Determine JAVA_HOME
The script extracts the Java command used by the AEM process and determines the Java binary directory.

`JAVA_CMD=$(ps -p $pid -o args= | grep -oE "java[^ ]*")`

`JAVA_BIN=$(dirname $(dirname $(readlink -f $(which java))))/bin/`

##### Determine AEM JAR
The script identifies the AEM JAR file used by the AEM process.

`AEM_JAR=$(ps -p $pid -o args= | grep -E "(author|publish|cq|aem).*\.jar" | grep -oE "\-jar [^ ]*\.jar" | awk '{print $2}' | head -1)`

##### Collect Diagnostic Information
The script collects various system statistics and logs, including:

- I/O statistics using iostat
- Virtual memory statistics using vmstat
- System activity report using sar
- Disk usage statistics using df

##### Generate Diagnostic Files
The script generates diagnostic files under the crx-quickstart/logs/diagnostics/ directory within the AEM home directory. The files include:

- jstack output
- top output
- I/O statistics logs
- Check for JVM GC Log Flags
- The script checks for JVM GC log flags and copies the GC log files to the diagnostic output directory if found.

##### Error Handling
If the script encounters any errors, it will output an error message and exit. Common errors include:

- Missing PID
- Unable to locate AEM JAR file
- Failed to capture jstack or top output (sudo needed perhaps)

This AEM diagnostic script is a powerful tool for gathering diagnostic information about an AEM instance. By following the instructions in this README.md file, you can effectively use the script to diagnose and troubleshoot issues with your AEM instance.


# jstackSeries.sh
Bash jstack script for capturing a series of thread dumps from a Java process on Linux.

Just run it like this:

`sudo -u java-process-user-id sh jstackSeries.sh pid [[count] delay]`

For example:
`sudo -u javauser sh jstackSeries.sh 1234 10 3`
- javauser is the user that owns the java process
- 1234 is the pid of the Java process
- 10 is how many thread dumps to take
- 3 is the delay between each dump

Note: 
* The script must run as the user that owns the java process.
* The top output has the native thread id in decimal format while the jstack output has the "nid" in hexadecimal.  You can match the thread id (PID) from the top output to the jstack output by converting the thread id to hexadecimal.  This provides CPU profiling at the Java thread level.

# jstackSeriesAEM.sh
Bash jstack script for capturing a series of thread dumps from an Adobe Experience Manager Java process on Linux.

Make these modifications to the script:
* Update the JAVA_HOME variable to point to the path of where java is installed.
* Update the AEM_HOME variable to point to the path of where AEM is installed.

Just run it like this:

`sudo -u aem-process-user-id sh jstackSeriesAEM.sh [[count] delay]`

For example:
`sudo -u aemuser sh jstackSeriesAEM.sh 10 3`
- aemuser is the user that owns the java process that runs AEM
- 10 is how many thread dumps to take
- 3 is the delay between each dump

Note:
* The script will automatically try to get the AEM process' PID.  It will first look for ${AEM_HOME}/crx-quickstart/conf/cq.pid, if that file is non-existent or empty it would fail over to "ps -aux | grep $AEM_JAR" where variable $AEM_JAR is the name of the jar file.  If it fails with both of those it would report an error.
* Thread dumps and top output would automatically be generated under crx-quickstart/logs/threaddumps in a subfolder with the PID and a timestamp in the name.

# MS Windows - Powershell Script
NOTE - Makes the assumption that jstack is on the Windows Environmental Variables PATH

## Usage
Command:
```
jstackSeries_powershell.ps1 <pid> <num_threads> <time_between_threads_seconds>
```
### Step 1
Provide the script the location of jstack.exe via one of the following methods:
1. Add the JDK bin folder to the windows Path and reopen the powershell.
2. Set the JAVA_HOME environment variable to the JDK home directory and reopen the powershell.
3. Or modify the jstackSeries_powershell.ps1 script and set the script:jstackbin variable to the full path of jstack.exe. 

The "TOP" output is not similar to the Linux top output and there's some things to understand.

Regular expressions to match "long" running threads.
```
CPUTime \(Sec\)        : ([0-9]{2,}\.[0-9]{1,}) 
CPUTime \(Sec\)        : ([0-9]{3,}\.[0-9]{1,})
```

### $ProcessThread.TotalProcessorTime
A TimeSpan that indicates the amount of time that the associated process has spent utilizing the CPU. This value is the sum of the UserProcessorTime and the PrivilegedProcessorTime.

### $ProcessThread.UserProcessorTime
User CPUTime (%)

A TimeSpan that indicates the amount of time that the associated process has spent running code inside the application portion of the process (not inside the operating system core).

### $ProcessThread.privilegedProcessorTime
System CPUTime (%)

A TimeSpan that indicates the amount of time that the process has spent running code inside the operating system core.
