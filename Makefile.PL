use inc::Module::Install;

name ('Net-Server-IMAP');
author ('Jesse Vincent <jesse@bestpractical.com>');
version_from ('lib/Net/Server/IMAP.pm');
abstract_from('lib/Net/Server/IMAP.pm');
license('perl');
requires('Test::More');

&WriteAll;
