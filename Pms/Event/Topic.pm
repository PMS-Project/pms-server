#!/usr/bin/perl -w

=begin nd

  Package: Pms::Event::Topic
  
  Description:
    This event is fired when a user tries to change the topic
=cut

package Pms::Event::Topic;

use strict;
use utf8;
use Pms::Event::Event;

our @ISA = ("Pms::Event::Event");

=begin nd
  Constructor: new
    Initializes the Object
    
  Parameters:
    connecion - the <Pms::Core::Connection> object doing the topic change
    channel   - the <Pms::Core::Channel> object the user tries to change
    topic     - the new topic the user wants to set
=cut
sub new{
  my $class = shift;
  my $self  = $class->SUPER::new();
  bless($self,$class);
  
  $self->{m_connection} = shift or die "Need Connection Ref";
  $self->{m_channel} = shift or die "Need the Channel Ref";
  $self->{m_topic}   = shift or die "Need the new Topic";
  return $self;
}

=begin nd
  Function: connection
    The connection object that tries to change the topic
  
  Access:
    Public
    
  Returns:
    ref - <Pms::Core::Connection> object doing the topic change
=cut
sub connection{
  return $_[0]->{m_connection};
}

=begin nd
  Function: channel
    The channel to be changed
  
  Access:
    Public
    
  Returns:
    ref - The <Pms::Core::Channel> object the user tries to change
=cut
sub channel{
  return $_[0]->{m_channel};
}

=begin nd
  Function: channelName
    Reads the name of the channel that is going to be changed
  
  Access:
    Public
    
  Returns:
    string - the channel name
=cut
sub channelName{
  return $_[0]->{m_channel}->channelName();
}

=begin nd
  Function: topic
    The new topic that the user tries to set
  
  Access:
    Public
    
  Returns:
    string - the new topic
=cut
sub topic{
  return $_[0]->{m_topic};
}

1;