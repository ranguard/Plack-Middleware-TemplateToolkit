#!/usr/bin/env perl

use strict;
use warnings;
use lib qw(lib);
use Plack::App::Cascade;
use Plack::Builder;
use Plack::Middleware::Static;
use Plack::Middleware::ErrorDocument;
use Plack::App::TemplateToolkit;

my $root = '/Users/leo/svn/london-pm/LPM/root';

# Just to show that we can cascade to another bespoke app:
my $restriced_app = sub {
    my $env = shift;
    if ( $env->{PATH_INFO} eq '/test_403' ) {
        return [
            403, [ 'Content-Type' => 'text/plain' ],
            ["You should not be here"]
        ];
    } else {

        # Let something else handle it
        return [ 404, [], [] ];
    }
};

# Create our TT app, specifying the root and file extensions
my $tt_app = Plack::App::TemplateToolkit->new(
    root      => $root,      # required
    extension => '.html',    # optional
)->to_app;

# Create a cascade
my $cascade = Plack::App::Cascade->new;
$cascade->add($tt_app);
$cascade->add($restriced_app);

my $app = builder {
    mount '/' => $cascade;
};

$app = Plack::Middleware::ErrorDocument->wrap(
    $app,

    # Does not work????
    404        => "/page_not_found.html",
    subrequest => 1
);

# Binary files can be served directly
$app = Plack::Middleware::Static->wrap(
    $app,
    path => qr{[gif|png|jpg|swf|ico|mov|mp3|pdf]$},
    root => $root
);

# So can .js and .css files
$app = Plack::Middleware::Static->wrap(
    $app,
    path => qr{[js|css]$},
    root => $root
);


# Plack::Middleware::Deflater might be good to use here

builder {
    $app;
}
