package Net::Server::IMAP::Command;

use warnings;
use strict;

use base 'Class::Accessor';
use Regexp::Common qw/delimited/;
__PACKAGE__->mk_accessors(qw(server connection command_id options command));

sub run {
    my $self = shift;

    $self->bad_command( "command '" . $self->command . "' not recognized" );
}

sub parsed_options {
    my $self = shift;

    return
        map { s/^"(.*)"$/$1/; $_ }
        grep {/\S/} split /($RE{delimited}{-delim=>'"'}|\S+)/, $self->options;
}

sub data_out {
    my $self = shift;
    my $data = shift;
    if ( ref $data eq "ARRAY" ) {
        return "(" . join( " ", map { $self->data_out($_) } @{$data} ) . ")";
    } elsif ( ref $data eq "SCALAR" ) {
        return $$data;
    } elsif ( not ref $data ) {
        if ( not defined $data ) {
            return "NIL";
        } elsif ( $data =~ /["\r\n]/ ) {
            return "{" . ( length($data) ) . "}\r\n$data";
        } elsif ( $data =~ /^\d+$/ ) {
            return $data;
        } else {
            return qq{"$data"};
        }
    }
    return "";
}

sub untagged_response {
    my $self = shift;
    while ( my $message = shift ) {
        next unless $message;
        $self->out( "* " . $message . "\r\n" );
    }
}

sub tagged_response {
    my $self = shift;
    while ( my $message = shift ) {
        next unless $message;
        $self->untagged_response( uc( $self->command ) . " " . $message );
    }
}

sub ok_command {
    my $self            = shift;
    my $message         = shift;
    my %extra_responses = (@_);
    for ( keys %extra_responses ) {
        $self->untagged_response(
            "OK [" . uc($_) . "] " . $extra_responses{$_} );
    }
    $self->log("OK Request: $message");
    $self->out( $self->command_id . " " . "OK " . $message . "\r\n" );
}

sub no_command {
    my $self            = shift;
    my $message         = shift;
    my %extra_responses = (@_);
    for ( keys %extra_responses ) {
        $self->untagged_response(
            "NO [" . uc($_) . "] " . $extra_responses{$_} );
    }
    $self->log("NO Request: $message");
    $self->out( $self->command_id . " " . "NO " . $message . "\r\n" );
}

sub no_failed {
    my $self            = shift;
    my %extra_responses = (@_);
    $self->no_command( uc( $self->command ) . " FAILED", %extra_responses );
}

sub no_unimplemented {
    my $self = shift;
    $self->no_failed( alert => $self->options
            . " unimplemented. sorry. We'd love patches!" );
}

sub ok_completed {
    my $self            = shift;
    my %extra_responses = (@_);
    $self->ok_command( uc( $self->command ) . " COMPLETED",
        %extra_responses );
}

sub bad_command {
    my $self   = shift;
    my $reason = shift;
    $self->log("BAD Request: $reason");
    $self->out( $self->command_id . " " . "BAD " . $reason . "\r\n" );
}

sub log {
    my $self = shift;
    $self->connection->log(@_);
}

sub out {
    my $self = shift;
    $self->connection->out(@_);
}

1;
