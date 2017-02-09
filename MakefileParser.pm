package MakefileParser;
use strict;
use warnings;

use feature 'say';

use Carp;
use Net::SFTP::Foreign;

use Data::Dumper;





sub new {
	my ($class, %args) = @_;
	my $self = bless {}, $class;

	$self->{vars} = {};
	$self->{rules} = {};

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
		} elsif ($line =~ /\A($variable_identifier_expression_regex):\Z/) {
			my $var = $1;
			$var = $self->substitute_expression($var);
			# say "got block: '$var'";
			$self->{rules}{$var} = $self->get_block;
		} else {
			confess "unknown makefile directive: '$line'";
		}
	}
}

sub run_rule {
	my ($self, $rule) = @_;
	if (exists $self->{rules}{$rule}) {
		$self->run($self->{rules}{$rule});
	} else {
		croak "no such rule $rule!";
	}
}

sub run {
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
		} elsif ($line =~ /\Ash(?:\s+(.*))?\Z/s) {
			my $arg = $self->substitute_expression($1 // '');
			my $commands = $self->get_block_from_lines(\@block);
			$self->run_sh_block($arg, $commands);
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
		say "$command";
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

sub run_sftp_block {
	my ($self, $args, $block) = @_;

	my %sftp_args = (
		autodie => 1,
	);
	if ($args =~ /\A(.+):(.+)\@([^\@]+)\Z/s) {
		$sftp_args{user} = $1;
		$sftp_args{password} = $2;
		$sftp_args{host} = $3;
	} elsif ($args =~ /\A(.+)\@([^\@]+)\Z/s) {
		$sftp_args{user} = $1;
		$sftp_args{host} = $2;
	} else {
		confess "invalid sftp argument: '$args'";
	}

	say "sftp login to $sftp_args{user}\@$sftp_args{host} ...";
	my $con = Net::SFTP::Foreign->new(%sftp_args);
	foreach my $command (@$block) {
		$command = $self->substitute_expression($command);
		say "$sftp_args{user}\@$sftp_args{host}> $command";
		if ($command =~ /\Aget\s+((?:[^\s]|\\\s)*)\s+=>\s+((?:[^\s]|\\\s)*)\Z/) {
			my ($src, $dst) = ($1, $2);
			$src =~ s/\\(.)/$1/gs;
			$dst =~ s/\\(.)/$1/gs;
			$con->get($src, $dst);
		} elsif ($command =~ /\Arget\s+((?:[^\s\\]|\\[\s\\])*)\s+=>\s+((?:[^\s\\]|\\[\s\\])*)\Z/) {
			my ($src, $dst) = ($1, $2);
			$src =~ s/\\(.)/$1/gs;
			$dst =~ s/\\(.)/$1/gs;
			$con->rget($src, $dst);
		} elsif ($command =~ /\Aput\s+((?:[^\s\\]|\\[\s\\])*)\s+=>\s+((?:[^\s\\]|\\[\s\\])*)\Z/) {
			my ($src, $dst) = ($1, $2);
			$src =~ s/\\(.)/$1/gs;
			$dst =~ s/\\(.)/$1/gs;
			$con->put($src, $dst);
		} elsif ($command =~ /\Arput\s+((?:[^\s\\]|\\[\s\\])*)\s+=>\s+((?:[^\s\\]|\\[\s\\])*)\Z/) {
			my ($src, $dst) = ($1, $2);
			$src =~ s/\\(.)/$1/gs;
			$dst =~ s/\\(.)/$1/gs;
			$con->rput($src, $dst);
		} elsif ($command =~ /\Aremove\s+((?:[^\s\\]|\\[\s\\])*)\Z/) {
			my $dir = $1;
			$dir =~ s/\\(.)/$1/gs;
			$con->remove($dir);
		} elsif ($command =~ /\Arremove\s+((?:[^\s\\]|\\[\s\\])*)\Z/) {
			my $dir = $1;
			$dir =~ s/\\(.)/$1/gs;
			$con->rremove($dir);
		} else {
			confess "invalid sftp command: '$command'";
		}
	}
}



my $parser = MakefileParser->new;
$parser->parse_file('test.make');
say Dumper $parser->{vars};
say Dumper $parser->{rules};

my $rule = shift // die "no rule specified";
$parser->run_rule($rule);
