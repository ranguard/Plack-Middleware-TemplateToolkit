package Plack::App::TemplateToolkit;

use strict;
use warnings;
use 5.008_001;

our $VERSION = 0.05;

use parent qw( Plack::Component );
use Plack::Request 0.9901;
use Plack::MIME;
use Template 2;

use Plack::Util::Accessor
    qw( root interpolate post_chomp dir_index path extension content_type 
        default_type tt eval_perl pre_process process);

sub prepare_app {
    my ($self) = @_;

    die "No root supplied" unless $self->root();

    $self->dir_index('index.html')   unless $self->dir_index();
    $self->default_type('text/html') unless $self->default_type();
    $self->interpolate(0)            unless defined $self->interpolate();
    $self->eval_perl(0)              unless defined $self->eval_perl();
    $self->post_chomp(1)             unless defined $self->post_chomp();

    my $config = {
        INCLUDE_PATH => $self->root(),           # or list ref
        INTERPOLATE  => $self->interpolate(),    # expand "$var" in plain text
        POST_CHOMP   => $self->post_chomp(),     # cleanup whitespace
        EVAL_PERL    => $self->eval_perl(),      # evaluate Perl code blocks
    };

    $config->{PRE_PROCESS} = $self->pre_process() if $self->pre_process();
    $config->{PROCESS}     = $self->process()     if $self->process();

    # create Template object
    $self->tt( Template->new($config) );

}

sub call {
    my $self = shift;
    my $env  = shift;

    if ( my $res = $self->_handle_tt($env) ) {
        return $res;
    }
    return [ 404, [ 'Content-Type' => 'text/html' ], ['404 Not Found'] ];
}

sub _handle_tt {
    my $self = shift;
    my $req = Plack::Request->new(shift);

    my $path = $req->path;
    $path .= $self->dir_index if $path =~ /\/$/;

    if ( my $extension = $self->extension() ) {
        return 0 unless $path =~ /${extension}$/;
    }

    my $tt = $self->tt();

    my $vars = { params => $req->query_parameters(), };

    my $content;
    $path =~ s{^/}{};    # Do not want to enable absolute paths

    if ( $tt->process( $path, $vars, \$content ) ) {
	my $type = $self->content_type || do { 
            Plack::MIME->mime_type($1) if $path =~ /(\.\w{1,6})$/
	} || $self->default_type;
        return [ 200, [ 'Content-Type' => $type ], [$content] ];
    } else {
        my $error = $tt->error->as_string();
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

=head1 NAME

Plack::App::TemplateToolkit - Basic Plack App Template Toolkit

=head1 SYNOPSIS

    # in app.psgi
    use Plack::Builder;
    use Plack::App::TemplateToolkit;

    my $root = '/path/to/htdocs/';

    my $tt_app = Plack::App::TemplateToolkit->new(
        root => $root,    # Required
    )->to_app();

    return builder {

        # Page to show when requested file is missing
        enable "Plack::Middleware::ErrorDocument",
            404 => "$root/page_not_found.html";

        # These files can be served directly
        enable "Plack::Middleware::Static",
            path => qr{[gif|png|jpg|swf|ico|mov|mp3|pdf|js|css]$},
            root => $root;

        # Our application
        $tt_app;
    }

=head1 DESCRIPTION

Plack::App::TemplateToolkit - process files through L<Template> Toolkit (TT)

The idea behind this module is to provide access to L<Template> Toolkit (TT) for
content that is ALMOST static, but where having the power of TT can make
the content easier to manage. You probably only want to use this for the
simpliest of sites, but it should be easy enough to migrate to something
more significant later.

The QUERY_STRING params are available to the templates, but the more you use
these the harder it could be to migrate later so you might want to
look at a propper framework such as L<Catalyst> if you do want to use them:

  [% params.get('field') %] params is a L<Hash::MultiValue>

You can mix this application with other Plack::App applications and
Plack::Middleware which you will find on CPAN.

=head1 CONFIGURATIONS

=over 4

=item root

Required, root where templates live, e.g. INCLUDE_PATH. This can be
an array reference or a string.

=item extension

Limit to only files with this extension.

=item content_type

Specify the Content-Type header you want returned. If not specified, the
content type will be guessed by L<Plack::MIME> based on the file extension
with default_type as default.

=item default_type

Specify the default Content-Type header. Defaults to to text/html.

=item dir_index

Which file to use as a directory index, defaults to index.html

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

=head1 SEE ALSO

L<Plack>, L<Template>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
