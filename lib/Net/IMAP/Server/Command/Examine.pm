package Net::Server::IMAP::Command::Examine;

use warnings;
use strict;

use base qw/Net::Server::IMAP::Command::Select/;

# See Net::Server::IMAP::Command::Select, which special-cases the
# "Examine" command to force the mailbox read-only

1;
