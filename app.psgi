#!/usr/bin/env perl

use strict;
use warnings;
use lib qw(lib);
use Plack::App::Cascade;
use Plack::Builder;
use Plack::Middleware::Static;
use Plack::Middleware::ErrorDocument;
use Plack::Middleware::TemplateToolkit;

my $root = '/Users/leo/svn/london-pm/LPM/root';

# Just to show you can build up layers, 
my $another_app = sub {
    return [ 200, [ 'Content-Type' => 'text/plain' ], ["You should not be here"] ];
};

my $tt_app = Plack::Middleware::TemplateToolkit->new(
    root => $root,
    extension => '.html'
)->to_app;

my $cascade = Plack::App::Cascade->new;
$cascade->add($tt_app);
# $cascade->add($another_app);

my $app = builder {
    mount '/' => $cascade;
};

$app = Plack::Middleware::ErrorDocument->wrap(
    $app,
    404 => "/page_not_found.html",
    subrequest => 1
);

$app = Plack::Middleware::Static->wrap(
    $app,
    path => qr{[jpg|gif|jpeg|css|js|ico]$},
    root => $root
);

builder {
    $app;
}
