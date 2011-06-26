package Plack::Middleware::TemplateToolkit;

use strict;
use warnings;
use 5.008_001;

use parent 'Plack::Middleware';
use Plack::Request 0.994;
use Plack::MIME;
use Template 2;
use Scalar::Util qw(blessed);
use HTTP::Status qw(status_message);
use Encode;
use Carp;

# Configuration options as described in Template::Manual::Config
our @TT_CONFIG;
our @DEPRECATED;

BEGIN {
    @TT_CONFIG = qw(START_TAG END_TAG TAG_STYLE PRE_CHOMP POST_CHOMP TRIM
        INTERPOLATE ANYCASE INCLUDE_PATH DELIMITER ABSOLUTE RELATIVE DEFAULT
        BLOCKS VIEWS AUTO_RESET RECURSION VARIABLES CONSTANTS
        CONSTANT_NAMESPACE NAMESPACE PRE_PROCESS POST_PROCESS PROCESS WRAPPER
        ERROR EVAL_PERL OUTPUT OUTPUT_PATH STRICT DEBUG DEBUG_FORMAT
        CACHE_SIZE STAT_TTL COMPILE_EXT COMPILE_DIR PLUGINS PLUGIN_BASE
        LOAD_PERL FILTERS LOAD_TEMPLATES LOAD_PLUGINS LOAD_FILTERS
        TOLERANT SERVICE CONTEXT STASH PARSER GRAMMAR
    );

    # the following ugly code is only needed to catch deprecated accessors
    @DEPRECATED = qw(pre_process process eval_perl interpolate post_chomp);
    no strict 'refs';
    my $module = "Plack::Middleware::TemplateToolkit";
    foreach my $name (@DEPRECATED) {
        *{ $module . "::$name" } = sub {
            my $correct = uc($name);
            carp $module. "$name is deprecated, use ::$correct";
            my $method = $module . "::$correct";
            &$method(@_);
            }
    }

    sub new {
        my $self = Plack::Component::new(@_);

        # Support 'root' config (matches MW::Static etc)
        # if INCLUDE_PATH hasn't been defined
        $self->INCLUDE_PATH( $self->root )
            if !$self->INCLUDE_PATH() && $self->root;

        foreach ( grep { defined $self->{$_} } @DEPRECATED ) {
            $self->$_;
        }
        $self;
    }
}

use Plack::Util::Accessor (
    qw(dir_index path extension content_type default_type
        tt pass_through utf8_downgrade utf8_allow vars root), @TT_CONFIG
);

sub prepare_app {
    my ($self) = @_;

    $self->dir_index('index.html')   unless $self->dir_index;
    $self->pass_through(0)           unless defined $self->pass_through;
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

    my $config = {};
    foreach (@TT_CONFIG) {
        next unless $self->$_;
        $config->{$_} = $self->$_;
        $self->$_(undef);    # don't initialize twice
    }

    if ( $self->tt ) {
        die 'tt must be a Template instance'
            unless UNIVERSAL::isa( $self->tt, 'Template' );
        die 'Either specify a template with tt or Template options, not both'
            if %$config;
    } else {
        die 'No INCLUDE_PATH supplied' unless $config->{INCLUDE_PATH};
        $self->tt( Template->new($config) );
    }
}

sub call {    # adopted from Plack::Middleware::Static
    my ( $self, $env ) = @_;

    my $res = $self->_handle_template($env);
    if ( $res && not( $self->pass_through and $res->[0] == 404 ) ) {
        return $res;
    }

    if ( $self->app ) {
        $res = $self->app->($env);

        # TODO: if $res->[0] ne 200 and catch_errors: process error message
    } else {
        my $req = Plack::Request->new($env);
        $res = $self->process_error( 404, 'Not found', 'text/plain', $req );
    }

    $res;
}

sub process_template {
    my ( $self, $template, $code, $vars ) = @_;

    my $content;
    if ( $self->tt->process( $template, $vars, \$content ) ) {
        my $type = $self->content_type || do {
            Plack::MIME->mime_type($1) if $template =~ /(\.\w{1,6})$/;
            }
            || $self->default_type;
        if ( not $self->utf8_allow ) {
            $content = encode_utf8($content);
        } elsif ( $self->utf8_downgrade ) {

            # this undocumented option does not fix but makes errors visible
            utf8::downgrade($content);
        }
        return [ $code, [ 'Content-Type' => $type ], [$content] ];
    } else {
        return $self->tt->error->as_string;
    }
}

