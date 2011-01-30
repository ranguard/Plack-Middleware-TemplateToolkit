use Test::More;
use Plack::Test;
use Plack::Builder;
use Plack::App::TemplateToolkit;
use HTTP::Request;

my $app = sub {
    return [ 200, [ 'Content-Type' => 'text/plain' ], ["DEFAULT"] ];
};

my @tests = (
    {   name           => 'Basic request',
        request_method => 'GET',
        request_url    => '/foo',
        app            => $default_app,
        options        => {
            root => '/tmp/',
        },
        headers_out    => {
            'Content-Type'      => 'text/html',
        },
    },

);

foreach my $test (@tests) {

    pass( '---- ' . $test->{name} . ' ----' );
    my $handler = builder {
        enable "Plack::App::TemplateToolkit",
            %{ $test->{options} };
        $app;
    };

    test_psgi
        app    => $handler,
        client => sub {
        my $cb = shift;

        my $req = HTTP::Request->new( $test->{request_method},
            $test->{request_url} );
        my $res = $cb->($req);

        my $h = $res->headers();

        while ( my ( $header, $value ) = each %{ $test->{headers_out} } ) {
            is $res->header($header), $value, "Header $header - ok";
            $h->remove_header($header);
        }

        is $h->as_string, '', 'No extra headers were set';

        };

}

done_testing;
