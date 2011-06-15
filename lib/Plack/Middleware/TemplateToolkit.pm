package Plack::Middleware::TemplateToolkit;

use strict;
use warnings;
use 5.008_001;

use parent 'Plack::Middleware';
use Plack::Request 0.994;
use Plack::MIME;
use Template 2;

# Configuration options as described in Template::Manual::Config
our @TT_CONFIG;
BEGIN { @TT_CONFIG = qw(START_TAG END_TAG TAG_STYLE PRE_CHOMP POST_CHOMP TRIM
INTERPOLATE ANYCASE INCLUDE_PATH DELIMITER ABSOLUTE RELATIVE DEFAULT BLOCKS
VIEWS AUTO_RESET RECURSION VARIABLES CONSTANTS CONSTANT_NAMESPACE NAMESPACE
PRE_PROCESS POST_PROCESS PROCESS WRAPPER ERROR EVAL_PERL OUTPUT OUTPUT_PATH
STRICT DEBUG DEBUG_FORMAT CACHE_SIZE STAT_TTL COMPILE_EXT COMPILE_DIR PLUGINS
PLUGIN_BASE LOAD_PERL FILTERS LOAD_TEMPLATES LOAD_PLUGINS LOAD_FILTERS TOLERANT
SERVICE CONTEXT STASH PARSER GRAMMAR); }

use Plack::Util::Accessor (qw(dir_index path extension content_type 
       default_type tt pass_through 404 vars),@TT_CONFIG);

sub prepare_app {
    my ($self) = @_;

    $self->dir_index('index.html')   unless $self->dir_index;
    $self->default_type('text/html') unless $self->default_type;

    if ( not ref $self->vars ) {
        $self->vars(
            sub {
                { shift->query_parameters }
            }
        );
    } elsif ( ref $self->vars ne 'CODE' ) {
        my $vars = $self->vars;
        $self->vars( sub {$vars} );
    }

    die 'No INCLUDE_PATH supplied' unless $self->INCLUDE_PATH;

    my $config = { };
    foreach ( @TT_CONFIG ) {
        $config->{$_} = $self->$_ if $self->$_;
    }

    # create Template object
    $self->tt( Template->new($config) );
}

sub call {    # adopted from Plack::Middleware::Static
    my ( $self, $env ) = @_;

    my $res = $self->_handle_template($env); # returns undef only if no match
    if ( $res && not( $self->pass_through and $res->[0] == 404 ) ) {
        return $res;
    }

    return $self->app->($env);

    # TODO: catch errors from $self->app and transform them if required
}

sub _handle_template {
    my ( $self, $env ) = @_;

    my $path_match = $self->path || '/';
    my $path = $env->{PATH_INFO} || '/';

    for ($path) {
        my $matched
            = 'CODE' eq ref $path_match
            ? $path_match->($_)
            : $_ =~ $path_match;
        return unless $matched;
    }

    my $req = Plack::Request->new($env);

    $path = $req->path;
    $path .= $self->dir_index if $path =~ /\/$/;

    my $extension = $self->extension;
    if ( $extension and $path !~ /${extension}$/ ) {

        # TODO: we may want another code (forbidden) and message here
        return $self->_process_error( $req, 404, 'text/plain', 'Not found' );
    }

    $path =~ s{^/}{};    # Do not want to enable absolute paths

    my $vars = $self->vars->($req);
    my $res = $self->process_template( $path, 200, $vars );
    if ( ref $res ) {
        return $res;
    } else {
        my $type = $self->content_type || $self->default_type;
        if ( $res =~ /file error .+ not found/ ) {
            return $self->_process_error( $req, 404, $type, $res );
        } else {
            if ( ref $req->logger ) {
                $req->logger->( { level => 'warn', message => $res } );
            }
            return $self->_process_error( $req, 500, $type, $res );
        }
    }
}

sub process_template {
    my ( $self, $template, $code, $vars ) = @_;

    my $content;
    if ( $self->tt->process( $template, $vars, \$content ) ) {
        my $type = $self->content_type || do {
            Plack::MIME->mime_type($1) if $template =~ /(\.\w{1,6})$/;
            }
            || $self->default_type;
        return [ $code, [ 'Content-Type' => $type ], [$content] ];
    } else {
        return $self->tt->error->as_string;
    }
}

