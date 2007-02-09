package Net::Server::IMAP::Command::Starttls;
use base qw/Net::Server::IMAP::Command/;

sub run {
    my $self = shift;
    $self->bad_command("Sorry. We don't support TLS yet. Patches welcome!");
}

