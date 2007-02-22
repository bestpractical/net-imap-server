package Email::IMAPFolder;
use base 'Email::Folder';
use YAML;

sub bless_message {
    my $self = shift;
    my $message = shift || "";

    return Net::Server::IMAP::Message->new($message);
}
1;
