use inc::Module::Install;

name 'Plack-Middleware-Template';
all_from 'lib/Plack/Middleware/Template.pm';

requires 'Plack', 0.994;
requires 'Template', 2;

build_requires 'Test::More', 0.88;
test_requires 'HTTP::Request', 5.824;

resources # TODO: adjust these names
  bugtracker => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=Plack-App-TemplateToolkit',
  repository => 'https://github.com/ranguard/Plack-App-TemplateToolkit',
  homepage   => 'https://github.com/ranguard/Plack-App-TemplateToolkit';

WriteAll;
