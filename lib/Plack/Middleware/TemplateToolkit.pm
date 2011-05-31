package Plack::Middleware::TemplateToolkit;

use strict;
use warnings;
use 5.008_001;

use parent 'Plack::Middleware';
use Plack::Request 0.994;
use Plack::MIME;
use Template 2;

use Plack::Util::Accessor
    qw(root interpolate post_chomp dir_index path extension content_type 
       default_type tt eval_perl pre_process process pass_through 404 vars);

sub prepare_app {
    my ($self) = @_;

    die "No root supplied" unless $self->root;

    $self->dir_index('index.html')   unless $self->dir_index;
    $self->default_type('text/html') unless $self->default_type;
    $self->interpolate(0)            unless defined $self->interpolate;
    $self->eval_perl(0)              unless defined $self->eval_perl;
    $self->post_chomp(1)             unless defined $self->post_chomp;

    if ( not ref $self->vars ) {
        $self->vars( sub { { shift->query_parameters } } );
    } elsif ( ref $self->vars ne 'CODE' ) {
        my $vars = $self->vars;
        $self->vars( sub { $vars } );
    }

    my $config = {
        INCLUDE_PATH => $self->root,           # or list ref
        INTERPOLATE  => $self->interpolate,    # expand "$var" in plain text
        POST_CHOMP   => $self->post_chomp,     # cleanup whitespace
        EVAL_PERL    => $self->eval_perl,      # evaluate Perl code blocks
    };

    $config->{PRE_PROCESS} = $self->pre_process if $self->pre_process;
    $config->{PROCESS}     = $self->process     if $self->process;

    # create Template object
    $self->tt( Template->new($config) );
}

sub call {    # adopted from Plack::Middleware::Static
    my ($self, $env) = @_;

    my $res = $self->_handle_template($env);
    if ($res && not ($self->pass_through and $res->[0] == 404)) {
        return $res;
    }

    return $self->app->($env);

    # TODO: catch errors from $self->app and transform them if required
}

sub _handle_template {
    my ($self, $env) = @_;

    my $path_match = $self->path || '/';
    my $path = $env->{PATH_INFO};

    for ($path) {
        my $matched = 'CODE' eq ref $path_match ? $path_match->($_) : $_ =~ $path_match;
        return unless $matched;
    }

    my $req = Plack::Request->new($env);

    $path = $req->path;
    $path .= $self->dir_index if $path =~ /\/$/;

    my $extension = $self->extension;
    if ($extension and $path !~ /${extension}$/) {
        # TODO: we may want another code (forbidden) and message here
        return $self->_process_error($req, "404", "text/plain", "Not found");
    }

    $path =~ s{^/}{};    # Do not want to enable absolute paths

    my $vars = $self->vars->( $req );
    my $res = $self->process_template( $path, 200, $vars );
    if ( ref $res ) {
        return $res;
    } else {
	my $type  = $self->content_type || $self->default_type;
        if ( $res =~ /file error .+ not found/ ) {
            return $self->_process_error($req, 404, $type, $res);
        } else {
            if ( ref $req->logger ) {
                $req->logger->({ level => "warn", message => $res });
            }
            return $self->_process_error($req, 500, $type, $res);
        }
    }
}

sub process_template {
    my ($self, $template, $code, $vars) = @_;

    my $content;
    if ( $self->tt->process( $template, $vars, \$content ) ) {
        my $type = $self->content_type || do { 
            Plack::MIME->mime_type($1) if $template =~ /(\.\w{1,6})$/
        } || $self->default_type;
        return [ $code, [ 'Content-Type' => $type ], [ $content ] ];
    } else {
        return $self->tt->error->as_string;
    }
}

sub _process_error {
    my ($self, $req, $code, $type, $error) = @_;

    return [ $code, [ 'Content-Type' => $type ], [$error] ]
        unless $self->{$code};

    my $vars = $self->vars->( $req );
    my $res = $self->process_template( $self->{$code}, $code,
        { %$vars, error => $error } );

    if ( ref $res ) {
        return $res;
    } else {
       # processing error document failed: result in a 500 error
        my $type  = $self->content_type || $self->default_type;
        if ($code eq 500) { 
           return [ 500, [ 'Content-Type' => $type ], [$res] ];
        } else {
            if ( ref $req->logger ) {
                $req->logger->({ level => "warn", message => $res });
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
            root => $root;

	enable "Plack::Middleware::TemplateToolkit",
            root => '/path/to/htdocs/', # required
            pass_through => 1; # delegate missing templates to $app

        $app;
    }

A minimal .psgi script that uses the middleware as stand-alone application:

    use Plack::Middleware::TemplateToolkit;

    Plack::Middleware::TemplateToolkit->new( root => "/path/to/docs" );

=head1 DESCRIPTION

Enable this middleware or application to allow your Plack-based application to
serve files processed through L<Template> Toolkit (TT).

The idea behind this module is to provide access to L<Template> Toolkit (TT) for
content that is ALMOST static, but where having the power of TT can make
the content easier to manage. You probably only want to use this for the
simpliest of sites, but it should be easy enough to migrate to something
more significant later.

As L<Plack::Middleware> derives from C<Plack::Component> you can also use
this as simple application. If you just want to serve files via Template
Toolkit, treat this module as if it was called Plack::App::TemplateToolkit.

By default, the QUERY_STRING params are available to the templates, but the
more you use these the harder it could be to migrate later so you might want to
look at a propper framework such as L<Catalyst> if you do want to use them:

  [% params.get('field') %] params is a L<Hash::MultiValue>

You can mix this middleware with other Plack::App applications and
Plack::Middleware which you will find on CPAN.

=head1 CONFIGURATIONS

=over 4

=item root

Required, root where templates live. This can be an array reference or a string
(see L<Template> configuration INCLUDE_PATH)

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
file is not found.

=item pre_process

Optional, supply a file to pre process before serving each html file
(see C<Template> configuration PRE_PROCESS)

=item process

Optional, supply a file to process (see C<Template> configuration PROCESS)

=item eval_perl

Default to 0, this option lets you run perl blocks in your
templates - I would strongly recommend NOT using this.
(see C<Template> configuration EVAL_PERL)

=item interpolate

Default to 0, see C<Template> configuration INTERPOLATE

=item post_chomp

Defaults to 1, see C<Template> configuration POST_CHOMP

=back

In addition you can specify templates for error codes, for instance:

  Plack::Middleware::TemplateToolkit->new(
      root => '/path/to/htdocs/',
      404  => 'page_not_found.html' # = /path/to/htdocs/page_not_found.html
  );
 
If a specified error templates could not be found and processed, an error
with HTTP status code 500 is returned, possibly also as template.

=head1 METHODS

In addition to the call() method derived from T<Plack::Middleware>, this
class defines the following methods for internal use.

=head2 process_template($template, $code, \%vars)

Calls the process() method of L<Template> and returns the output in a PSGI
response object on success. The first parameter indicates the input template's
file name. The second parameter is the HTTP status code to return on success.
A reference to a hash with template variables may be passed as third parameter.
On failure this method returns an error message instead of a reference.

=head1 SEE ALSO

L<Plack>, L<Template>

=cut
