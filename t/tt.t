use Test::More;
use Plack::Test;
use Plack::Builder;
use Plack::App::TemplateToolkit;
use HTTP::Request;
use Path::Class;

my $root = dir( file($0)->dir(), 'root' )->stringify();

my $app = Plack::App::TemplateToolkit->new(
    root => $root,    # Required
)->to_app();

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

);

foreach my $test (@tests) {

    pass( '---- ' . $test->{name} . ' ----' );
    my $handler = builder {
        $app;
    };

    test_psgi
        app    => $handler,
        client => sub {
        my $cb = shift;

        my $req = HTTP::Request->new( $test->{request_method},
            $test->{request_url} );
        my $res = $cb->($req);

        if ( $test->{content} ) {
            is( $res->content(), $test->{content},
                "Got content as expected" );
        }

        my $h = $res->headers();

        while ( my ( $header, $value ) = each %{ $test->{headers_out} } ) {
            is $res->header($header), $value, "Header $header - ok";
            $h->remove_header($header);
        }

        is $h->as_string, '', 'No extra headers were set';

        };

}

done_testing;