sub process_error {
    my ( $self, $code, $error, $type, $req ) = @_;

    $code = 500 unless $code && $code =~ /^\d\d\d$/;
    $error = status_message($code) unless $error;
    $type = ( $self->content_type || $self->default_type || 'text/plain' )
        unless $type;

    # plain error without template
    return [ $code, [ 'Content-Type' => $type ], [$error] ]
        unless $self->{$code} and $self->tt;

    $req = Plack::Request->new( { 'tt.vars' => {} } )
        unless blessed $req && $req->isa('Plack::Request');
    $self->_set_vars($req);

    $req->env->{'tt.vars'}->{'error'} = $error;
    my $res = $self->process_template( $self->{$code}, $code,
        $req->env->{'tt.vars'} );

    if ( not ref $res ) {

        # processing error document failed: result in a 500 error
        if ( $code eq 500 ) {
            $res = [ 500, [ 'Content-Type' => $type ], [$res] ];
        } else {
            if ( ref $req->logger ) {
                $req->logger->( { level => 'warn', message => $res } );
            }
            $res = $self->process_error( 500, $res, $type, $req );
        }
    }

    return $res;
}

sub _set_vars {
    my ( $self, $req ) = @_;
    my $env = $req->env;

    # TODO: $self->vars may die if it's broken. Should be catch this?
    my $vars = $self->vars->($req) if defined $self->{vars};

    if ( $env->{'tt.vars'} ) {
        foreach ( keys %$vars ) {
            $env->{'tt.vars'}->{$_} = $vars->{$_};
        }
    } else {
        $env->{'tt.vars'} = $vars;
    }
}

sub _handle_template {
    my ( $self, $env ) = @_;

    my $path       = $env->{PATH_INFO} || '/';
    my $path_match = $self->path       || '/';

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
        return $self->process_error( 404, 'Not found', 'text/plain', $req );
    }

    $path =~ s{^/}{};    # Do not want to enable absolute paths

    $self->_set_vars($req);

    $env->{'tt.template'} = $path;    # for debug inspection (not tested)

    my $res = $self->process_template( $path, 200, $env->{'tt.vars'} );
    if ( ref $res ) {
        return $res;
    } else {
        my $type = $self->content_type || $self->default_type;
        if ( $res =~ /file error .+ not found/ ) {
            return $self->process_error( 404, $res, $type, $req );
        } else {
            if ( ref $req->logger ) {
                $req->logger->( { level => 'warn', message => $res } );
            }
            return $self->process_error( 500, $res, $type, $req );
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
having the power of TT can make the content easier to manage. You probably 
only want to use this for the simpliest of sites, but it should be easy 
enough to migrate to something more significant later.

As L<Plack::Middleware> derives from L<Plack::Component> you can also use
this as simple application. If you just want to serve files via Template
Toolkit, treat this module as if it was called Plack::App::TemplateToolkit.

You can mix this middleware with other Plack::App applications and
Plack::Middleware which you will find on CPAN.

This middleware reads and sets the PSGI environment variable tt.vars for
variables passed to templates. By default, the QUERY_STRING params are
available to the templates, but the more you use these the harder it could be
to migrate later so you might want to look at a propper framework such as
L<Catalyst> if you do want to use them:

  [% params.get('field') %] params is a L<Hash::MultiValue>

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
Templates variables specified by this option are added to existing template
variables in the tt.vars environment variable.

=item dir_index

Which file to use as a directory index, defaults to index.html

=item pass_through

If this option is enabled, requests are passed back to the application, if
the incoming request path matches with the C<path> but the requested template
file is not found. Disabled by default, so all matching requests result in
a valid response with status code 200, 404, or 500.

=item tt

Directly set an instance of L<Template> instead of creating a new one:

  Plack::Middleware::TemplateToolkit->new( %tt_options );

  # is equivalent to:

  my $tt = Template->new( %tt_options );
  Plack::Middleware::TemplateToolkit->new( tt => $tt );

=item utf8_allow

PSGI expects the content body to be a byte stream, but Template Toolkit
is best used with templates and variables as UTF8 strings. For this reason
processed templates are encoded to UTF8 byte streams unless you enable this
options. It is then up to you to ensure that only byte streams are emitted
by your PSGI application. It is recommended to use L<Plack::Middleware::Lint>
and test with Unicode characters or your application will likely fail.

=back

In addition you can specify templates for error codes, for instance:

  Plack::Middleware::TemplateToolkit->new(
      INCLUDE_PATH => '/path/to/htdocs/',
      404  => 'page_not_found.html' # = /path/to/htdocs/page_not_found.html
  );

If a specified error templates could not be found and processed, an error
with HTTP status code 500 is returned, possibly also as template.

=head1 METHODS

In addition to the call() method derived from L<Plack::Middleware>, this
class defines the following methods for internal use.

=head2 process_template ( $template, $code, \%vars )

Calls the process() method of L<Template> and returns the output in a PSGI
response object on success. The first parameter indicates the input template's
file name. The second parameter is the HTTP status code to return on success.
A reference to a hash with template variables may be passed as third parameter.
On failure this method returns an error message instead of a reference.

=head2 process_error ( $code, $error, $type, $req ) = @_;

Returns a PSGI response to be used as error message. Error templates are used
if they have been specified and prepare_app has been called before. This method 
tries hard not to fail: undefined parameters are replaced by default values.

=head1 SEE ALSO

L<Plack>, L<Template>

=head1 AUTHORS

Leo Lapworth (started) and Jakob Voss (most of the work!)

=cut
