package Plack::Middleware::Debug::TemplateToolkit;

use strict;
use warnings;
use 5.008_001;

use parent 'Plack::Middleware::Debug::Base';

sub run {
    my ($self, $env, $panel) = @_;

    return sub {
        my $res = shift;

        $panel->nav_subtitle( $env->{'tt.template'} )
            if defined $env->{'tt.template'};

        my $ttvars = "";
        if ( defined $env->{'tt.vars'} ) {
            $ttvars = '<h4>Template variables (tt.vars)</h4>'
                . $self->render_hash( delete $env->{'tt.vars'} );
        }

        my @ttkeys = grep { $_ =~ /^tt\./ } keys %$env;

        $panel->content(
            $self->render_list_pairs( [
                map { $_ => delete $env->{$_} } sort @ttkeys
            ] ) . $ttvars
        );
    }
}

1;

__END__

=head1 NAME

Plack::Middleware::Debug::TemplateToolkit - Debug panel for Template Toolkit

=head1 SYNOPSIS

=head1 DESCRIPTION

This L<Plack::Middleware::Debug> Panel shows which template has been processed
with which templates variables, by displaying all C<tt.> PSGI environment
variables.

=head1 AUTHOR

Jakob Voss

=cut
