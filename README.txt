What should it do:
Files in this directory should automatically create sshuttle as a service on local server and make it tunnel communication to remote server.
Website used as source: https://medium.com/@mike.reider/using-sshuttle-as-a-service-bec2684a65fe
WARNING: YOU NEED TO HAVE A USER ON SERVER TO WHICH YOU WANT TO TUNNEL BEFORE USING THIS SCRIPT

How to run:
Run sshuttle_install_script.sh [-dh] -u <Username on remote server, holds SSH key> -s <Remote hostname>

Files in directory sshuttle_install
Commands files:
- sshuttle_install_script.sh - Shell script which sets up sshuttle as service and tunneling to remote server, MUST RUN WITH SUDO
	
Files used by sshuttle_install_script (These files are copied to its place by this script):
- sshuttle.sh - shell script which is used by sshuttle service 
- sshuttle.service - File defining sshuttle service
- sshuttle - Sudoers file for sshuttle, sets sudo access to sshuttle user to modify firewall, 
WARNING: Currently this file practically gives sshuttle user root privilages through sudo on local (host) server but this user can be accessed only by root
-sshuttle.conf - config used by sshuttle.sh, contains: - Hostname of server to which we want to tunnel communication
															   - What ip adresses and ports should we tunnel (0/0 - means all communication)
															   - Excepted ip adresses and port
															   - example: sshuttle@10.0.2.5,0/0 -x 10.0.2.5 -x 10.0.2.15:22
		
