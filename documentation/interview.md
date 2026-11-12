# Technical interview notes

Use a real example from the [lab results](project_report.md#verification) when explaining each topic.

## How do you calculate CPU utilization?

Read the aggregate counters from `/proc/stat` twice, one second apart. Subtract the first busy and idle totals from the second ones. The busy percentage is `100 × busy delta / (busy delta + idle delta)`. The script counts I/O wait with idle time and reports an unavailable reading if the counter change is invalid.

## What triggers an alert?

The script compares the sampled CPU percentage, the share of memory outside `MemAvailable`, and each filesystem's reported disk usage with its configured threshold. A value at the threshold triggers an alert. The report includes the observed value and limit. A breach is a report result, so a successfully collected report still exits zero.

## How do you diagnose an unhealthy service?

Start with `systemctl is-active`. If the report flags a unit, use `systemctl status UNIT` to see its state and exit status. Filter the journal with `log_analysis.sh --unit UNIT --since '30 minutes ago' --priority info` to connect that state to the service's recent events. Recheck the state and journal after recovery.

## What happens if the backup fails halfway through?

`tar` writes into a private temporary file in the destination directory. A failing `tar` stops the script, and the exit trap removes the temporary file. A successful run publishes the finished file with a hard link that refuses to overwrite an existing name. An optional retention pass runs only after publication and applies to matching archives in that directory.

## How do you prove a scheduled backup works?

Use a short test schedule and check that the job runs under the expected account. Inspect the log for the new archive path, restore the archive to a separate directory, and compare the extracted contents with the source. In the lab, both jobs ran as a regular user and the scheduled backup restored the sample file.

## How does this relate to SAP BASIS?

The lab practices Linux skills used in infrastructure support, including permissions, process and service checks, journal troubleshooting, disk capacity checks, scheduled tasks, and restore validation. Describe the verified Ubuntu work and connect it to the operating-system checks you would use when supporting an SAP environment.
