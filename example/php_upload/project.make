
REMOTE_SERVER = 192.168.11.3
USER = dmin
PASSWORD = dminpassword

PHP_FILE = my_awesome_test_file.php

all: upload

upload:
	sftp $(USER):$(PASSWORD)@$(REMOTE_SERVER)
		put $(PHP_FILE) => /var/www/html/$(PHP_FILE)

test:
	sh
		perl run_test.pl http://$(REMOTE_SERVER)/$(PHP_FILE)

clean_remote:
	sftp $(USER):$(PASSWORD)@$(REMOTE_SERVER)
		delete /var/www/html/$(PHP_FILE)
