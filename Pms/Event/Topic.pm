#!/usr/bin/perl -w

=begin nd

  Package: Pms::Event::Topic
  
  Description:
  
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
    xxxx - description
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
    <function_description>
  
  Access:
    Public
    
  Parameters:
    
  Returns:
    xxxx
=cut
sub connection{
  return $_[0]->{m_connection};
}

=begin nd
  Function: channel
    <function_description>
  
  Access:
    Public
    
  Parameters:
    
  Returns:
    xxxx
=cut
sub channel{
  return $_[0]->{m_channel};
}

=begin nd
  Function: channelName
    <function_description>
  
  Access:
    Public
    
  Parameters:
    
  Returns:
    xxxx
=cut
sub channelName{
  return $_[0]->{m_channel}->channelName();
}

=begin nd
  Function: topic
    <function_description>
  
  Access:
    Public
    
  Parameters:
    
  Returns:
    xxxx
=cut
sub topic{
  return $_[0]->{m_topic};
}

1;