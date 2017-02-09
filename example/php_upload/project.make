# a basic example makefile to upload a php script to a remote directory, test said file, download any errors, and clean the remote file off of the server


# prepare our credentials
# server address can be a domain name as well, and can optionally have a port number like '192.168.11.3:22'
SSH_SERVER = 192.168.11.3
HTTP_SERVER = 192.168.11.3
USER = dmin
# password is optional, if you use "sftp $(USER)@$(SSH_SERVER)" instead, Net::OpenSSH will ask you for a password in command line
PASSWORD = dminpassword


# define a few file locations we'll be using
PHP_FILE = my_awesome_test_file.php
LOG_LOCATION = /var/log/apache2
LOG_NAME = error.log

# default to uploading file
all: upload

upload:
	# start an sftp connection
	sftp $(USER):$(PASSWORD)@$(SSH_SERVER)
		# put the file into apache's public html directory
		put $(PHP_FILE) => /var/www/html/$(PHP_FILE)

# test the uploaded file
test:
	sh
		# run a perl script that will die() if it doesn't confirm the remote file's output
		perl run_test.pl http://$(HTTP_SERVER)/$(PHP_FILE)

get_log:
	sftp $(USER):$(PASSWORD)@$(SSH_SERVER)
		# retrieve the log file to the local directory
		get $(LOG_LOCATION)/$(LOG_NAME) => $(LOG_NAME)

clean_remote:
	sftp $(USER):$(PASSWORD)@$(SSH_SERVER)
		# delete the file off of the remote server
		delete /var/www/html/$(PHP_FILE)
