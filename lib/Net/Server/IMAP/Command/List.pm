package Net::Server::IMAP::Command::List;

use warnings;
use strict;

use base qw/Net::Server::IMAP::Command/;

sub run {
    my $self = shift;

    return $self->bad_command("Log in first") if $self->connection->is_unauth;

    my @args = $self->parsed_options;

    return $self->bad_command("Wrong arugments") unless @args == 2;

    my ( $root, $search ) = @args;

   # In the special case of a query for the delimiter, give them our delimiter
    if ( $search eq "" ) {
        $self->tagged_response( q{(\Noselect) "}
                . $self->connection->model->seperator
                . q{" ""} );
    } else {
        my $sep = $self->connection->model->seperator;
        $search =~ s/\*/.*/g;
        $search =~ s/%/[^$sep]/g;
        my $regex = qr{^\Q$root\E$search$};
        $self->traverse( $self->connection->model->root, $regex );
    }

    $self->ok_completed;
}

sub traverse {
    my $self  = shift;
    my $node  = shift;
    my $regex = shift;

    my $str = $node->children ? q{(\HasChildren)} : q{()};
    $str .= q{ "/" };
    $str .= q{"} . $node->full_path . q{"};
    $self->tagged_response($str) if $node->full_path =~ $regex;
    if ( $node->children ) {
        $self->traverse( $_, $regex ) for @{ $node->children };
    }
}

1;
