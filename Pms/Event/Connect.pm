#!/usr/bin/perl -w

=begin nd

  Package: Pms::Event::Connect
  
  Description:
  This event is fired when a new connection 
  is established from a client
  
=cut

package Pms::Event::Connect;

use strict;
use utf8;
use Pms::Event::Event;

our @ISA = ("Pms::Event::Event");

=begin nd
  Constructor: new
    Initializes the Object
    
  Parameters:
    connection - the <Pms::Core::Connection> object representing the connect
=cut
sub new{
  my $class = shift;
  my $self  = $class->SUPER::new();
  bless($self,$class);
  
  $self->{m_connection} = shift;
  return $self;
}

=begin nd
  Function: connection
    Gets the connection object
  
  Access:
    Public
    
  Parameters:
    
  Returns:
    A *ref* to a <Pms::Core::Connection> object
=cut
sub connection{
  my $self = shift;
  return $self->{m_connection};
}
1;