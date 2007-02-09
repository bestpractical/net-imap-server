package Net::Server::IMAP::Command::List;

use base qw/Net::Server::IMAP::Command/;

sub run {
    my $self = shift;
    my $options = $self->options;

    my @atoms;
    while ($options and $options =~ /^(".*?"|.*?)(?:\s(.*)|$)/) {
        push @atoms, $1;
        $options = $2;
    }
    
    use YAML; warn YAML::Dump(\@atoms);
   
    # In the special case of a query for the delimiter, give them our delimiter
    if ($self->options eq '"" ""') {
        $self->tagged_response(q{(\Noselect) "/" ""});
    } else {
        print STDERR "\n\nOptions are {".$self->options."}";
        $self->tagged_response(q{() "/" INBOX});
        $self->tagged_response(q{() "/" foo});
        $self->tagged_response(q{() "/" foo/bar});
        $self->tagged_response(q{() "/" foo/baz});
    }

    $self->ok_completed;
}

1;
