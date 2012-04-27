#!/usr/bin/perl -w

=begin nd

  Package: Pms::Event::Join
  
  Description:
    This Event is fired if a user tries to join 
    a channel.
=cut

package Pms::Event::Join;

use strict;
use utf8;
use Pms::Event::Event;

our @ISA = ("Pms::Event::Event");

=begin nd
  Constructor: new
    Initializes the Object
    
  Parameters:
    connection - the <Pms::Core::Connection> object which is doing the join
    channel    - the <Pms::Core::Channel> object the user tries to join into
=cut
sub new{
  my $class = shift;
  my $self  = $class->SUPER::new();
  bless($self,$class);
  
  $self->{m_connection} = shift;
  $self->{m_channel}    = shift;
  return $self;
}

=begin nd
  Function: channel
    Reads the channel object
  
  Access:
    Public
    
  Returns:
    ref - reference to the <Pms::Core::Channel> object
=cut
sub channel{
  return $_[0]->{m_channel};
}

=begin nd
  Function: channelName
    Reads the channel name
  
  Access:
    Public
    
  Returns:
    string - the channel name
=cut
sub channelName{
  return $_[0]->{m_channel}->channelName();
}

=begin nd
  Function: connection
    Reads the connection object
  
  Access:
    Public
    
  Returns:
    ref - the <Pms::Core::Connection> object
=cut
sub connection{
  return $_[0]->{m_connection};
}
1;