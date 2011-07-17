use Plack::Builder;
use Plack::Middleware::TemplateToolkit;
use File::Basename;
use Cwd;

my $root = Cwd::realpath( dirname($0) );

my $app = sub {
    [   404,
        [ 'Content-Type' => 'text/html' ],
        ['<html><body>not found</body></html>']
    ];
};

builder {
    enable 'Debug';
    enable 'Debug::TemplateToolkit';
    enable 'TemplateToolkit',
        INCLUDE_PATH => $root,
        INTERPOLATE  => 1,
        vars         => { greet => 'Hello' },
        request_vars => [qw(parameters base)],
        pass_through => 1;
    $app;
};
