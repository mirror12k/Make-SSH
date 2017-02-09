#!/usr/bin/env perl
use strict;
use warnings;

use feature 'say';

use LWP::UserAgent;



my $url = shift // die 'remote url required!';

my $ua = LWP::UserAgent->new;
my $content = $ua->get($url)->content;

die "content '$content' doesnt match expected!" unless $content eq 'hello world!';


say "all tests good!";
