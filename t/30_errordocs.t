use Test::More;
use Plack::Test;
use Plack::Builder;
use Plack::Middleware::TemplateToolkit;
use HTTP::Request;
use File::Spec;
use Plack::Builder;

BEGIN {
    use lib "t";
    require_ok "app_tests.pl";
}

my $root = File::Spec->catdir( "t", "root" );

app_tests
    app => Plack::Middleware::TemplateToolkit->new(
    root => $root,
    404  => '404.html',
    500  => '500.html',
    200  => 'ignore_this',
    ),
    tests => [
    {   name    => 'Basic request',
        request => [ GET => '/index.html' ],
        content => 'Page value',
        headers => { 'Content-Type' => 'text/html', },
        code    => 200
    },
    {   name    => '404 error template',
        request => [ GET => '/boom.html' ],
        content => '404-page',
        headers => { 'Content-Type' => 'text/html', },
        code    => 404,
        logged  => []
    },
    {   name    => '500 error template',
        request => [ GET => '/broken.html' ],
        content => qr/^Server error: file error - parse error/,
        headers => { 'Content-Type' => 'text/html', },
        code    => 500,
        logged  => [ { level => 'warn' } ],
    }
    ];

app_tests
    app => Plack::Middleware::TemplateToolkit->new(
    root => $root,
    404  => '404_missing.html',
    500  => '500.html',
    ),
    tests => [
    {   name    => '404 error template missing but we have 500 template',
        request => [ GET => '/boom.html' ],
        content => 'Server error: file error - 404_missing.html: not found',
        headers => { 'Content-Type' => 'text/html', },
        code    => 500,
        logged  => [ { level => 'warn' } ],
    }
    ];

app_tests
    app => Plack::Middleware::TemplateToolkit->new(
    root => $root,
    404  => '404_missing.html',
    500  => '500_missing.html',
    ),
    tests => [
    {   name => '404 error template missing and 500 error template missing',
        request => [ GET => '/boom.html' ],
        content => 'file error - 500_missing.html: not found',
        headers => { 'Content-Type' => 'text/html', },
        code    => 500,
        logged => [ { level => 'warn' } ],
    },
    {   name    => '500 error template missing',
        request => [ GET => '/broken.html' ],
        content => 'file error - 500_missing.html: not found',
        headers => { 'Content-Type' => 'text/html', },
        code    => 500,
        logged  => [
            {   level   => 'warn',
                message => qr/^file error - parse error - broken.html/
            }
        ]
    }
    ];

done_testing;
