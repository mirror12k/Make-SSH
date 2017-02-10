#!/usr/bin/env perl
package Sugar::IO::Dir;
use strict;
use warnings;

use feature 'say';

use Carp;
use IO::Dir;
use Cwd 'abs_path';

use Sugar::IO::File;

use overload '""' => 'path';


=pod

=head1 what is Sugar::IO::Dir?

sugar module for easily working with directories,
caches results to allow for irresponsible programming

=head2 Sugar::IO::Dir->new($path)

returns a new Sugar::IO::Dir object with a given path

=head2 $dir->path / $dir->as_string / "$dir"

return string path to the directory that this represents

=head2 $dir->simplify

return a new directory object with the path component stripped of redundant tokens

=head2 $dir->abs_dir

return a new directory object with the path converted to an absolute path (and simplified)

=head2 $dir->list

returns a list of Sugar::IO::File and Sugar::IO::Dir objects representing the contents of the directory

=head2 $dir->files

returns a list of Sugar::IO::File objects representing the files in the directory

=head2 $dir->dirs

returns a list of Sugar::IO::Dir objects representing the sub-directories in the directory

=head2 $dir->recursive_files

returns a list of Sugar::IO::File objects representing all files in the directory and all sub-directories

=head2 $dir->file($name)

safely checks that a file exists in the given directory with the given name, and returns a Sugar::IO::File representing it.
croaks if the name is invalid or the file doesn't exist (or isn't a file)

=head2 $dir->new_file($name)

safely checks that a file doesn't exists in the given directory with the given name, and returns a Sugar::IO::File representing it.
croaks if the name is invalid or the file already exists

=head2 $dir->dir($name)

safely checks that a sub-directory exists in the given directory with the given name, and returns a Sugar::IO::Dir representing it.
croaks if the name is invalid or the dir doesn't exist (or isn't a directory)

=head2 $dir->new_dir($name)

safely checks that a sub-directory doesn't exist in the given directory with the given name, and returns a Sugar::IO::Dir representing it.
croaks if the name is invalid or the dir already exists

=head2 $dir->read_directory

use to refresh a directory listing

=cut



sub new {
	my ($class, $path) = @_;
	croak "path argument required" unless defined $path;

	my $self = bless {}, $class;
	$self->{directory_path} = $path;

	return $self
}



sub path { return $_[0]{directory_path} }
sub as_string { return $_[0]->path }

sub exists {
	my ($self) = @_;
	return -e -d $self->{directory_path}
}



sub name {
	my ($self) = @_;
	my $path = $self->{directory_path};
	croak "invalid directory_path '$path'" unless $path =~ /([^\/]+)\/?$/m;
	return $1
}



sub simplify {
	my ($self) = @_;
	my $path = $self->path;

	$path =~ s#^\./(?!$)##;
	$path =~ s#//#/#g while $path =~ m#//#;
	$path =~ s#/./#/#g while $path =~ m#/./#;
	while ($path =~ m#(/|^)(?!\.\.)[^/]+/\.\.(/|$)#) {
		$path =~ s#(/|^)(?!\.\.)[^/]+/\.\.(/|$)#$1#g ;
	}
	$path =~ s#(?<!^)/$##;

	return $self if $path eq $self->path;
	return Sugar::IO::Dir->new($path)
}


sub abs_dir {
	my ($self) = @_;
	my $path = abs_path $self->path;

	return $self if $path eq $self->path;
	return Sugar::IO::Dir->new($path)
}




sub read_directory {
	my ($self) = @_;

	my $dir = IO::Dir->new($self->path);
	croak "invalid directory '" . $self->path . "'" unless defined $dir;

	my @items;
	my $file;
	push @items, $file while defined ($file = $dir->read);
	$dir->close;

	$self->{directory_items} = [ grep { $_ ne '.' and $_ ne '..' } @items ];
	$self->{directory_files} = undef;
	$self->{directory_subdirectories} = undef;
}

sub list {
	my ($self) = @_;
	return $self->files, $self->dirs
}

sub files {
	my ($self) = @_;
	$self->read_directory unless defined $self->{directory_items};
	$self->{directory_files} = [ map Sugar::IO::File->new($self->path . "/$_"), grep -f $self->path . "/$_", @{$self->{directory_items}} ]
		unless defined $self->{directory_files};
	return @{$self->{directory_files}}
}

sub dirs {
	my ($self) = @_;
	$self->read_directory unless defined $self->{directory_items};
	$self->{directory_subdirectories} = [ map Sugar::IO::Dir->new($self->path . "/$_"), grep -d $self->path . "/$_", @{$self->{directory_items}} ]
		unless defined $self->{directory_subdirectories};
	return @{$self->{directory_subdirectories}}
}

sub recursive_files {
	my ($self) = @_;
	my @paths = ($self);

	my @ret;
	while (@paths) {
		my @new_paths;
		foreach my $path (@paths) {
			push @ret, $path->files;
			push @new_paths, $path->dirs;
		}
		@paths = @new_paths;
	}
	
	return @ret
}



sub file {
	my ($self, $name) = @_;
	croak "invalid filename '$name'" if $name =~ m#/# or $name eq '..' or $name eq '.';

	my $file = Sugar::IO::File->new($self->path . "/$name");
	croak "missing file '$file'" unless $file->exists;

	return $file
}

sub new_file {
	my ($self, $name) = @_;
	croak "invalid filename '$name'" if $name =~ m#/# or $name eq '..' or $name eq '.';

	my $file = Sugar::IO::File->new($self->path . "/$name");
	croak "file already exists '$file'" if $file->exists;

	return $file
}

sub dir {
	my ($self, $name) = @_;
	croak "invalid directory name '$name'" if $name =~ m#/# or $name eq '..' or $name eq '.';

	my $dir = Sugar::IO::Dir->new($self->path . "/$name");
	croak "missing directory '$dir'" unless $dir->exists;

	return $dir
}

sub new_dir {
	my ($self, $name) = @_;
	croak "invalid directory name '$name'" if $name =~ m#/# or $name eq '..' or $name eq '.';

	my $dir = Sugar::IO::Dir->new($self->path . "/$name");
	croak "directory already exists '$dir'" if $dir->exists;

	return $dir
}




sub mk {
	my ($self) = @_;
	croak "attempt to make directory which already exists: '" . $self->path . "'" if $self->exists;

	mkdir $self->path
}

sub rm {
	my ($self) = @_;
	croak "attempt to rm directory which doesn't exist: '" . $self->path . "'" unless $self->exists;

	foreach my $file ($self->files) {
		$file->rm;
	}
	foreach my $dir ($self->dirs) {
		$dir->rm;
	}

	rmdir $self->path
}




1;
