use Test::More;
use File::Spec;
use Plack::Middleware::TemplateToolkit;
use utf8;

# Rule: any application that is not tested with Unicode will fail on UTF8

my $root = File::Spec->catdir( "t", "root" );
my $env = { PATH_INFO => '/vars.html', 'tt.vars' => { foo => "\x{1F4A9}" } };

my $tt = Plack::Middleware::TemplateToolkit->new( INCLUDE_PATH => $root, 
    utf8_allow => 1 );
$tt->prepare_app;

my $res = $tt->call( $env );
my ($str) = @{$res->[2]};

ok( utf8::is_utf8($str), 'is UTF8' );
ok( $str =~ /[^\x00-\x7f]/, 'look\'s like UTF8' );

$tt = Plack::Middleware::TemplateToolkit->new( INCLUDE_PATH => $root );
$tt->prepare_app;

$res = $tt->call( $env );
($str) = @{$res->[2]};

ok( !utf8::is_utf8($str), 'is not UTF8' );
ok( $str =~ /[^\x00-\x7f]/, 'look\'s like UTF8' );

done_testing;
