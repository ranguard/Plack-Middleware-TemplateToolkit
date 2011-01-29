package Plack::Middleware::TemplateToolkit;
use strict;
use warnings;

use parent qw( Plack::Middleware );
use Plack::Request;
use Template;

our $VERSION = 0.01;

use Plack::Util::Accessor qw( root path extension content_type tt);

sub prepare_app {
    my ($self) = @_;

    die "No root supplied" unless $self->root();

    $self->content_type('text/html') unless $self->content_type();

    my $config = {
        INCLUDE_PATH => $self->root(),    # or list ref
        INTERPOLATE  => 1,                # expand "$var" in plain text
        POST_CHOMP   => 1,                # cleanup whitespace
        EVAL_PERL    => 1,                # evaluate Perl code blocks
    };

    # create Template object
    $self->tt( Template->new($config) );

}

sub call {
    my $self = shift;
    my $env  = shift;

    if ( my $res = $self->_handle_tt($env) ) {
        return $res;
    }
    return $self->app->($env);
}

sub _handle_tt {
    my ( $self, $env ) = @_;

    my $path = $env->{PATH_INFO};

    if ( my $extension = $self->extension() ) {
        return unless $path =~ /${extension}$/;
    }

    if ( my $path_match = $self->path ) {
        for ($path) {
            my $matched
                = 'CODE' eq ref $path_match
                ? $path_match->($_)
                : $_ =~ $path_match;
            return unless $matched;
        }
    }

    my $tt = $self->tt();

    my $req = Plack::Request->new($env);

    my $vars = {
        env     => $env,
        params  => $req->query_parameters(),
        cookies => $req->cookies(),            # probably too much?
    };

    my $content;
    $path =~ s{^/}{};    # Do not want to enable absolute paths

    if ( $tt->process( $path, $vars, \$content ) ) {
        return [
            '200', [ 'Content-Type' => $self->content_type() ],
            [$content]
        ];
    } else {
        my $error = $tt->error;
        if ( $error =~ /not found/ ) {
            return [
                '404',
                [ 'Content-Type' => $self->content_type() ],
                [ $tt->error() ]
            ];
        } else {
            return [
                '500',
                [ 'Content-Type' => $self->content_type() ],
                [ $tt->error() ]
            ];
        }
    }
}

1;

__END__

=head1 NAME

Plack::Middleware::TemplateToolkit - Basic Template Toolkit

=head1 SYNOPSIS

  # in app.psgi
  use Plack::Builder;

  builder {
      enable "Plack::Middleware::TemplateToolkit",
        root => '/path/to/templates/, # required
        path => '/tt/',               # optional
        extenstion => '.tt',          # optional
        content_type => 'text/html',  # default, sets Content-Type header out
      $app;
  };

=head1 DESCRIPTION

Plack::Middleware::TemplateToolkit - process files through L<Template> Toolkit (TT)

The idea behind this module is to provide access to L<Template> Toolkit for
content that is ALMOST static, but where having the power of TT can make
the content easier to manage. You probably only want to use this for the
simpliest of sites, but it should be easy enough to migrate to something
more significant later.

Some values are passed to the templates, but the more you use
these the harder it could be to migrate later so you might want to
look at a propper framework such as L<Catalyst>:

  [% env.XX %] the raw environment variables
  [% params.get('field') %] params is a L<Hash::MultiValue>

=head1 CONFIGURATIONS

=over 4

=item root

Required, root where templates live, e.g. docroot.

=item path

Only apply to files in this folder.

=item extension

Limit to only files with this extension.

=item content_type

Specify the Content-Type header you want returned, defaults to text/html

=back

=head1 AUTHOR

Leo Lapworth

=head1 SEE ALSO

L<Plack>

=cut
