package Net::Server::IMAP::Command::Select;
use base qw/Net::Server::IMAP::Command/;

sub run {
    my $self = shift;
    $self->untagged_response('1 EXISTS');
    $self->untagged_response('1 RECENT');
               $self->untagged_response('OK [UNSEEN 12] Message 12 is first unseen');
               $self->untagged_response('OK [UIDVALIDITY 3857529045] UIDs valid');
               $self->untagged_response('OK [UIDNEXT 4392] Predicted next UID');
               $self->untagged_response('FLAGS (\Answered \Flagged \Deleted \Seen \Draft)');
               $self->untagged_response('OK [PERMANENTFLAGS (\Deleted \Seen \*)] Limited');
    $self->ok_command("[READ-ONLY] SELECT Completed");
    
}

1;
