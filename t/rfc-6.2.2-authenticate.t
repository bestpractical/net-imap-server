use lib 'inc';
use strict;
use warnings;

use Net::IMAP::Server::Test;
my $t = "Net::IMAP::Server::Test";

$t->start_server_ok;

# Connect over SSL
$t->connect_ok;

# We support PLAIN auth by default
my ($cap) = $t->cmd_like(
    "CAPABILITY",
    "* CAPABILITY",
    "tag OK",
);

like($cap, qr/\bAUTH=PLAIN\b/, "Advertises AUTH=PLAIN");

# Try a bogus auth type
$t->cmd_like("AUTHENTICATE BOGUS aaa", "tag NO");

# Fail the auth by not base64-encoding
$t->cmd_like("AUTHENTICATE PLAIN bogus", "tag BAD");

# Omit the password
use MIME::Base64;
my $base64 = encode_base64("authz\0username"); chomp $base64;
$t->cmd_like("AUTHENTICATE PLAIN $base64", "tag BAD");

# Wrong password
$base64 = encode_base64("authz\0username\0wrong"); chomp $base64;
$t->cmd_like("AUTHENTICATE PLAIN $base64", "tag NO");

# Correct login
$base64 = encode_base64("authz\0username\0password"); chomp $base64;
$t->cmd_like("AUTHENTICATE PLAIN $base64", "tag OK");

# Can't login again
$t->cmd_like("AUTHENTICATE PLAIN $base64", "tag BAD");
$t->cmd_ok("LOGOUT");

# Do the auth over two lines
$t->connect_ok;
$t->cmd_like("AUTHENTICATE PLAIN", "+");
$t->line_like($base64, "tag OK");
$t->cmd_ok("LOGOUT");

# Test cancelling auth
$t->connect_ok;
$t->cmd_like("AUTHENTICATE PLAIN", "+");
$t->line_like("*", "tag BAD");


done_testing;
