
# macbac

Lists and controls your macOS snapshots and backups for all your available modules.
This is a pretty wrapper around tmutil for your convenience.

```shell
% macbac status
Status: Inactive

% macbac list
/Volumes/SSD
> 2020/12/30 10:23
> 2020/12/30 11:04
> 2020/12/30 11:05

% macbac snapshot
Assuming / is the volume we would like to snapshot.
Created local snapshot with date: 2020-12-30-111728
Snapshotted volume /
```

## Installation

Just copy `macbac.sh` to  your filesystem.
