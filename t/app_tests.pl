# package Plack::Test::App; # put this into a dedicated testing module?

# run an array of tests with expected response on an app
sub app_tests {
    my %arg = @_;

    my $app = $arg{app};

    my $run = sub {
        foreach my $test (@{$arg{tests}}) {

            pass( '---- ' . $test->{name} . ' ----' ) if $test->{name};
            my $handler = builder {
                $app;
            };

            test_psgi $handler, sub { 
                my $cb = shift;

                my $res = $cb->( HTTP::Request->new( %{$test->{request}} ) );

                if ( ref $test->{content} and ref $test->{content} eq 'Regexp' ) {
                    like( $res->content, $test->{content},
                        "Got content as expected" );
                } elsif ( $test->{content} ) {
                    is( $res->content, $test->{content},
                        "Got content as expected" );
                }

                if ( $test->{code} ) {
                    is( $res->code, $test->{code}, 
                        "Got status code as expected" );
                }

                my $h = $res->headers;

                while ( my ( $header, $value ) = each %{ $test->{headers} } )
                {
                    is $res->header($header), $value, "Header $header - ok";
                    $h->remove_header($header);
                }

                is $h->as_string, '', 'No extra headers were set';
            };
        }
    };

    if ($arg{name}) {
        subtest $arg{name} => $run;
    } else {
        $run->();
    }
}

1;
