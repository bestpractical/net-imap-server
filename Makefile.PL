use inc::Module::Install;

name ('Net-IMAP-Server');
author ('Alex Vandiver <alexmv@mit.edu>');
version_from ('lib/Net/IMAP/Server.pm');
abstract_from('lib/Net/IMAP/Server.pm');
repository("http://github.com/bestpractical/net-imap-server/");
license('perl');

requires('Class::Accessor');
requires('Coro');
requires('DateTime');
requires('DateTime::Format::Mail');
requires('DateTime::Format::Strptime');
requires('Email::Address');
requires('Email::MIME' => 1.862);
requires('Email::MIME::ContentType');
requires('Email::Simple' => 1.999);
requires('Encode::IMAPUTF7');
requires('MIME::Base64');
requires('Net::SSLeay');
requires('Net::Server::Coro' => 0.6);
requires('Regexp::Common');
requires('Test::More');
requires('UNIVERSAL::require');

&WriteAll;
