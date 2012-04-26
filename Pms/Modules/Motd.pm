#!/usr/bin/perl -w

=begin nd

  Package: Pms::Modules::Motd
  
  Description:
  
=cut

package Pms::Modules::Motd;

use strict;
use utf8;
use Pms::Event::Connect;
use Pms::Prot::Messages;
use Data::Dumper;

=begin nd
  Constructor: new
    Initializes the Object
    
  Parameters:
    xxxx - description
=cut
sub new{
  my $class = shift;
  my $self  = {};
  bless ($self, $class);
  
  $self->{m_parent} = shift;
  $self->{m_config} = shift;
  $self->{m_eventGuard} = undef;
  $self->initialize();
  
  if(!defined $self->{m_config}){
    die "Need a line to print";
  }
  
  warn "Motd Module created";
  return $self;
}

=begin nd
  Destructor: DESTROY
    Initializes the Object
    
  Parameters:
=cut
sub DESTROY{
  my $self = shift;
  $self->shutdown();
}

=begin nd
  Function: initialize
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
=cut
sub initialize{
  my $self = shift;
  $self->{m_eventGuard} = $self->{m_parent}->connect( 
    client_connect_success => sub{
      my $eventChain = shift;
      my $eventType  = shift;
      
      $eventType->connection()->postMessage(Pms::Prot::Messages::serverMessage("default",$self->{m_config}));
    }
  );
}

=begin nd
  Function: shutdown
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
=cut
sub shutdown (){
  my $self = shift;
  warn "Shutting Down";
  $self->{m_parent}->disconnect($self->{m_eventGuard});
}

1;