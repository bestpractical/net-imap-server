use warnings;
use strict;

package Net::Server::IMAP::Command;
use base 'Class::Accessor';
__PACKAGE__->mk_accessors(qw(io_handle command_id options command));



sub run {
    my $self = shift;
    
    $self->bad_command("command '".$self->command . "' not recognized");


}

sub untagged_response {
    my $self = shift;
    while (my $message = shift) {
        next unless $message;
        $self->out("* ".$message."\n");
    } 
}

sub tagged_response {
    my $self = shift;
    while (my $message = shift) {
        next unless $message;
        $self->untagged_response( uc($self->command)." ".$message);
    }
}

sub ok_command {
    my $self = shift;
    my $message = shift;
    my %extra_responses = (@_);
    for (keys %extra_responses) {
        $self->untagged_response("OK [".uc($_) ."] ".$extra_responses{$_});
    }
    $self->log("OK Request: $message");
    $self->out($self->command_id. " "."OK ". $message);
    $self->out("\n");
}

sub ok_completed {
    my $self = shift;
    my %extra_responses = (@_);
    $self->ok_command(uc($self->command). " COMPLETED", %extra_responses); 
}


sub bad_command {
    my $self = shift;
    my $reason = shift;
    $self->log("BAD Request: $reason");
    $self->out($self->command_id. " "."BAD ". $reason."\n");
}


sub log {
    my $self = shift;
    my $msg = shift;
    chomp($msg);
    warn $msg ."\n";
}

sub out {
    my $self = shift;
    my $msg = shift;
    $self->io_handle->print($msg);
    $self->log("S: $msg");
}
1;
