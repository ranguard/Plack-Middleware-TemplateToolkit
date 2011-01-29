#!/usr/bin/env perl

use strict;
use warnings;
use lib qw(lib);
use Plack::Builder;

my $app = sub {
    return [ 200, [ 'Content-Type' => 'text/plain' ], ["DEFAULT"] ];
};

builder {
    enable "Plack::Middleware::TemplateToolkit",
        root => '/tmp',
        # path       => '/tt/',
        extension => '.tt';
    $app;
};
