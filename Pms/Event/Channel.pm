#!/usr/bin/perl -w

=begin nd

  Package: Pms::Event::Channel
  
  Description:
    This Event is fired anytime when a Channel is opened
    or closed.
  
=cut

package Pms::Event::Channel;

use strict;
use utf8;
use Pms::Event::Event;

our @ISA = ("Pms::Event::Event");

=begin nd
  Constructor: new
    Initializes the Object
    
  Parameters:
    connection - the connection object triggering the change
    channel    - the name of the channel
=cut
sub new{
  my $class = shift;
  my $self  = $class->SUPER::new();
  bless($self,$class);
  
  $self->{m_connection}  = shift;
  $self->{m_channel} = shift;
  $self->{m_closing} = 0; #set this to true to indicate the channel is closing
  
  return $self;
}

=begin nd
  Function: setClosing
    Sets the close flag to true.
    
    Indicates that the Channel is in closing state
  
  Access:
    Public
    
  Returns:
    1 - for closing state
    0 - for opening state
=cut
sub setClosing{
  $_[0]->{m_closing} = $_[1];
}

=begin nd
  Function: isClosing
    Returns the closing flag
  
  Access:
    Public
    
  Returns:
    1 or 0 see <isClosing> for meaning
=cut
sub isClosing{
  return $_[0]->{m_closing};
}

=begin nd
  Function: channelName
    The channel name
  
  Access:
    Public
    
  Returns:
    A *string* containing the channel name
=cut
sub channelName{
  return $_[0]->{m_channel};
}

=begin nd
  Function: connection
    Returns the user connection object
  
  Access:
    Public
    
  Returns:
    A reference to a <Pms::Core::Connection> instance
=cut
sub connection{
  return $_[0]->{m_connection};
}

1;