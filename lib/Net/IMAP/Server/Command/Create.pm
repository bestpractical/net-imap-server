package Net::IMAP::Server::Command::Create;

use warnings;
use strict;

use base qw/Net::IMAP::Server::Command/;

sub validate {
    my $self = shift;

    return $self->bad_command("Log in first") if $self->connection->is_unauth;

    my @options = $self->parsed_options;
    return $self->bad_command("Not enough options") if @options < 1;
    return $self->bad_command("Too many options") if @options > 1;

    my $mailbox = $self->connection->model->lookup( @options );
    return $self->no_command("Mailbox already exists") if $mailbox;

    # This both ensures that the mailbox path is valid UTF-7, and that
    # there aren't bogusly encoded characters (like '/' -> '&AC8-')
    my $roundtrip = eval {
        Encode::encode( 'IMAP-UTF-7',
            Encode::decode( 'IMAP-UTF-7', $options[0] ) );
    };

    return $self->bad_command("Invalid UTF-7 encoding")
        unless $roundtrip eq $options[0];

    return 1;
}

sub run {
    my $self = shift;

    my @parts = $self->connection->model->split( $self->parsed_options );

    my $base = $self->connection->model->root;
    for my $n (0.. $#parts) {
        my $sep = $self->connection->model->root->separator || "";
        my $path = join($sep, @parts[0 .. $n]);
        my $part = $self->connection->model->lookup($path);
        unless ($part) {
            unless ($part = $base->create( name => $parts[$n] )) {
                return $self->no_command("Permission denied");
            }
        }
        $base = $part;
    }

    $self->ok_completed();
}

1;
