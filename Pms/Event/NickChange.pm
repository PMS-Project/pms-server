#!/usr/bin/perl -w

=begin nd

  Package: Pms::Event::NickChange
  
  Description:
    This Event is fired when a user tries to change his nick
  
=cut

package Pms::Event::NickChange;

use strict;
use utf8;
use Pms::Event::Event;
our @ISA = ("Pms::Event::Event");

=begin nd
  Constructor: new
    Initializes the Object
    
  Parameters:
    connection - the <Pms::Core::Connection> object doing the nickchange
    oldname    - the old username
    newname    - the new username
=cut
sub new{
  my $class = shift;
  my $self  = $class->SUPER::new();
  bless($self,$class);
  
  $self->{m_connection} = shift;
  $self->{m_oldname}    = shift;
  $self->{m_newname}    = shift;
  return $self;
}

=begin nd
  Function: newName
    The new nickname the user tries to switch to
  
  Access:
    Public
    
  Returns:
    string - new username
=cut
sub newName{
  my $self = shift or die "Need Ref";
  return $self->{m_newname};
}

=begin nd
  Function: oldName
    The current name of the user
  
  Access:
    Public
    
  Returns:
    string - the current name
=cut
sub oldName{
  my $self = shift or die "Need Ref";
  return $self->{m_oldname};
}

=begin nd
  Function: connection
    The connection object of the user
  
  Access:
    Public
    
  Parameters:
    
  Returns:
    ref - <Pms::Core::Connection> the connection object associated with the user
=cut
sub connection{
  my $self = shift or die "Need Ref";
  return $self->{m_connection};
}
1;