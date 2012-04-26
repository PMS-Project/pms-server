#!/usr/bin/perl -w 
package Pms::Core::Connection;

use Pms::Core::Object;
use strict;
use utf8;

our @ISA = qw(Pms::Core::Object);

our %PmsEvents = ('dataAvailable' => 1,
                  'disconnect' => 1,
                  'error' => 1,
                  'change_username' => 1
                 );

sub new {
  my $class = shift;
  my $self = $class->SUPER::new( );
  bless($self,$class);
  
  $self->{m_fh}     = shift or die "Connection needs a Socket Handle";
  $self->{m_host}   = shift or die "Connection needs a Host Value";
  $self->{m_port}   = shift or die "Connection needs a Port Value";
  $self->{m_user}   = undef;
  $self->{m_buffer} = []; #internal read buffer
  
  return $self;
}

=begin nd
 Function: close
 
 Closes the connection to the other side
 
=cut
sub close{
  die "This function is virtual, it needs to be implemented in the subclass";  
}


=begin nd
 Function: identifier
 
 Returns: 
 a unique identifier for the connection Object.
 Can be used in Hashes.
 
=cut
sub identifier{
  die "This function is virtual, it needs to be implemented in the subclass";  
}


=begin nd
 Function: messagesAvailable
 
 Returns: 
 The number of messages in the internal buffer
 
=cut
sub messagesAvailable{
  my $self = shift or die "Need Ref";
  
  #return the number of messages
  my $count = @{ $self->{m_buffer} };
  return $count;
}

=begin nd
 Function: nextMessage
 
 Removes the next Message from the internal Buffer and returns it
 
 Returns: 
 The next message
 
=cut
sub nextMessage{
  my $self = shift or die "Need Ref";
  
  my $message = shift(@{ $self->{m_buffer} });
  return $message;
}

=begin nd
 Function: sendMessage
 
 Directly sends a message to the client, bypassing
 the write queue
 
 Parameters:
    message - The message to be sent
 
 Note:
 Do not use this, most of the time you want to use
 postMessage instead. 
=cut
sub sendMessage{
  die "This function is virtual, it needs to be implemented in the subclass";
}

=begin nd
 Function: postMessage
 
 Enqueues the message into the internal write queue
 
 Parameters:
    message - The message to be sent
 
=cut
sub postMessage{
  die "This function is virtual, it needs to be implemented in the subclass";
}

=begin nd
 Function: setUsername
 
 Changes the username to a new value.
 
 Warning:
    This does NOT check if the user exists in the server
 
 Parameters:
    username - The new username
 
=cut
sub setUsername{
  my $self = shift or die "Need Ref";
  my $name = shift or die "Need Name";
  my $oldname = $self->{m_user};
  
  
  $self->{m_user} = $name;
  $self->emitSignal(change_username => $oldname,$name);
}

=begin nd
 Function: username
 
 Returns: 
 The username associated with this connection
=cut
sub username{
  return $_[0]->{m_user};
}

1;