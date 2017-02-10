#!/usr/bin/env perl
package Sugar::IO::Archive;
use strict;
use warnings;

use feature 'say';

use Carp;
use Archive::Zip;

use Sugar::IO::File;



sub new {
	my ($class, $path, $type) = @_;
	croak "path argument required" unless defined $path;

	my $self = bless {}, $class;

	$self->{archive_handlers} = {
		zip => {
			init => 'init_zip_archive',
			list => 'list_zip_archive',
			extract => 'extract_zip_archive',
		},
	};
	$self->{archive_path} = $path;
	$self->{archive_type} = $type // $self->infer_archive_type;

	$self->init;

	return $self
}



sub path { return $_[0]{archive_path} }
sub type { return $_[0]{archive_type} }
sub as_string { return $_[0]->path }
sub as_file {
	my ($self) = @_;
	return Sugar::IO::File->new($self->path)
}



sub infer_archive_type {
	my ($self) = @_;

	return 'zip' if $self->{archive_path} =~ /\.(zip|jar)$/i;
	confess "unknown archive type '$self->{archive_path}'";
}

sub init {
	my ($self) = @_;

	carp "undefined archive handlers for archive type '$self->{archive_type}'"
		unless exists $self->{archive_handlers}{$self->type} and exists $self->{archive_handlers}{$self->type}{init};

	my $func = $self->{archive_handlers}{$self->type}{init};
	$self->$func();
}

sub list {
	my ($self) = @_;

	carp "undefined archive handlers for archive type '$self->{archive_type}'"
		unless exists $self->{archive_handlers}{$self->type} and exists $self->{archive_handlers}{$self->type}{list};

	my $func = $self->{archive_handlers}{$self->type}{list};
	return $self->$func()
}

sub extract {
	my ($self, $destination, @files) = @_;
	croak "destination required" unless defined $destination;
	$destination = "$destination";
	@files = $self->list unless @files;

	carp "undefined archive handlers for archive type '$self->{archive_type}'"
		unless exists $self->{archive_handlers}{$self->type} and exists $self->{archive_handlers}{$self->type}{extract};

	my $func = $self->{archive_handlers}{$self->type}{extract};
	$self->$func($destination, @files);
}










sub init_zip_archive {
	my ($self) = @_;

	my $arc = Archive::Zip->new;
	my $status = $arc->read($self->{archive_path});
	die "failed to open zip archive: $status" unless $status == 0;

	$self->{zip_archive} = $arc;
}


sub list_zip_archive {
	my ($self) = @_;

	return map $_->fileName, grep { not $_->isDirectory } $self->{zip_archive}->members
}


sub extract_zip_archive {
	my ($self, $destination, @files) = @_;
	foreach my $file (@files) {
		my $res = $self->{zip_archive}->extractMember($file, "$destination/$file");
		if ($res != 0) {
			die "error extracting '$file': $res";
		}
	}
}



1;
