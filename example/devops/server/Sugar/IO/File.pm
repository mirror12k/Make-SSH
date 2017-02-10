#!/usr/bin/env perl
package Sugar::IO::File;
use strict;
use warnings;

use feature 'say';

use Carp;
use IO::Dir;

use overload '""' => 'path';


use Sugar::IO::Archive;



=pod

=head1 what is Sugar::IO::File?

a sugar module for easily working with files

=head2 Sugar::IO::File->new($path)

returns a new Sugar::IO::File object with a given path

=head2 $file->path / $file->as_string / "$file"

return string path to the directory that this represents

=head2 $file->exists

return true if a file already exists with the given path

=head2 $file->read

return a string containing all of the file's contents

=head2 $file->readlines

return a list of strings containing all of the file's contents as lines (newlines removed)

=head2 $file->append($data)

writes the given data to the end of the file (creating it if it doesn't exist, but preserving any existing content)

=head2 $file->write($data)

writes the given data to the file (creating it if it doesn't exist, or erasing any previous contents if it does)



=cut


sub new {
	my ($class, $path) = @_;
	croak "path argument required" unless defined $path;

	my $self = bless {}, $class;
	$self->{file_path} = "$path";

	return $self
}



sub path { return $_[0]{file_path} }
sub as_string { return $_[0]->path }



sub exists {
	my ($self) = @_;
	return -e -f $self->{file_path}
}
sub as_archive {
	my ($self) = @_;
	return Sugar::IO::Archive->new($self->path)
}



sub name {
	my ($self) = @_;
	my $path = $self->{file_path};
	croak "invalid file_path '$path'" unless $path =~ /([^\/]+)\/?$/m;
	return $1
}



sub read {
	my ($self) = @_;
	croak "attempt to read non-existant file " . $self->path unless $self->exists;

	my $data;
	{ local $/; open my $file, "<", "$self->{file_path}" or return; $data = <$file>; close $file }
	return $data
}

sub readlines {
	my ($self) = @_;
	croak "attempt to read non-existant file " . $self->path unless $self->exists;
	
	my $file = IO::File->new($self->{file_path}, 'r');
	my @data = map s/\r?\n$//r, $file->getlines;
	$file->close;

	return @data
}

sub write {
	my ($self, $data) = @_;

	my $file = IO::File->new($self->{file_path}, 'w');
	$file->print($data);
	$file->close;
}

sub append {
	my ($self, $data) = @_;

	my $file = IO::File->new($self->{file_path}, 'a');
	$file->print($data);
	$file->close;
}


sub rm {
	my ($self) = @_;

	croak "attempt to rm non-existant file " . $self->path unless $self->exists;
	unlink $self->{file_path}
}






1;

