package Net::IMAP::Server::Command::Create;

use warnings;
use strict;

use base qw/Net::IMAP::Server::Command/;

use Encode;
use Encode::IMAPUTF7;

sub validate {
    my $self = shift;

    return $self->bad_command("Log in first") if $self->connection->is_unauth;

    my @options = $self->parsed_options;
    return $self->bad_command("Not enough options") if @options < 1;
    return $self->bad_command("Too many options") if @options > 1;

    my ($name) = @options;
    $name = eval { Encode::decode('IMAP-UTF-7', $name) };
    return $self->bad_command("Invalid UTF-7 encoding") unless defined $name;

    my $mailbox = $self->connection->model->lookup( $name );
    return $self->no_command("Mailbox already exists") if $mailbox;

    return 1;
}

sub run {
    my $self = shift;

    my($name) = $self->parsed_options;
    $name = Encode::decode('IMAP-UTF-7',$name);
    my @parts = $self->connection->model->split($name);

    my $base = $self->connection->model->root;
    for my $n (0.. $#parts) {
        my $path = join($self->connection->model->root->separator, @parts[0 .. $n]);
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
