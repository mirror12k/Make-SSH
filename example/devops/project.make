# example makefile to upload an entire server project, start running the server, and clean it up

# establish our configuration
# notice we don't record the password anywhere, this way it'll be asked from the user upon starting an ssh connection
SSH_SERVER = 192.168.11.3:22
QUARTZ_SERVER = 192.168.11.3:22222
USER = dmin

all: upload

# upload the entire server directory to remote
upload:
	sftp $(USER)@$(SSH_SERVER)
		put server => server

# start the server
start:
	ssh $(USER)@$(SSH_SERVER)
		# Net::OpenSSH doesn't support changing directory, so an && chain is necessary
		# to leave the server running even after the command is done, you'll need to use something like nohup or a daemon
		cd server && perl server.pl

# quickly verify that we can curl the file
verify:
	sh
		curl http://$(QUARTZ_SERVER)/test.am

# delete the entire directory off of remote
clean:
	sftp $(USER)@$(SSH_SERVER)
		delete server
