# a basic example makefile to build a C program


# variables are supported
BIN = test_main

# multi line instructions are supported
SRCS = test.c\
		main.c

GCC_FLAGS = -Wall -Wextra -Werror

# default rule execution goes to the 'all' rule
# rules can invoke other rules by specifying them immediately
all: build

build:
	# rules can invoke shell commands by specifying an sh block
	sh
		gcc $(GCC_FLAGS) -o $(BIN) $(SRCS)

clean:
	sh
		# errors in commands will cause the makefile to stop
		# errors can be ignored by using a leading minus sign
		-rm $(BIN)
