# Set up Ubuntu on WSL2

## 1. Find the Ubuntu distribution

In Windows PowerShell, run:

```powershell
wsl --version
wsl --list --verbose
```

Look for Ubuntu with `VERSION` set to `2`. Use the exact distribution name displayed by the command. The following example assumes it is named `Ubuntu`:

```powershell
wsl --distribution Ubuntu
```

If the list works and no Ubuntu distribution is installed, use the [Microsoft WSL installation guide](https://learn.microsoft.com/en-us/windows/wsl/install). If Ubuntu is listed as version `1`, back up any important files in the distribution before converting it with `wsl --set-version <distribution-name> 2`. If the list returns access denied in your own PowerShell session, resolve that before attempting to install or convert a distribution. [Microsoft WSL command reference](https://learn.microsoft.com/windows/wsl/reference)

## 2. Verify the Linux runtime

Inside Ubuntu, run:

```bash
cat /etc/os-release
uname -r
id
ps -p 1 -o comm=
```

For the service and journal exercises, PID 1 should be `systemd`. If it is not, edit `/etc/wsl.conf` with `sudoedit` and set `systemd=true` under `[boot]`, keeping the existing settings. Exit Ubuntu, run `wsl --terminate <distribution-name>` from PowerShell to restart only that distribution, reopen Ubuntu, and check PID 1 again. [Microsoft systemd configuration guide](https://learn.microsoft.com/en-us/windows/wsl/systemd/)

## 3. Prepare the Linux lab directories

Inside Ubuntu, run:

```bash
mkdir -p "$HOME/linux-monitoring-lab"/{data,reports,logs,backups}
```

Clone the published repository into `~/linux-server-administration`. To run an unpublished copy, adjust the Windows path in this example and copy the files from the mounted drive:

```bash
project_source='/mnt/c/Users/your-name/Projects/linux-server-administration'
mkdir -p "$HOME/linux-server-administration"
cp -a -- "$project_source"/README.md "$project_source"/{scripts,cron,tests,documentation,reports} \
  "$HOME/linux-server-administration/"
cd "$HOME/linux-server-administration"
```

Run the permissions exercises and store generated reports, logs, backup inputs, and archives in the Linux-native `~/linux-monitoring-lab` directory. [Microsoft guide to Windows and Linux filesystems](https://learn.microsoft.com/en-us/windows/wsl/filesystems)

## 4. Prepare the baseline utilities

Once Ubuntu is verified, install the baseline utilities inside the lab distribution:

```bash
sudo apt update
sudo apt install cron git htop iproute2 iputils-ping procps tar gzip
```

Install `openssh-server` during the [SSH exercise](lab.md#networking-and-local-ssh), which uses a separate listener bound to loopback.
