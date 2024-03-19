#!/bin/sh
#-
# SPDX-License-Identifier: BSD-2-Clause-FreeBSD
#
# Copyright 2024 Michael Dexter
# All rights reserved
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted providing that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
# IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

# Not to be confused with /usr/sbin/acpidump
[ -x /usr/local/bin/acpidump ] || pkg install acpica-tools
which dmidecode 2>&1 >/dev/null || pkg install dmidecode
which smartctl 2>&1 >/dev/null || pkg install smartmontools
which sedutil-cli 2>&1 >/dev/null || pkg install sedutil

echo ; echo Obtaining serial number with dmidecode\(8\)
serial_number=`dmidecode -s system-serial-number` || \
	{ echo Failed to obtain serial number ; exit 1 ; }

if [ "$#" -ge 2 ]; then
		echo ; echo System name cannot contain a space
		echo Example: my-laptop
		exit 1
elif [ "$1" ]; then
		system_name="$1"
		echo ; echo Using system name $system_name
else
		system_name="$serial_number"
fi

if [ -d $system_name ] ; then

	echo ; echo Deleting ${system_name}.previous
	[ -d ${system_name}.previous ] && rm -rf ${system_name}.previous
	echo Moving $system_name to ${system_name}.previous
	mv $system_name ${system_name}.previous
fi

mkdir $system_name || { echo Failed to make $system_name directory ; exit 1 ; }

echo ; echo Obtaining Product Key
# FYI on Linux: /sys/firmware/acpi/tables/MSDM
/usr/local/bin/acpidump | grep -A5 MSDM | tail -n3 | cut -c60-75 | \
xargs echo | sed -e 's/^\.*//' -e 's/ //g' > $system_name/product-key.txt

echo ; echo Obtaining DMI information
# Collect all
dmidecode > $system_name/dmidecode.txt

# Collect individual for parsing to a spreadsheet etc.
dmi_strings="bios-vendor
bios-version
bios-release-date
bios-revision
firmware-revision
system-manufacturer
system-product-name
system-version
system-serial-number
system-uuid
system-sku-number
system-family
baseboard-manufacturer
baseboard-product-name
baseboard-version
baseboard-serial-number
baseboard-asset-tag
chassis-manufacturer
chassis-type
chassis-version
chassis-serial-number
chassis-asset-tag
processor-family
processor-manufacturer
processor-version
processor-frequency"

mkdir $system_name/dmi-strings || { echo Failed to make dmi-strings ; exit 1 ; }

for string in $dmi_strings ; do
	dmidecode -s $string > $system_name/dmi-strings/$string
done

# systemd systems may fail on this
ifconfig > $system_name/ifconfig
dmesg > $system_name/dmesg
# FreeBSD-specific
gpart show > $system_name/gpart_show

mkdir $system_name/disks

# FreeBSD-specific
sysctl -n kern.disks | tr ' ' '\n' | while read disk ; do
# The kernel sees nvd0 but smartctl wants nvme0
	device_type=$( echo $disk | tr -d "[0-9]" )
	device_number=$( echo $disk | tr -d "[a-z]" )

	case $device_type in
		ada|da)
# Could get the serial number but that would fail with virtual disks
			smartctl -a /dev/$disk > \
				$system_name/disks/$disk.smartctl-a
			smartctl -x /dev/$disk > \
				$system_name/disks/$disk.smartctl-x
		;;
		nda|nvd|nvme)
			# FreeBSD-specific
			nvmecontrol identify $disk > $system_name/disks/${disk}.identify
			nvmecontrol identify nvme$device_number > \
				$system_name/disks/nvme${device_number}.identify
			echo
			nvmecontrol identify nvme${device_number}ns1 | \
				grep "LBA Format"

			smartctl -a /dev/nvme$device_number > \
			$system_name/disks/nvme${device_number}.smartctl-a
			smartctl -x /dev/nvme$device_number > \
			$system_name/disks/nvme${device_number}.smartctl-x

			echo
			echo The syntax to reformat nvme${device_number} to another LBA format \(i.e. #01\) is:
			echo nvmecontrol format -f 01 nvme${device_number}ns1
			echo You must reboot for the format to be recognized
		;;
	esac
done

echo ; echo The PC Hardware information is saved in $system_name
exit 0
