#!/usr/bin/perl -w

=begin nd

  Package: Pms::Core::Object
  
  Description:
  
  This Package implements the Base Class for all Object in 
  PMS that need to send signals or events.
  
  Every subclass has to define a global Hash called %PmsEvents
  and put all available events in it. Pms::Object will automatically
  check if the event exists if its emitted or connected.
=cut

package Pms::Core::Object;

use strict;
use Object::Event;
use Scalar::Util;

our @ISA = qw(Object::Event);
our %PmsEvents = ('connectionAvailable' => 1);

our $Debug = $ENV{'PMS_DEBUG'};

sub new (){
  my $class = shift;
  my $self  = $class->SUPER::new( );
  bless($self,$class);
  
  return $self;
}

sub connect (){
  my $self = shift;
  my @args = @_;
  
  while(@args){
    my $event = shift @args;
    my $cb    = shift @args;
    
    #Object::Event supports a optional priority argument
    #we maybe need to shift it out
    if(!ref $cb){
      my $cb = shift @args;
    }
    
    if(!$self->_hasEvent($event)){
      die "Unknown Signal/Event $event";
    }
  }
  
  if($Debug){
    warn "Passing Args to reg_cb @_";
  }
  $self->reg_cb(@_);
}

sub emitSignal (){
  my $self = shift;
  my $signal = shift;
  
  #due to performance issues we will only check for firing events in debug mode
  if($Debug){
    if(!$self->_hasEvent($signal)){
        die "Unknown Signal/Event $signal";
    }
  }
  
  return $self->event($signal => @_);
}

sub disconnect (){
  my $self = shift;
  my $guard = shift;

  $self->unreg_cb($guard);
}

sub _hasEvent(){
  my $self = shift;
  my $eventName = shift;
  
  my @currClasses = (Scalar::Util::blessed($self));
  
  return $self->_searchEvent($eventName,@currClasses);
}

sub _searchEvent(){
  my $self = shift;
  my $event = shift;
  my @classes = shift;
  
  #first search the top level classes
  foreach my $currClass (@classes){
    my %events = $self->_getEvents($currClass);
    if (exists $events{$event}) {
      return 1;
    }
  }
  
  #search the next levels
  foreach (@classes){
    my @superClasses = $self->_getSuperClasses($_);
    if(@superClasses){
      if($self->_searchEvent($event,@superClasses)){
        return 1;
      }
    }
  }
  return 0;
}

sub _getSuperClasses(){
  my $self = shift;
  my $class = shift;
  
  #we need to disable strict refs, so we can use symbolic references
  no strict 'refs';
  
  my @classes = @{"${class}::ISA"};
  return @classes;
}

sub _getEvents(){
  my $self = shift;
  my $class = shift;
  
  #we need to disable strict refs, so we can use symbolic references
  no strict 'refs';
  
  my %events = %{"${class}::PmsEvents"};
  return %events;  
}

1;