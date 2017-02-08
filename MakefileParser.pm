package MakefileParser;
use strict;
use warnings;

use feature 'say';

use Data::Dumper;



sub new {
	my ($class, %args) = @_;
	my $self = bless {}, $class;

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

	foreach my $line (@joined_lines) {
		say $line
	}
}



my $parser = MakefileParser->new;
$parser->parse_file('test.make');
