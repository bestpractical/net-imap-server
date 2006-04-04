package Net::Server::IMAP::Command::List;

use base qw/Net::Server::IMAP::Command/;

sub run {
    my $self = shift;

    if ($self->options eq '"" ""') {
        $self->tagged_response(q{(\Noselect) "/" ""});
    } else {
        print STDERR "\n\nOptions are {".$self->options."}";
        $self->tagged_response(q{"/" "INBOX"});
        $self->tagged_response(q{"/" "INBOX/spiinbox"});
        $self->tagged_response(q{"/" "/foo/bar/spiinbox"});
    }

    $self->ok_completed;
}

1;
