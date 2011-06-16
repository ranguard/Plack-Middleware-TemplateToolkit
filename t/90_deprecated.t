use strict;
use Test::More 0.98;

use Plack::Middleware::TemplateToolkit;

my $tt = eval { Plack::Middleware::TemplateToolkit->new( 
    INCLUDE_PATH => '.',  process => 1 ); };
ok $@, 'deprecated accessor';

$tt = Plack::Middleware::TemplateToolkit->new( INCLUDE_PATH => '.' );
eval { $tt->eval_perl; };
ok $@, 'deprecated method';

done_testing;
