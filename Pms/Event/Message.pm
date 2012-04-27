#!/usr/bin/perl -w

=begin nd

  Package: Pms::Event::Message
  
  Description:
    This event is fired when a user tries to send a message
=cut

package Pms::Event::Message;

use strict;
use utf8;
use Pms::Event::Event;
our @ISA = ("Pms::Event::Event");

=begin nd
  Constructor: new
    Initializes the Object
    
  Parameters:
    connection - the <Pms::Core::Connection> object sending the message
    channel    - the receiver (channel-name) of the message
    message    - the message itself
    when       - a unixtimestamp when we received the message
=cut
sub new{
  my $class = shift;
  my $self  = $class->SUPER::new();
  bless($self,$class);
  
  $self->{m_connection} = shift;
  $self->{m_channel}    = shift;
  $self->{m_message}    = shift;
  $self->{m_when}       = shift;
  return $self;
}

=begin nd
  Function: connection
    The connection object
  
  Access:
    Public
    
  Returns:
    ref - The <Pms::Core::Connection> object
=cut
sub connection{
  return $_[0]->{m_connection};
}

=begin nd
  Function: channel
    The name of the receiving channel
  
  Access:
    Public
    
  Returns:
    string - the channel name
=cut
sub channel{
  return $_[0]->{m_channel};
}

=begin nd
  Function: message
    the message to be sent to the channel
  
  Access:
    Public
    
  Returns:
    string - the message itself
=cut
sub message{
  return $_[0]->{m_message};
}

=begin nd
  Function: when
    The unixtimestamp when the message entered the server
  
  Access:
    Public
    
  Parameters:
    
  Returns:
    int - the unix timestamp
=cut
sub when{
  return $_[0]->{m_when};
}
1;