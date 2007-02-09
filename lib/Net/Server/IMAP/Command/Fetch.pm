package Net::Server::IMAP::Command::Fetch;
use base qw/Net::Server::IMAP::Command/;

sub run {
    my $self = shift;
    my $options = $self->options;


    my ($messages, $spec) = split(/\s+/,$options,2);
    warn "Messages: $messages";
    warn "Spec: $spec";
    warn "The client asked for messages, but we have none to give";
    $self->ok_completed();
}

1;
