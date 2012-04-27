#!/usr/bin/perl -w

=begin nd

  Package: Pms::Event::Disconnect
  
  Description:
    This event is fired when a user disconnects 
    from the server.
  
=cut

package Pms::Event::Disconnect;
use strict;
use utf8;
use Pms::Event::Event;


our @ISA = ("Pms::Event::Event");

=begin nd
  Constructor: new
    Initializes the Object
    
  Parameters:
    connection - the <Pms::Core::Connection> object doing the disconnect
=cut
sub new{
  my $class = shift;
  my $self  = $class->SUPER::new();
  bless($self,$class);
  
  $self->{m_connection} = shift or die "Need Connection";
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
  return $_[0]->{m_connection};
}
1;