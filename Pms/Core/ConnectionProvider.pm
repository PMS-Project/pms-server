#!/usr/bin/perl -w

=begin nd

  Package: Pms::Core::ConnectionProvider
  
  Description:
  Implements the base class for all ConnectionProviders.
  A ConnectionProvider is a object that can accept incoming
  connection on a special device for example a Socket or 
  a HTTP Request.
=cut

=begin nd
  Signal: connectionAvailable()
  
  Description:
  is emitted when a new connection is enqueued
=cut

package Pms::Core::ConnectionProvider;

use strict;
use utf8;
use Pms::Core::Object;

our @ISA = qw(Pms::Core::Object);

=begin nd
  Variable: %PmsEvents
  
  Description:
  See <Pms::Core::Object>
=cut
our %PmsEvents = ('connectionAvailable' => 1);

=begin nd
  Constructor: new
    Initializes the Object
    
  Parameters:
    $parent - the <Pms::Application> object
=cut
sub new {
  my $class = shift;
  my $self = $class->SUPER::new( );
  
  bless($self,$class);
  
  $self->{m_parent} = shift or die "needs a reference to parent";
  $self->{m_connectionQueue} = [];
  
  return $self;
  
}

=begin nd
  Function: nextConnection
    Returns the next pending connection in the queue
  
  Access:
    Public
    
  Returns:
    *undef* if no connection is available
    or a <Pms::Core::Connection> reference
=cut
sub nextConnection{
  my $self = shift or die "No Ref";
  
  my $connection = shift(@{ $self->{m_connectionQueue} });
  return $connection;
}

=begin nd
  Function: connectionAvailable
    Checks if there are pending connections
  
  Access:
    Public
    
  Returns:
    the number of pending connections
=cut
sub connectionsAvailable{
  my $self = shift or die "No Ref";
  my $count = @{ $self->{m_connectionQueue} };
  return $count;
}

1;