use inc::Module::Install;

name ('Net-Server-IMAP');
author ('Jesse Vincent <jesse@bestpractical.com>');
version_from ('lib/Net/Server/IMAP.pm');
abstract_from('lib/Net/Server/IMAP.pm');
license('perl');

requires('Class::Accessor');
requires('Email::Address');
requires('Email::MIME');
requires('Email::MIME::ContentType');
requires('Email::Simple' => 1.999);
requires('IO::Socket');
requires('IO::Socket::SSL');
requires('MIME::Base64');
requires('Regexp::Common');
requires('Test::More');

&WriteAll;
