# Usage for `test_optics.sh`

```
usage: test_optics.sh [-l LABEL] [OPTIONS] -s PORT:PART [ -s PORT:PART]

Perform an EEPROM dump of the pluggable module PART on PORT.

COMMAND LINE OPTIONS

        -h
                Help.  Print this message.

        -n
                Dry run.  Do not perform any actions.

        -v
                Be verbose. Print what is happening.

        -o
                Use the following output directory.
                (default: /mnt/usb/interop_pluggables_results)

        -l
                Use the following label for this EEPROM dump run.
                (default: UNKNOWN)

        -s
                Use the following PORTs and SERIAL NUM using a ':' to
                separate PORT and SERIAL NUM.  Multiple PORT:SERIAL NUM can be
                specified by specifying another -s PORT:SERIAL NUM.

```

In the following example, we use `603` as the part number or SKU and `APF` is
the serial number.

Generally, `ethtool -m swp1 | egrep 'Vendor (P|S)N'` is used to grab this 
information.

```
# mkdir -p /mnt/usb
# mount /dev/sdb1 /mnt/usb
# cd /mnt/usb
# ./test_optics.sh -l 603020005 -s swp1:APF153400545GN -s swp:APF153400545H2
```

Output is collected under `/mnt/usb/interop_pluggables_results`.
