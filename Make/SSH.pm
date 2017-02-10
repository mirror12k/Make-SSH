#!/usr/bin/env perl
package Make::SSH;
use strict;
use warnings;

use feature 'say';

use Carp;
use Net::SFTP::Foreign;
use Net::OpenSSH;

# use Data::Dumper;



=pod

=head1 Make::SSH

A build tool designed for both building and uploading/operating projects via ssh/sftp.

Uses a subset of gnu makefile syntax to allow executing sh commands locally, ssh commands remotely, and sftp upload/download.
The makefile is split up into rules which can be invoked individually from commandline.
When an error occurs in any sh command, ssh command, or sftp operation, execution of the project.make file is immediately stopped.

=head1 requirements

This module requires the following perl modules: Carp, Net::OpenSSH, Net::SFTP::Foreign.
It also requires some version of openssh client to be installed because Net::OpenSSH and Net::SFTP::Foreign piggyback on it to perform connections.
Obviously your development server needs an ssh server (and an sftp server if you are going to use sftp).

=head1 examples

see the example makefiles under example/gcc/project.make, example/php_upload/project.make, and example/devops/project.make to learn how to use it.

=cut



sub new {
	my ($class, %args) = @_;
	my $self = bless {}, $class;

	$self->{vars} = {};
	$self->{rules} = {};
	$self->{ssh_connection_cache} = {};
	# caches an ssh connections to remote servers, allows avoiding renegotiation of passwords and authetication
	$self->{cache_connections} = $args{cache_connections} // 1;

	return $self
}

sub parse_file {
	my ($self, $filepath) = @_;
	my $text;
	{ local $/; open my $file, '<', $filepath; $text = <$file>; $file->close };
	return $self->parse($text);
}

sub parse {
	my ($self, $text) = @_;

	$self->{text} = $text;
	my @lines = split /\r?\n/, $text;
	@lines = grep $_ !~ /\A\s*\Z/s, map s/\#.*\Z//sr, @lines;
	my @joined_lines;
	while (@lines) {
		my $line = shift @lines;
		while ($line =~ /\\\Z/) {
			$line = substr $line, 0, -1;
			$line .= shift (@lines) =~ s/\A\s*/ /sr;
		}
		push @joined_lines, $line;
	}

	$self->{lines} = \@joined_lines;
	$self->process;
}

sub get_line {
	my ($self) = @_;
	return unless @{$self->{lines}};
	return shift @{$self->{lines}}
}

sub get_block {
	my ($self) = @_;
	my @block;
	while (@{$self->{lines}} and $self->{lines}[0] =~ /\A\t/) {
		push @block, shift (@{$self->{lines}}) =~ s/\A\t//r;
	}
	return \@block
}

sub get_block_from_lines {
	my ($self, $lines) = @_;
	my @block;
	while (@$lines and $lines->[0] =~ /\A\t/) {
		push @block, shift (@$lines) =~ s/\A\t//r;
	}
	return \@block
}

our $identifier_expression_regex = qr/[a-zA-Z_][a-zA-Z_0-9]*/;
our $substitute_expression_regex = qr/\$\($identifier_expression_regex\)/;
our $variable_identifier_expression_regex = qr/(?:[a-zA-Z_]|$substitute_expression_regex)(?:[a-zA-Z_0-9]|$substitute_expression_regex)*/;

sub substitute_expression {
	my ($self, $expression) = @_;
	return $expression =~ s/\$\(([a-zA-Z_][a-zA-Z_0-9]*)\)/$self->{vars}{$1}/ger
}

