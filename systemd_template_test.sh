#/bin/sh
count=16

cleanup()
{
	for (( c=1; c <= $count; c++ ))
	do
		systemctl stop dummy_daemon@${c}.service > /dev/null 2>&1
	done
	rm -f /usr/lib/systemd/system/dummy_daemon@* > /dev/null 2>&1
	rm -f /usr/sbin/dummy_daemon > /dev/null 2>&1
}

verify_result()
{
	expected=$1
	actual=$2
	errstr=$3

	if [ $1 -ne $2 ]; then
		echo "FAILED - $errstr"
		exit 1
	fi
}

unit_test()
{
	# 1. Start All.
	echo "Starting All"
	for (( c=1; c <= $count; c++ ))
	do
		systemctl start dummy_daemon@${c}.service > /dev/null 2>&1
		verify_result 0 $? "start failed for instance $c"
	done

	# 2. Verify Status of all
	echo "Verify Status All"
	for (( c=1; c <= $count; c++ ))
	do
	systemctl status dummy_daemon@${c}.service > /dev/null 2>&1
		verify_result 0 $? "status failed for instance $c when it should be up"
	done

	# 3. Kill all
	echo "Kill All"
	killall -9 dummy_daemon
	sleep 4

	# 4. Verify all restarted after failure
	echo "Verify Automatic Restart for All"
	for (( c=1; c <= $count; c++ ))
	do
		systemctl status dummy_daemon@${c}.service > /dev/null
		verify_result 0 $? "status failed for instance $c when it should be up"
	done

	# 5. Stop All
	echo "Verify Stop All"
	for (( c=1; c <= $count; c++ ))
	do
		systemctl stop dummy_daemon@${c}.service > /dev/null
		verify_result 0 $? "stop failed for instance $c"
		systemctl status dummy_daemon@${c}.service > /dev/null
		verify_result 3 $? "status passed for instance $c when it should NOT be up"
	done

	echo "All Tests Passed!"
}

cleanup

# create a systemd template service. This is defined by setting
# a @ before .service
cat << END >> /usr/lib/systemd/system/dummy_daemon@.service
[Unit]
Description=Dummy service file.

[Service]
Type=simple
Restart=always
ExecStart=/usr/sbin/dummy_daemon
END

# create a dummy executable for the our template
cat << END >> /usr/sbin/dummy_daemon
#!/bin/python
import time
while True: time.sleep(5)
END
chmod 755 /usr/sbin/dummy_daemon

# Make as many copies of our templated service as we want
# copies are defined as a symlink to the template <prefix>@<instance>.service
for (( c=1; c <= $count; c++ ))
do
	ln -s /usr/lib/systemd/system/dummy_daemon.service /usr/lib/systemd/system/dummy_daemon@${c}.service
done
systemctl daemon-reload

# now we can start an individual instance of the template
# Example: start multiple instances of the template using symlinks
# systemctl start dummy_daemon@1.service
# systemctl start dummy_daemon@2.service

# TESTING
unit_test
cleanup
