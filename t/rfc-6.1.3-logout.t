use lib 't/lib';
use strict;
use warnings;

use Net::IMAP::Server::Test;
my $t = "Net::IMAP::Server::Test";

$t->start_server_ok;

# Non-SSL
$t->connect_ok( "Non-SSL connection OK",
    Class => "IO::Socket::INET",
    PeerPort => $t->PORT,
);
ok($t->get_socket->connected, "Is connected");
$t->cmd_like(
    "LOGOUT",
    "* BYE",
    "tag OK",
);
{
    local $TODO = "It doesn't realize it has been disconnected";
    ok(!$t->get_socket->connected, "Is still connected");
    $t->get_socket->print("\n");
}
ok(!$t->get_socket->connected, "Is still connected");

# SSL connection
$t->connect_ok;
ok($t->get_socket->connected, "Is connected");
$t->cmd_like(
    "LOGOUT",
    "* BYE",
    "tag OK",
);
{
    local $TODO = "It doesn't realize it has been disconnected";
    ok(!$t->get_socket->connected, "Is still connected");
    $t->get_socket->print("\n");
}
ok(!$t->get_socket->connected, "Is still connected");

# Logged in
$t->connect_ok;
$t->cmd_ok("LOGIN username password");
$t->cmd_like(
    "LOGOUT",
    "* BYE",
    "tag OK",
);

# And selected
$t->connect_ok;
$t->cmd_ok("LOGIN username password");
$t->cmd_ok("SELECT INBOX");
$t->cmd_like(
    "LOGOUT",
    "* BYE",
    "tag OK",
);

done_testing;
