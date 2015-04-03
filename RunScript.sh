#!/bin/bash
# Run robocontroller Processing program and pipe it to actionbot.  Supply the three usbmodem ports to actionbot.  Requires FTDI serial port drivers.

cd "application.linux64" && ./robocontroller | ../actionbot `ls -d -1 /dev/*.* | grep tty.usbmodem | xargs -n3`
