#!/usr/bin/env perl

# This app.psgi is for testing slightly more complex configurations

use strict;
use warnings;
use lib qw(lib);

use Plack::App::Cascade;
use Plack::App::TemplateToolkit;
use Plack::App::URLMap;
use Plack::Builder;
use Plack::Middleware::ErrorDocument;
use Plack::Middleware::Static;
use File::Spec;
use File::Basename;

my $root = Cwd::realpath( File::Spec->catdir( dirname($0), "t","root") );

# Create our TT app, specifying the root and file extensions
my $tt_app = Plack::App::TemplateToolkit->new(
    root      => $root,      # required
    extension => '.html',    # optional
)->to_app;

# Create a cascade
my $cascade = Plack::App::Cascade->new;

# You could have your own app
# $cascade->add($app);
# Fall back to the TT app
$cascade->add($tt_app);

my $urlmap = Plack::App::URLMap->new;
$urlmap->map( "/" => $cascade );

my $app = $urlmap->to_app;

$app = Plack::Middleware::ErrorDocument->wrap( $app,
    404 => "$root/page_not_found.html", );

# Binary files can be served directly
$app = Plack::Middleware::Static->wrap(
    $app,
    path => qr{[gif|png|jpg|swf|ico|mov|mp3|pdf|js|css]$},
    root => $root
);

# Plack::Middleware::Deflater might be good to use here

return builder {
    $app;
}
