use Test::More;
use Plack::Test;
use Plack::Builder;
use Plack::App::TemplateToolkit;
use HTTP::Request;
use File::Spec;
use Plack::Middleware::ErrorDocument;

my $root = File::Spec->catdir("t","root");

my $app = Plack::App::TemplateToolkit->new(
    root => $root,    # Required
)->to_app();

$app = Plack::Middleware::ErrorDocument->wrap( $app,
    404 => "$root/page_not_found.html", );

my @tests = (
    {   name           => 'Basic request',
        request_method => 'GET',
        request_url    => '/index.html',
        content        => 'Page value',
        headers_out    => { 'Content-Type' => 'text/html', },
    },
    {   name           => 'Index request',
        request_method => 'GET',
        request_url    => '/',
        content        => 'Page value',
        headers_out    => { 'Content-Type' => 'text/html', },
    },
    {   name           => '404request',
        request_method => 'GET',
        request_url    => '/boom.html',
        content        => '404-page',
        headers_out    => { 'Content-Type' => 'text/html', },
    },
    {   name           => 'MIME type by extension',
        request_method => 'GET',
        request_url    => '/style.css',
        content        => 'body { font-style: sans-serif; }',
        headers_out    => { 'Content-Type' => 'text/css', },
    },
    {   name           => 'No extension',
        request_method => 'GET',
        request_url    => '/noext',
        content        => 'What am I?',
        headers_out    => { 'Content-Type' => 'text/html', },
    },
);

run_tests( $app, \@tests );

{
    my @pre_tests = (
        {   name           => 'Basic request with pre_process',
            request_method => 'GET',
            request_url    => '/index.html',
            content        => 'Included Page value',
            headers_out    => { 'Content-Type' => 'text/html', },
        },
    );

    my $app_pre = Plack::App::TemplateToolkit->new(
        root        => $root,       # Required
        pre_process => 'pre.html'
    )->to_app();

    run_tests( $app_pre, \@pre_tests );
}

{
    my @process_tests = (
        {   name           => 'Basic request with pre_process',
            request_method => 'GET',
            request_url    => '/index.html',
            content        => 'The Page value here',
            headers_out    => { 'Content-Type' => 'text/html', },
        },
    );

    my $app_pro = Plack::App::TemplateToolkit->new(
        root        => $root,       # Required
        process => 'process.html'
    )->to_app();

    run_tests( $app_pro, \@process_tests );
}

{
    my @mime_tests = (
        {   name           => 'Default MIME type',
            request_method => 'GET',
            request_url    => '/noext',
            content        => 'What am I?',
            headers_out    => { 'Content-Type' => 'text/plain', },
        },
    );

    my $app = Plack::App::TemplateToolkit->new(
        root         => $root, 
        default_type => 'text/plain'
    )->to_app();

    run_tests( $app, \@mime_tests );
}

sub run_tests {
    my ( $app, $tests ) = @_;

    foreach my $test (@$tests) {

        pass( '---- ' . $test->{name} . ' ----' );
        my $handler = builder {
            $app;
        };

        test_psgi $handler, sub { 
            my $cb = shift;

            my $req = HTTP::Request->new( $test->{request_method},
                $test->{request_url} );
            my $res = $cb->($req);

            if ( $test->{content} ) {
                is( $res->content(), $test->{content},
                    "Got content as expected" );
            }

            my $h = $res->headers();

            while ( my ( $header, $value ) = each %{ $test->{headers_out} } )
            {
                is $res->header($header), $value, "Header $header - ok";
                $h->remove_header($header);
            }

            is $h->as_string, '', 'No extra headers were set';

            };
    }
}

done_testing;
