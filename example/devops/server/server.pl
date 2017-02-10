#!/usr/bin/env perl
use strict;
use warnings;

use Quartz::Server;
use Quartz::Amethyst;




my $server = Quartz::Server->new;
$server->route('/.*' => amethyst_directory(route => '/', directory => 'www'));
$server->start;



