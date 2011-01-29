use ExtUtils::MakeMaker;
use strict;
use warnings;

WriteMakefile(
    'NAME'         => 'Plack::Middleware::TemplateToolkit',
    'VERSION_FROM' => 'lib/Plack/Middleware/TemplateToolkit.pm',
    'PREREQ_PM'    => {
        'Template'   => 0,
        'Plack'      => 0.9901,
        'Test::More' => 0,
        'HTTP::Request' => 0,
    }
);

