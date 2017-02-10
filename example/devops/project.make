
SSH_SERVER = 192.168.11.3:22
QUARTZ_SERVER = 192.168.11.3:22222
USER = dmin

all: upload

upload:
	sftp $(USER)@$(SSH_SERVER)
		put server => server

start:
	ssh $(USER)@$(SSH_SERVER)
		cd server && perl server.pl

verify:
	sh
		curl http://$(QUARTZ_SERVER)/test.am

clean:
	sftp $(USER)@$(SSH_SERVER)
		delete server
