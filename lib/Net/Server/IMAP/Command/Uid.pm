package Net::Server::IMAP::Command::Uid;

use warnings;
use strict;

use base qw/Net::Server::IMAP::Command/;

sub validate {
    my $self = shift;

    return $self->bad_command("Login first") if $self->connection->is_unauth;
    return $self->bad_command("Select a mailbox first")
        unless $self->connection->is_selected;

    my @options = $self->parsed_options;
    return $self->bad_command("Not enough options") if @options < 1;

    return 1;
}

sub run {
    my $self = shift;

    my ($subcommand, @rest) = $self->parsed_options;
    $subcommand = lc $subcommand;
    if ($subcommand =~ /^(copy|fetch|store|search)$/i ) {
        $self->$subcommand(@rest);
    } else {
        $self->log(
            $subcommand . " wasn't understood by the 'UID' command" );
        $self->no_failed(
            alert => q{Your client sent a UID command we didn't understand} );
    }

}

sub fetch {
    my $self = shift;

    return $self->bad_command("Not enough options") if @_ < 2;
    return $self->bad_command("Too many options") if @_ > 2;

    my ( $messages, $spec ) = @_;
    $spec = [$spec] unless ref $spec;
    push @{$spec}, "UID" unless grep {uc $_ eq "UID"} @{$spec};
    my @messages = $self->connection->selected->get_uids($messages);
    for my $m (@messages) {
        $self->untagged_response( $self->connection->sequence($m)
                . " FETCH "
                . $self->data_out( [ $m->fetch($spec) ] ) );
    }

    $self->ok_completed();
}

sub store {
    my $self = shift;

    return $self->bad_command("Mailbox is read-only") if $self->connection->selected->read_only;

    return $self->bad_command("Not enough options") if @_ < 3;
    return $self->bad_command("Too many options") if @_ > 3;

    my ( $messages, $what, $flags ) = @_;
    $flags = ref $flags ? $flags : [$flags];
    my @messages = $self->connection->selected->get_uids($messages);
    $self->connection->ignore_flags(1) if $what =~ /\.SILENT$/i;
    for my $m (@messages) {
        $m->store( $what => $flags );
        $self->connection->untagged_fetch->{$self->connection->sequence($m)}{UID}++
          unless $what =~ /\.SILENT$/i;
    }
    $self->connection->ignore_flags(0) if $what =~ /\.SILENT$/i;

    $self->ok_completed;
}

sub copy {
    my $self = shift;
    
    return $self->bad_command("Not enough options") if @_ < 2;
    return $self->bad_command("Too many options") if @_ > 2;

    my ( $messages, $name ) = @_;
    my $mailbox = $self->connection->model->lookup( $name );
    return $self->no_command("[TRYCREATE] Mailbox does not exist") unless $mailbox;
    return $self->bad_command("Mailbox is read-only") if $mailbox->read_only;

    my @messages = $self->connection->selected->get_uids($messages);
    return $self->no_command("Permission denied") if grep {not $_->copy_allowed($mailbox)} @messages;

    $_->copy($mailbox) for @messages;

    $self->ok_completed;
}

sub search {
    my $self = shift;

    my $filter = Net::Server::IMAP::Command::Search::filter($self, @_);
    return unless $filter;

    my @results = map {$_->uid} grep {$filter->($_)} $self->connection->get_messages('1:*');
    $self->untagged_response("SEARCH @results");

    $self->ok_completed;
}

1;
