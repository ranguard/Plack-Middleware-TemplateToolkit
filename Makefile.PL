use ExtUtils::MakeMaker;
use strict;
use warnings;

WriteMakefile(
    'NAME'         => 'Plack::App::TemplateToolkit',
    'VERSION_FROM' => 'lib/Plack/App/TemplateToolkit.pm',
    'PREREQ_PM'    => {
        'Template'      => 2,
        'Plack'         => 0.9901,
        'Test::More'    => 0,
        'HTTP::Request' => 0,
        'Path::Class'   => 0,
    }
);

