use inc::Module::Install;

name ('Net-IMAP-Server');
author ('Jesse Vincent <jesse@bestpractical.com>');
version_from ('lib/Net/IMAP/Server.pm');
abstract_from('lib/Net/IMAP/Server.pm');
license('perl');

requires('Class::Accessor');
requires('Coro');
requires('Email::Address');
requires('Email::MIME');
requires('Email::MIME::ContentType');
requires('Email::Simple' => 1.999);
requires('MIME::Base64');
requires('Net::Server::Coro' => 0.2);
requires('Regexp::Common');
requires('Test::More');

&WriteAll;
