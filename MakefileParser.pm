package MakefileParser;
use strict;
use warnings;

use feature 'say';

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
			say "got var '$var' = $expression";
			$self->{vars}{$var} = $expression;
		} elsif ($line =~ /\A($variable_identifier_expression_regex):\Z/) {
			my $var = $1;
			$var = $self->substitute_expression($var);
			say "got block: '$var'";
			$self->{rules}{$var} = $self->get_block;
		}
	}
}



my $parser = MakefileParser->new;
$parser->parse_file('test.make');
say Dumper $parser->{vars};
say Dumper $parser->{rules};
