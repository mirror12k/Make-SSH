# Make::SSH
A build tool designed for both building and uploading/operating projects via ssh/sftp.

## basics

Uses a subset of gnu makefile syntax to allow executing sh commands locally, ssh commands remotely, and sftp upload/download.
The makefile is split up into rules which can be invoked individually from commandline.
When an error occurs in any sh command, ssh command, or sftp operation, execution of the project.make file is immediately stopped.

## requirements

This module requires the following perl modules: Carp, Net::OpenSSH, Net::SFTP::Foreign.
It also requires some version of openssh client to be installed because Net::OpenSSH and Net::SFTP::Foreign piggyback on it to perform connections.
Obviously your development server needs an ssh server (and an sftp server if you are going to use sftp).

## details!

launch with `./Make/SSH.pm <my rule>` to execute the project.make in the current directory. see the example files at [gcc example](example/gcc/project.make), [php example](example/php_upload/project.make), and [devops example](example/devops/project.make)

## makefiles!

makefiles must always be called 'project.make'.

## sh commands
```make
build:
	sh
		# basic sh commands
		gcc stuff.c
		mv a.out example_binary
		rm example_binary
```

## ssh commands
```make
remote_stuff:
	ssh user:password@192.168.10.101:22
		# basic sh commands on the remote server
		echo hello > test
		cat test
		rm test
		# if a command fails, the make file will stop executing
```


## sftp commands
```make
upload_download:
	sftp user:password@192.168.10.101:22
		# upload a file or directory to remote
		put server_file_or_directory => stuff
		# download the apache log file to local directory
		get /var/log/apache2/error.log => goddamn.log
		# delete a file or directory on the remote server
		delete stuff
```

## why?

Because it seems that there is no simple solution for when uploading/downloading/testing remote files is a common occurrence. This module solves that project with a lightweight and easy to learn solution.
