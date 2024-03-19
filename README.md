## pchw: PC Hardware System Information Collector for FreeBSD

pchw.sh is a PC/x86 system information collector for FreeBSD that collects basic information like manufacturer, product line, serial number, BIOS revision etc., plus provides syntax for changing NVMe LBA formats (i.e. 512b to 4Kn) and has a helper script to generate tab-serparated output for export to a spreadsheet or database.

By default, pchw.sh ouptputs to a directory named with the serial number of the system. Providing a name will use that name rather than the serial number.

```
sh pchw.sh my-new-laptop
```

To output tab-separated values:

```
sh generate-tsv.sh
LENOVO	ThinkPad T490	20N20042US	Notebook	ABCD1234	1.80	06/21/2023	Intel(R) Core(TM) i7-8665U CPU @ 1.90GHz	No Asset Information
```

Edit the dmi_strings variable in generate-tsv.sh based on the values in <system>/dmi-strings/* to suit.

This project is not an endorsement of GitHub
