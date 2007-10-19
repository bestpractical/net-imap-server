package Net::Server::IMAP::Command::List;

use warnings;
use strict;

use base qw/Net::Server::IMAP::Command/;

sub validate {
    my $self = shift;

    return $self->bad_command("Log in first") if $self->connection->is_unauth;

    my @options = $self->parsed_options;
    return $self->bad_command("Not enough options") if @options < 2;
    return $self->bad_command("Too many options") if @options > 2;

    return 1;
}

sub run {
    my $self = shift;

    my ( $root, $search ) = $self->parsed_options;

    # In the special case of a query for the delimiter, give them our delimiter
    if ( $search eq "" ) {
        $self->tagged_response( q{(\Noselect) "}
                . $self->connection->model->root->seperator
                . q{" ""} );
    } else {
        my $sep = $self->connection->model->root->seperator;
        $search = quotemeta($search);
        $search =~ s/\\\*/.*/g;
        $search =~ s/\\%/[^$sep]+/g;
        my $regex = qr{^\Q$root\E$search$};
        $self->traverse( $self->connection->model->root, $regex );
    }

    $self->ok_completed;
}

sub list_out {
    my $self = shift;
    my $node = shift;
    my @props = @_;

    my $str = $self->data_out([map {\$_} @props]);
    $str .= q{ "} . $self->connection->model->root->seperator . q{" };
    $str .= q{"} . $node->full_path . q{"};
    $self->tagged_response($str);
}

sub traverse {
    my $self  = shift;
    my $node  = shift;
    my $regex = shift;

    my @props;
    push @props, @{$node->children} ? '\HasChildren' : '\HasNoChildren';
    push @props, '\Noselect' unless $node->selectable;

    $self->list_out($node, @props) if $node->parent and $node->full_path =~ $regex;
    $self->traverse( $_, $regex ) for @{ $node->children };
}

1;
