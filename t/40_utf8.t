use Test::More;
use File::Spec;
use Plack::Middleware::TemplateToolkit;
use Plack::Builder;
use Plack::Test;
use utf8;

# Rule: any application that is not tested with Unicode will fail on UTF8

BEGIN {
    use lib "t";
    require_ok "app_tests.pl";
}

my $root = File::Spec->catdir( "t", "root" );

# utf8 template variable
my $smiley = "\x{263A}";
my $env = { PATH_INFO => '/vars.html', 'tt.vars' => { foo => $smiley } };

my $tt = Plack::Middleware::TemplateToolkit->new( 
    INCLUDE_PATH => $root, utf8 => 'allow' );
$tt->prepare_app;

my $res = $tt->call( $env );
my ($str) = @{$res->[2]};

ok( utf8::is_utf8($str), 'allowed utf8 is UTF8' );
ok( $str =~ /[^\x00-\x7f]/, 'allowed utf8 look\'s like UTF8' );
is( $str, $smiley, 'utf8 passed through' );

# utf8 fixing
foreach my $strategy (qw(encode fix)) {
    $tt = Plack::Middleware::TemplateToolkit->new( 
        INCLUDE_PATH => $root, utf8 => $strategy );
    $tt->prepare_app;

    $res = $tt->call( $env );
    ($str) = @{$res->[2]};

    is $str, "\xE2\x98\xBA", "utf8 as binary with utf8 => '$strategy'";
    ok( $str =~ /[^\x00-\x7f]/ && !utf8::is_utf8($str), 'so it\'s not UTF-8' );
}

my $bom     = "\xFF\xFE";
my $snowman = "\x{2603}";

$app = Plack::Middleware::TemplateToolkit->new(
        INCLUDE_PATH  => $root, ENCODING => 'utf8',
        request_vars => ['parameters'], utf8 => 'fix',
);

app_tests
    app => $app,
    tests => [
    {   name    => 'Variables in templates',
        request => [ GET => '/unicode.html' ],
        content => "\xE2\x98\x83",
    },
    {   name    => 'UTF-8 parameter variable in non-UTF8 template',
        request => [ GET => '/req.html?foo=%E2%98%BA' ],
        content => qr{^R:HASH[^,]+,,\xE2\x98\xBA$},
    }
    ];

done_testing;
