
# macbac

Lists, controls and schedules efficient APFS snapshots for your convenience.

```shell
# let's take space efficient APFS snapshots every hour
# knowing they get cleaned up if necessary
% ./macbac.sh schedule hourly
Installing daemon config to /Users/user/Library/LaunchAgents/com.hazcod.macbac.plist
Loading config to enable schedule...
Scheduled hourly snapshots!

# show our current snapshots
% macbac list
/Volumes/SSD
> 2020/12/30 10:23
> 2020/12/30 11:04
> 2020/12/30 11:05

# take a manual snapshot
% macbac snapshot
Assuming / is the volume we would like to snapshot.
Created local snapshot with date: 2020-12-30-111728
Snapshotted volume /

# let's remove snapshots but ensure we keep the 3 most recent
% macbac prune 3
Pruning 1 of 4 snapshots for /
Pruning snapshot 2021-02-04-155845 (1/1)
```

## How does it work?

It's a convenient wrapper around `tmutil`.

## Installation

Installation can be done straight from [my Homebrew tap](https://github.com/hazcod/homebrew-hazcod) via `brew install hazcod/homebrew-hazcod/macbac` or just copy `macbac.sh` to  your filesystem.

## Usage

`Usage: macbac <status|list|snapshot|enable|disable|schedule|deschedule|prune> <...>`

To view Time Machine status: `macbac status`

To take a snapshot: `macbac snapshot`

To take a snapshot and keep 3: `macbac snapshot 3`

To prune but keep 5: `macbac prune 5`

To schedule hourly snapshots, keeping 24: `macbac schedule hourly`

To schedule hourly snapshots, keeping 3: `macbac schedule hourly 3` 

To schedule daily snapshots, keeping 7: `macbac schedule daily`
