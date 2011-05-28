use Test::More;
use Plack::Test;
use Plack::Builder;
use Plack::Middleware::Template;
use HTTP::Request;
use File::Spec;
use Plack::Middleware::ErrorDocument;
use Plack::Builder;

my $root = File::Spec->catdir("t","root");

my $err = sub { [ 500, ["Content-type"=>"text/plain"], ["Server hit the bottom"] ] };

my $app = builder {
  enable "Plack::Middleware::Template", root => $root, pass_through => 1;
  $err;
};

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
        content        => 'Server hit the bottom',
        headers_out    => { 'Content-Type' => 'text/plain', },
    },
);

run_tests( $app, \@tests );

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
