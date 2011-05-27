use inc::Module::Install;

name 'Plack-App-TemplateToolkit';
all_from 'lib/Plack/App/TemplateToolkit.pm';

requires 'Plack', 0.9901;
requires 'Template', 2;

build_requires 'Test::More', 0.88;
test_requires 'HTTP::Request', 5.824;

resources
  bugtracker => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=Plack-App-TemplateToolkit',
  repository => 'https://github.com/ranguard/Plack-App-TemplateToolkit',
  homepage   => 'https://github.com/ranguard/Plack-App-TemplateToolkit';

WriteAll;
