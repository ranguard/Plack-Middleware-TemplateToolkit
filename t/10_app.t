use Test::More;
use Plack::Test;
use Plack::Builder;
use Plack::Middleware::TemplateToolkit;
use HTTP::Request;
use File::Spec;
use Plack::Middleware::ErrorDocument;
use Template;

BEGIN {
    use lib "t";
    require_ok "app_tests.pl";
}

my $root = File::Spec->catdir( "t", "root" );

my $app = Plack::Middleware::TemplateToolkit->new(
    INCLUDE_PATH => $root,
    POST_CHOMP   => 1
)->to_app();

$app = Plack::Middleware::ErrorDocument->wrap( $app, 404 => "$root/404.html" );

app_tests
    app   => $app,
    tests => [
    {   name    => 'Basic request',
        request => [ GET => '/index.html' ],
        content => 'Page value',
        headers => { 'Content-Type' => 'text/html', },
    },
    {   name    => 'Index request',
        request => [ GET => '/' ],
        content => 'Page value',
        headers => { 'Content-Type' => 'text/html', },
    },
    {   name    => '404request',
        request => [ GET => '/boom.html' ],
        content => '404-page',
        headers => { 'Content-Type' => 'text/html', },
        code    => 404
    },
    {   name    => 'MIME type by extension',
        request => [ GET => '/style.css' ],
        content => 'body { font-style: sans-serif; }',
        headers => { 'Content-Type' => 'text/css', },
    },
    {   name    => 'No extension',
        request => [ GET => '/noext' ],
        content => 'What am I?',
        headers => { 'Content-Type' => 'text/html', },
    },
    {   name    => 'broken template',
        request => [ GET => '/broken.html' ],
        content => qr/^file error - parse error/,
        headers => { 'Content-Type' => 'text/html', },
        code    => 500
    }
    ];

app_tests
    app => Plack::Middleware::TemplateToolkit->new(
        INCLUDE_PATH => $root, POST_CHOMP => 1,
        path         => qr{^/ind},
    ),
    tests => [{
        name    => 'Basic request',
        request => [ GET => '/index.html' ],
        content => 'Page value',
        headers => { 'Content-Type' => 'text/html', },
    },{   
        name    => 'Unmatched request',
        request => [ GET => '/style.css' ],
        code    => 404,
    }];

app_tests
    app => Plack::Middleware::TemplateToolkit->new(
        INCLUDE_PATH => $root,
        PRE_PROCESS  => 'pre.html',
        POST_CHOMP   => 1
    )->to_app(),
    tests => [
    {   name    => 'Basic request with pre_process',
        request => [ GET => '/index.html' ],
        content => 'Included Page value',
        headers => { 'Content-Type' => 'text/html', },
    }
    ];

app_tests
    app => Plack::Middleware::TemplateToolkit->new(
        INCLUDE_PATH => $root,
        PROCESS      => 'process.html',
        POST_CHOMP   => 1
    )->to_app(),
    tests => [
    {   name    => 'Basic request with pre_process',
        request => [ GET => '/index.html' ],
        content => 'The Page value here',
        headers => { 'Content-Type' => 'text/html', },
    }
    ];

app_tests
    app => Plack::Middleware::TemplateToolkit->new(
        INCLUDE_PATH => $root,
        default_type => 'text/plain'
    )->to_app(),
    tests => [
    {   name    => 'Default MIME type',
        request => [ GET => '/noext' ],
        content => 'What am I?',
        headers => { 'Content-Type' => 'text/plain', },
    }
    ];

app_tests
    app => Plack::Middleware::TemplateToolkit->new(
        INCLUDE_PATH => $root,
        extension => 'html'
    )->to_app(),
    tests => [
    {   name    => 'Forbidden extension',
        request => [ GET => '/style.css' ],
        content => 'Not found',
        headers => { 'Content-Type' => 'text/plain', },
        code    => 404
    }
    ];

app_tests
    app => Plack::Middleware::TemplateToolkit->new(
        INCLUDE_PATH => $root,
        vars => { foo => 'Hello', bar => ', world!' }
    )->to_app(),
    tests => [
    {   name    => 'Variables in templates',
        request => [ GET => '/vars.html' ],
        content => 'Hello, world!',
    }
    ];

my $template = Template->new( INCLUDE_PATH => $root );

app_tests 
    app => Plack::Middleware::TemplateToolkit->new(
        tt   => $template,
        vars => sub {
            my $req = shift;
            return { foo => 'Hi, ', bar => $req->param('who') };
        }
    ),
    tests => [{   
        name    => 'Variables in templates',
        request => [ GET => '/vars.html?who=you' ],
        content => 'Hi, you',
    }];

$app = Plack::Middleware::TemplateToolkit->new(
    INCLUDE_PATH => $root, POST_CHOMP => 1 );

app_tests 
    app => builder {
        enable sub { my $app = shift; sub { 
            my $env = shift;
            # test for empty PATH_INFO
            $env->{PATH_INFO} = '' if $env->{PATH_INFO} eq '/index.html'; 
            $app->($env);
        } };
        $app;
    },
    tests => [{
        name    => 'use as plain app',
        request => [ GET => '/index.html' ],
        content => 'Page value',
        code    => 200,
    }];

app_tests 
    app => builder {
        enable sub { my $app = shift; sub { 
            my $env = shift;
            $env->{'tt.vars'} = { bar => 'Do' };
            $app->($env);
        } };
        $app;
    },
    tests => [{
        name    => 'with mixed variable sources',
        request => [ GET => '/vars.html?foo=Ho' ],
        content => 'HoDo',
        code    => 200,
    }];

done_testing;
