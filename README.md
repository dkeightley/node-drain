# node-drain

A systemd service and script to drain and optionally delete nodes on shutdown/restart.

### Install

#### Download the files

- git clone this repo
- `cd node-drain`

or

```bash
curl -OLs https://raw.githubusercontent.com/dkeightley/node-drain/master/node-drain.service
curl -OLs https://raw.githubusercontent.com/dkeightley/node-drain/master/node-drain.sh
```

#### Copy files into place and enable the service

```bash
cp node-drain.sh /usr/local/bin/
cp node-drain.service /etc/systemd/system/
systemctl enable node-drain
systemctl daemon-reload
systemctl start node-drain
```

### Check the logs
```bash
journalctl -u node-drain
```

### Usage

```
node-drain systemd service for RKE and k3s

  Usage: bash node-drain.sh [ -d -n -r <container runtime> ]

    All flags are optional:
    -d    Delete local data, pods using emptyDir volumes will be drained as well
    -n    Delete node as well, useful for immutable infrastructure as nodes are replaced on shutdown
    -r    Override container runtime if not automatically detected (docker|k3s)
```