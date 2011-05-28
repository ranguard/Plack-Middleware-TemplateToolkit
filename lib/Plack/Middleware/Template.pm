package Plack::Middleware::Template;

use strict;
use warnings;
use 5.008_001;

=head1 NAME

Plack::Middleware::Template - Serve files with Template Toolkit and Plack

=cut

our $VERSION = 0.06;

use parent 'Plack::Middleware';
use Plack::Request 0.994;
use Plack::MIME;
use Template 2;

use Plack::Util::Accessor
    qw(root interpolate post_chomp dir_index path extension content_type 
       default_type tt eval_perl pre_process process pass_through);

sub prepare_app {
    my ($self) = @_;

    die "No root supplied" unless $self->root;

    $self->dir_index('index.html')   unless $self->dir_index;
    $self->default_type('text/html') unless $self->default_type;
    $self->interpolate(0)            unless defined $self->interpolate;
    $self->eval_perl(0)              unless defined $self->eval_perl;
    $self->post_chomp(1)             unless defined $self->post_chomp;

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
	my $type  = $self->content_type || $self->default_type;
        return [ 404, [ 'Content-Type' => $type ], ["Not found"] ];
    }

    my $tt = $self->tt;

    my $vars = { params => $req->query_parameters, };

    my $content;
    $path =~ s{^/}{};    # Do not want to enable absolute paths

    if ( $tt->process( $path, $vars, \$content ) ) {
	my $type = $self->content_type || do { 
            Plack::MIME->mime_type($1) if $path =~ /(\.\w{1,6})$/
	} || $self->default_type;
        return [ 200, [ 'Content-Type' => $type ], [$content] ];
    } else {
        my $error = $tt->error->as_string;
	my $type  = $self->content_type || $self->default_type;
        if ( $error =~ /not found/ ) {
            return [ 404, [ 'Content-Type' => $type ], [$error] ];
        } else {
            return [ 500, [ 'Content-Type' => $type ], [$error] ];
        }
    }
}

1;

__END__

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

	enable "Plack::Middleware::Template",
            root => '/path/to/htdocs/', # required
            pass_through => 1; # delegate missing templates to $app

        $app;
    }

A minimal .psgi script that uses the middleware as stand-alone application:

    use Plack::Middleware::Template;

    Plack::Middleware::Template->new( root => "/path/to/docs" );

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
Toolkit, treat this module as if it was called Plack::App::Template.

The QUERY_STRING params are available to the templates, but the more you use
these the harder it could be to migrate later so you might want to
look at a propper framework such as L<Catalyst> if you do want to use them:

  [% params.get('field') %] params is a L<Hash::MultiValue>

You can mix this application with other Plack::App applications and
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

=head1 TODO

Error documents are not served as templates. You can use 
L<Plack::Middleware::ErrorDocument> for customization.

=head1 SEE ALSO

L<Plack>, L<Template>

=head1 AUTHORS

Leo Lapworth and Jakob Voss

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