sub process {
	my ($self) = @_;
	while (my $line = $self->get_line) {
		if ($line =~ /\A($variable_identifier_expression_regex)\s*=\s*(.*)\Z/) {
			my ($var, $expression) = ($1, $2);
			$var = $self->substitute_expression($var);
			$expression = $self->substitute_expression($expression);
			# say "got var '$var' = $expression";
			$self->{vars}{$var} = $expression;
		} elsif ($line =~ /\A($variable_identifier_expression_regex):(?:\s*(.+))?\Z/) {
			my $rule_name = $1;
			my $subrules = $2 // '';
			$rule_name = $self->substitute_expression($rule_name);
			# say "got block: '$rule_name'";
			$self->{rules}{$rule_name} = [ "rule $subrules", @{$self->get_block} ];
		} else {
			confess "unknown makefile directive: '$line'";
		}
	}
}



sub run_rule {
	my ($self, $rule) = @_;
	if (exists $self->{rules}{$rule}) {
		say "make $rule";
		$self->run_rule_block($self->{rules}{$rule});
	} else {
		croak "no such rule $rule!";
	}
}

sub run_rule_block {
	my ($self, $block_ref) = @_;
	my @block = @$block_ref;
	while (@block) {
		my $line = shift @block;
		if ($line =~ /\Asay(?:\s+(.*))?\Z/s) {
			my $arg = $self->substitute_expression($1 // '');
			say $arg;
		} elsif ($line =~ /\Awarn(?:\s+(.*))?\Z/s) {
			my $arg = $self->substitute_expression($1 // '');
			warn "warning: $arg\n";
		} elsif ($line =~ /\Adie(?:\s+(.*))?\Z/s) {
			my $arg = $self->substitute_expression($1 // '');
			die "died: $arg\n";
		} elsif ($line =~ /\Arule(?:\s+(.*))?\Z/s) {
			my $arg = $self->substitute_expression($1 // '');
			foreach my $rule (split /\s+/, $arg) {
				$self->run_rule($rule);
			}
		} elsif ($line =~ /\Aperl(?:\s+(.*))?\Z/s) {
			my $arg = $self->substitute_expression($1 // '');
			my $commands = $self->get_block_from_lines(\@block);
			$self->run_perl_block($arg, $commands);
		} elsif ($line =~ /\Ash(?:\s+(.*))?\Z/s) {
			my $arg = $self->substitute_expression($1 // '');
			my $commands = $self->get_block_from_lines(\@block);
			$self->run_sh_block($arg, $commands);
		} elsif ($line =~ /\Assh(?:\s+(.*))?\Z/s) {
			my $arg = $self->substitute_expression($1 // '');
			my $commands = $self->get_block_from_lines(\@block);
			$self->run_ssh_block($arg, $commands);
		} elsif ($line =~ /\Asftp(?:\s+(.*))?\Z/s) {
			my $arg = $self->substitute_expression($1 // '');
			my $commands = $self->get_block_from_lines(\@block);
			$self->run_sftp_block($arg, $commands);
		} else {
			confess "unknown makefile rule command: '$line'";
		}
	}
}

sub run_sh_block {
	my ($self, $args, $block) = @_;

	foreach my $command (@$block) {
		my $ignore_error = $command =~ /\A-/;
		$command =~ s/\A-//;
		$command = $self->substitute_expression($command);
		say "> $command";
		if ($command =~ /\Acd\s+(.*)\Z/) {
			unless (chdir $1) {
				die "failed to cd into '$1'\n";
			}
		} else {
			print `$command`;
			if (not $ignore_error and $? != 0) {
				die "command failed with status code " . ($? >> 8) . "\n";
			}
		}
	}
}

sub run_perl_block {
	my ($self, $args, $block) = @_;
	local $@;
	eval join "\n", map $self->substitute_expression($_), @$block;
	if ($@) {
		confess "perl blocked died with error: '$@'";
	}
}

sub run_ssh_block {
	my ($self, $args, $block) = @_;


	my %ssh_args = ();
	if ($args =~ /\A(?:([^:]+)(?::(.+))?\@)?([^\@:]+)(?::(\d+))?\Z/s) {
		$ssh_args{user} = $1 if defined $1;
		$ssh_args{password} = $2 if defined $2;
		$ssh_args{host} = $3;
		$ssh_args{port} = $4 if defined $4;
	} else {
		confess "invalid ssh argument: '$args'";
	}

	my $identification = $ssh_args{host};
	$identification = "$identification:$ssh_args{port}" if exists $ssh_args{port};
	$identification = "$ssh_args{user}\@$identification" if exists $ssh_args{user};

	my $con;
	if ($self->{cache_connections}) {
		$con = $self->connect_ssh(%ssh_args);
	} else {
		say "ssh login to $identification ...";
		$con = Net::OpenSSH->new(%ssh_args);
	}

	foreach my $command (@$block) {
		my $ignore_error = $command =~ /\A-/;
		$command =~ s/\A-//;
		$command = $self->substitute_expression($command);
		say "$identification> $command";
		$con->system($command);
		if (not $ignore_error and $? != 0) {
			die "command failed with status code " . ($? >> 8) . "\n";
		}
	}
}

sub run_sftp_block {
	my ($self, $args, $block) = @_;

	my %ssh_args;
	if ($args =~ /\A(?:([^:]+)(?::(.+))?\@)?([^\@:]+)(?::(\d+))?\Z/s) {
		$ssh_args{user} = $1 if defined $1;
		$ssh_args{password} = $2 if defined $2;
		$ssh_args{host} = $3;
		$ssh_args{port} = $4 if defined $4;
	} else {
		confess "invalid sftp argument: '$args'";
	}

	my $identification = $ssh_args{host};
	$identification = "$identification:$ssh_args{port}" if exists $ssh_args{port};
	$identification = "$ssh_args{user}\@$identification" if exists $ssh_args{user};

	my $con;
	if ($self->{cache_connections}) {
		$con = $self->connect_ssh(%ssh_args)->sftp(autodie => 1);
	} else {
		say "sftp login to $identification ...";
		$con = Net::SFTP::Foreign->new(autodie => 1, %ssh_args);
	}

	foreach my $command (@$block) {
		$command = $self->substitute_expression($command);
		say "$identification> $command";

		if ($command =~ /\Aget\s+((?:[^\s\\]|\\[\s\\])*)\s+=>\s+((?:[^\s\\]|\\[\s\\])*)\Z/) {
			my ($src, $dst) = ($1, $2);
			$src =~ s/\\(.)/$1/gs;
			$dst =~ s/\\(.)/$1/gs;
			$con->rget($src, $dst);
		} elsif ($command =~ /\Aput\s+((?:[^\s\\]|\\[\s\\])*)\s+=>\s+((?:[^\s\\]|\\[\s\\])*)\Z/) {
			my ($src, $dst) = ($1, $2);
			$src =~ s/\\(.)/$1/gs;
			$dst =~ s/\\(.)/$1/gs;
			$con->rput($src, $dst);
		} elsif ($command =~ /\Adelete\s+((?:[^\s\\]|\\[\s\\])*)\Z/) {
			my $dir = $1;
			$dir =~ s/\\(.)/$1/gs;
			$con->rremove($dir);
		} else {
			confess "invalid sftp command: '$command'";
		}
	}
}

sub connect_ssh {
	my ($self, %ssh_args) = @_;

	my $identification = $ssh_args{host};
	$identification = "$identification:$ssh_args{port}" if exists $ssh_args{port};
	$identification = "$ssh_args{user}\@$identification" if exists $ssh_args{user};

	unless (exists $self->{ssh_connection_cache}{$identification}) {
		say "ssh login to $identification ...";
		my $con = Net::OpenSSH->new(%ssh_args);
		$self->{ssh_connection_cache}{$identification} = $con;
	}

	return $self->{ssh_connection_cache}{$identification}
}



sub main {
	my ($rule) = @_;
	$rule = $rule // 'all';

	my $parser = Make::SSH->new;
	$parser->parse_file('project.make');

	$parser->run_rule($rule);
}

caller or main(@ARGV);
