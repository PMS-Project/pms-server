#!/usr/bin/perl -w

=begin nd

  Package: Pms::Core::Object
  
  Description:
  
  This Package implements the Base Class for all Object in 
  PMS that need to send signals or events.
  
  Every subclass has to define a global Hash called %PmsEvents
  and put all available events in it. 
  
  Pms::Object will automatically check if the event exists when it is emitted or connected.
  
  (start code)
  our %PmsEvents = (
    signal_foo => 1,
    signal_bar => 1
  );
  (end)
=cut

package Pms::Core::Object;

use strict;
use utf8;
use Object::Event;
use Scalar::Util;

our @ISA = qw(Object::Event);
our %PmsEvents = ();

our $Debug = $ENV{'PMS_DEBUG'};

=begin nd
  Constructor: new
    Initializes the Object
=cut
sub new {
  my $class = shift;
  my $self  = $class->SUPER::new( );
  bless($self,$class);
  
  return $self;
}

=begin nd
  Function: connect
    connects a callback to a signal supports also multiple connects
    
    (start code)
    $guard = $object->connect(
      dataAvailable => $self->dataAvailableCallback(),
      disconnect    => $self->disconnectCallback()
    );
    (end)
  Note:
    This will die if the signal does not exist
  
  Access:
    Public
    
  Parameters:
    connections - a hash containing all signal => callback associations
    
  Returns:
    The return value $guard will be a guard that represents the set of callbacks you have installed. 
    
    You can either just "forget" the contents of $guard to unregister the callbacks or call disconnect with that ID to remove those callbacks again. 
    
    If connect is called in a void context no guard is returned and you have no chance to unregister the registered callbacks.
=cut
sub connect {
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
    warn "PMS-Core> ". "Passing Args to reg_cb @_";
  }
  $self->reg_cb(@_);
}

=begin nd
  Function: emitSignal
    Fires a signal and passes all arguments to the callback,
    First argument in the callback is always the Object emitting
    the signal.
    
  Note:
    Even if this is a public function the common use case is to
    not emit a signal from the outside of the object.
  
  Access:
    Public
    
  Parameters:
    $signal - the name of the signal to emit
    @args   - any number of arguments that should be available in the callback
    
  Returns:
    0 if it was not possible to emit the signal
    1 is the signal was emitted
=cut
sub emitSignal {
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

=begin nd
  Function: disconnect
    Remove a connection or a set of connections to callbacks.
  
  Access:
    Public
    
  Parameters:
    $guard - The event guard returned by <connect>
=cut
sub disconnect {
  my $self = shift;
  my $guard = shift;

  $self->unreg_cb($guard);
}

=begin nd
  Function: _hasEvent
    Checks if the current class-hierarchy has a signal or not
  
  Access:
    Private
    
  Parameters:
    $signal - The name of the signal we are looking for
    
  Returns:
    1 - for yes
    0 - for no
=cut
sub _hasEvent{
  my $self = shift;
  my $eventName = shift;
  
  my @currClasses = (Scalar::Util::blessed($self));
  
  return $self->_searchEvent($eventName,@currClasses);
}

=begin nd
  Function: _searchEvent
    Iterates over the Object hierarchy and searches 
    for the event. 
    This function is recursive and climbs up the inheritance
    tree to find the event.
    It starts to search in the leaves up to the root.
  
  Access:
    Private
    
  Parameters:
    $signal - The name of the signal we are looking for
    @classes - A list of the classes we want to look into
    
  Returns:
    1 - for yes
    0 - for no
=cut
sub _searchEvent{
  my $self = shift;
  my $event = shift;
  my @classes = shift;
  
  #first search the leaves
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

=begin nd
  Function: _getSuperClasses
    Tries to find the super classes of a given class
  
  Access:
    Private
    
  Parameters:
    $class - The child class of which we want to know the parents
    
  Returns:
    A array of superclasses (The ISA array of the class)
=cut
sub _getSuperClasses{
  my $self = shift;
  my $class = shift;
  
  #we need to disable strict refs, so we can use symbolic references
  no strict 'refs';
  
  my @classes = @{"${class}::ISA"};
  return @classes;
}

=begin nd
  Function: _getEvents
    Tries to search the %pmsEvents hash of a given class
  
  Access:
    Private
    
  Parameters:
    $class - The class of which we want to know the events
    
  Returns:
    a hash containins the events (the %pmsEvents hash of the class)
=cut
sub _getEvents{
  my $self = shift;
  my $class = shift;
  
  #we need to disable strict refs, so we can use symbolic references
  no strict 'refs';
  
  my %events = %{"${class}::PmsEvents"};
  return %events;  
}

1;