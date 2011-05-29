use Test::More;
use Plack::Test;
use Plack::Builder;
use Plack::Middleware::Template;
use HTTP::Request;
use File::Spec;
use Plack::Middleware::ErrorDocument;

BEGIN {
    use lib "t";
    require_ok "app_tests.pl"; 
}

my $root = File::Spec->catdir("t","root");

my $app = Plack::Middleware::Template->new(
    root => $root,    # Required
)->to_app();

$app = Plack::Middleware::ErrorDocument->wrap( $app,
    404 => "$root/page_not_found.html", );

app_tests
    app => $app,
    tests => [{
        name    => 'Basic request',
        request => { GET => '/index.html' },
        content => 'Page value',
        headers => { 'Content-Type' => 'text/html', },
    },{
        name    => 'Index request',
        request => { GET => '/' },
        content => 'Page value',
        headers => { 'Content-Type' => 'text/html', },
    },{
        name    => '404request',
        request => { GET => '/boom.html' },
        content => '404-page',
        headers => { 'Content-Type' => 'text/html', },
    },{
        name    => 'MIME type by extension',
        request => { GET => '/style.css' },
        content => 'body { font-style: sans-serif; }',
        headers => { 'Content-Type' => 'text/css', },
    },{
        name    => 'No extension',
        request => { GET => '/noext' },
        content => 'What am I?',
        headers => { 'Content-Type' => 'text/html', },
    }];

app_tests
    app => Plack::Middleware::Template->new(
            root        => $root,
            pre_process => 'pre.html'
        )->to_app(),
    tests => [{ 
        name    => 'Basic request with pre_process',
        request => { GET => '/index.html' },
        content => 'Included Page value',
        headers => { 'Content-Type' => 'text/html', },
    }];

app_tests
    app => Plack::Middleware::Template->new(
            root    => $root,
            process => 'process.html'
        )->to_app(),
    tests => [{
        name    => 'Basic request with pre_process',
        request => { GET => '/index.html' },
        content => 'The Page value here',
        headers => { 'Content-Type' => 'text/html', },
    }];

app_tests
    app => Plack::Middleware::Template->new(
            root         => $root, 
            default_type => 'text/plain'
        )->to_app(),
    tests => [{
        name    => 'Default MIME type',
        request => { GET => '/noext' },
        content => 'What am I?',
        headers => { 'Content-Type' => 'text/plain', },
    }];

done_testing;
