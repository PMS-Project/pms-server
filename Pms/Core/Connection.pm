#!/usr/bin/perl -w 

=begin nd

  Package: Pms::Core::Connection
  
  Description:
  Represents the connection of a chatuser.
  
  
=cut

package Pms::Core::Connection;

use Pms::Core::Object;
use strict;
use utf8;

our @ISA = qw(Pms::Core::Object);

=begin nd
  Variable: %PmsEvents
  
  Description:
  See <Pms::Core::Object>
=cut
our %PmsEvents = ('dataAvailable' => 1,
                  'disconnect' => 1,
                  'error' => 1,
                  'change_username' => 1
                 );

=begin nd
  Signal: dataAvailable
  
  Description:
    is emitted when new data is available in the buffer
  
  Signal: disconnect
  
  Description:
    is emitted when the socket closes the connection
  
  Signal: error
  
  Description:
    is emitted when there is a error in the connection
  
  Signal: change_username
  
  Description:
    is emitted when the user changes his name
  
  Parameters:
    $olname - the old username
    $newname - the new username
=cut



=begin nd
  Constructor: new
    Initializes the Object
    
  Parameters:
    $fh   - The filedescriptor of the connected socket
    $host - The hostname
    $port - The port number
=cut
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
  
  Access:
    Public
    
  Emits Signal:
    diconnect
=cut
sub close{
  die "This function is virtual, it needs to be implemented in the subclass";  
}

=begin nd
  Function: identifier
    This returns a identifier that uniquely identifies
    the connection object for use in a hash.
  
  Access:
    Public
    
  Parameters:
    
  Returns:
    A unique identifier for the connection Object.
    Can be used in Hashes.
=cut
sub identifier{
  die "This function is virtual, it needs to be implemented in the subclass";  
}

=begin nd
  Function: messagesAvailable
    Checks if messages are watiting in the queue
  
  Access:
    Public
    
  Parameters:
    
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
  
  Access:
    Public
    
  Parameters:
    
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
  
  Access:
    Public
    
  Parameters:
    $message - data to be sent to the user
    
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
    and returns immediately
  
  Access:
    Public
    
  Parameters:
    message - The message to be sent
    
  Returns:

=cut
sub postMessage{
  die "This function is virtual, it needs to be implemented in the subclass";
}

=begin nd
  Function: setUsername
    Changes the username to a new value.
  
  Access:
    Public
    
  Emits Signal:   
    change_username($oldname,$newname)
    
  Parameters:
    username - The new username
    
  Returns:
    
  Note:
    This does NOT check if the user exists in the server
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
    Gets the username of the connection object
  
  Access:
    Public
    
  Parameters:
    
  Returns:
    The username associated with this connection
=cut
sub username{
  return $_[0]->{m_user};
}

1;