sub _process_error {
    my ( $self, $req, $code, $type, $error ) = @_;

    return [ $code, [ 'Content-Type' => $type ], [$error] ]
        unless $self->{$code};

    my $vars = $self->vars->($req);
    my $res  = $self->process_template( $self->{$code}, $code,
        { %$vars, error => $error } );

    if ( ref $res ) {
        return $res;
    } else {

        # processing error document failed: result in a 500 error
        my $type = $self->content_type || $self->default_type;
        if ( $code eq 500 ) {
            return [ 500, [ 'Content-Type' => $type ], [$res] ];
        } else {
            if ( ref $req->logger ) {
                $req->logger->( { level => 'warn', message => $res } );
            }
            return $self->_process_error( $req, 500, $type, $res );
        }
    }
}

1;

__END__

=head1 NAME

Plack::Middleware::TemplateToolkit - Serve files with Template Toolkit and Plack

=head1 SYNOPSIS

    use Plack::Builder;

    builder {

        # Page to show when requested file is missing
        enable "Plack::Middleware::ErrorDocument",
            404 => "$root/page_not_found.html";

        # These files can be served directly
        enable "Plack::Middleware::Static",
            path => qr{\.[gif|png|jpg|swf|ico|mov|mp3|pdf|js|css]$},
            INCLUDE_PATH => $root;

        enable "Plack::Middleware::TemplateToolkit",
            INCLUDE_PATH => '/path/to/htdocs/', # required
            pass_through => 1; # delegate missing templates to $app

        $app;
    }

A minimal L<.psgi|PSGI> script as stand-alone application:

    use Plack::Middleware::TemplateToolkit;

    Plack::Middleware::TemplateToolkit->new( INCLUDE_PATH => "/path/to/docs" );

=head1 DESCRIPTION

Enable this middleware or application to allow your Plack-based application to
serve files processed through L<Template Toolkit|Template> (TT). The idea
behind this module is to provide content that is ALMOST static, but where
having the power of TT can make the content easier to manage. You probably only
want to use this for the simpliest of sites, but it should be easy enough to
migrate to something more significant later.

As L<Plack::Middleware> derives from L<Plack::Component> you can also use
this as simple application. If you just want to serve files via Template
Toolkit, treat this module as if it was called Plack::App::TemplateToolkit.

By default, the QUERY_STRING params are available to the templates, but the
more you use these the harder it could be to migrate later so you might want to
look at a propper framework such as L<Catalyst> if you do want to use them:

  [% params.get('field') %] params is a L<Hash::MultiValue>

You can mix this middleware with other Plack::App applications and
Plack::Middleware which you will find on CPAN.

=head1 CONFIGURATIONS

You can use all configuration options that are supported by Template Toolkit
(INCLUDE_PATH, INTERPOLATE, POST_COMP...). See L<Template::Manual::Config> for
an overview. The only mandatory option is INCLUDE_PATH to point to where the
templates live.

=over 4

=item path

Specifies an URL pattern or a callback to match with requests to serve
templates for.  See L<Plack::Middleware::Static> for further description.
Unlike Plack::Middleware::Static this middleware uses C<'/'> as default path.
You may also consider using L<Plack::App::URLMap> and the C<mount> syntax from
L<Plack::Builder> to map requests based on a path to this middleware.

=item extension

Limit to only files with this extension. Requests for other files will result in
a 404 response or be passed to the next application if pass_through is set.

=item content_type

Specify the Content-Type header you want returned. If not specified, the
content type will be guessed by L<Plack::MIME> based on the file extension
with default_type as default.

=item default_type

Specify the default Content-Type header. Defaults to to text/html.

=item vars

Specify a hash reference with template variables or a code reference that
gets a L<Plack::Request> objects and returns a hash reference with template
variables. By default only the QUERY_STRING params are provided as 'params'.

=item dir_index

Which file to use as a directory index, defaults to index.html

=item pass_through

If this option is enabled, requests are passed back to the application, if
the incoming request path matches with the C<path> but the requested template
file is not found. Disabled by default, so all matching requests result in
a valid response with status code 200, 404, or 500.

=back

In addition you can specify templates for error codes, for instance:

  Plack::Middleware::TemplateToolkit->new(
      root => '/path/to/htdocs/',
      404  => 'page_not_found.html' # = /path/to/htdocs/page_not_found.html
  );

If a specified error templates could not be found and processed, an error
with HTTP status code 500 is returned, possibly also as template.

=head1 METHODS

In addition to the call() method derived from L<Plack::Middleware>, this
class defines the following methods for internal use.

=head2 process_template($template, $code, \%vars)

Calls the process() method of L<Template> and returns the output in a PSGI
response object on success. The first parameter indicates the input template's
file name. The second parameter is the HTTP status code to return on success.
A reference to a hash with template variables may be passed as third parameter.
On failure this method returns an error message instead of a reference.

=head1 SEE ALSO

L<Plack>, L<Template>

=head1 AUTHORS

Leo Lapworth and Jakob Voss

=cut
