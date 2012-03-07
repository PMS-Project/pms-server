#!/usr/bin/perl -w

package Pms::Application;

use strict;
use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket;
use Object::Event;

use Pms::Event::Connect;
use Pms::Prot::Parser;
use Pms::Core::Connection;
use Pms::Core::ConnectionProvider;

use Pms::Prot::WebSocket::ConnectionProvider;

our @PmsEvents = ( 'client_connected'       # Event is fired if a new Client connects to the server
                 , 'client_disconnected'    # Any client closed the connection
                 , 'new_message'            # Any client sent a message to any channel
                 , 'user_entered_channel'   # A connected user entered a channel
                 , 'user_left_channel'      # A connected user left a channel
                 , 'channel_created'        # A new channel was created on the server 
                 , 'channel_closed');       # A channel was deleted/closed
  
sub new (){
  my $class = shift;
  my $self  = {};

  bless ($self, $class);

  $self->{m_eventLoop}     = AnyEvent->condvar();

  #TODO check if we can read the name of the signal in the callback
  $self->{m_signalHandler} = AnyEvent->signal (
                              signal => "TERM", 
                              cb     => $self->_termSignalCallback() );

  $self->{m_events}   = Object::Event->new();
  $self->{m_timers}   = ();
  $self->{m_clients}  = ();
  $self->{m_modules}  = ();
  $self->{m_commands} = ();
  $self->{m_connections} = ();
  $self->{m_parser}   = Pms::Prot::Parser->new();
  $self->{m_connectionProvider} = undef;
  $self->{m_dataAvailCallback} = $self->_dataAvailableCallback();
  
  
  #build in commands:
  $self->{m_buildinCommands} = {'send' => $self->_sendCommandCallback(),
                                'join' => $self->_joinChannelCallback(),
                                'leave' => $self->_leaveChannelCallback()};

  return $self;
}

sub execute (){
  my $self = shift;
  
  $self->{m_connectionProvider} = Pms::Prot::WebSocket::ConnectionProvider->new($self);
  $self->{m_connectionProvider}->reg_cb('connectionAvailable' => $self->_newConnectionCallback());
   
  $self->loadModules();
  $self->{m_eventLoop} ->recv; #eventloop
}

sub loadModules (){
  my $self = shift;
  
  opendir (my $dir, 'Pms/modules') or die $!;
  while( my $file = readdir($dir) ){
    next if (!($file =~ m/.*\.pm$/));
    print "Trying to load Module: ".$file,"\n";
    
    my $modname = "Pms/modules/".$file;
    my $basename = $file;
    $basename =~ s{\.pm$}{}g;   
    require $modname;
    
    my $module = $basename->new($self);
    push(@{$self->{m_modules}},$module); 
  }
  closedir $dir;  
}

sub connectEvent (){
  my $self = shift;
  return $self->{m_events}->reg_cb(@_);
}

sub disconnectEvent (){
  my $self = shift;
  my $guard = shift;

  $self->{m_events}->unreg_cb($guard);
}

sub _termSignalCallback(){
  my $self = shift;
  return sub {
    warn "Received TERM Signal\n";
    $PmsApplication::self{m_eventLoop}->send; #Exit from Eventloop
  }  
}

sub _newConnectionCallback(){
  my $self = shift;

  return sub{
    
    while($self->{m_connectionProvider}->connectionsAvailable()){
      my $connection = $self->{m_connectionProvider}->nextConnection();
      $self->{m_connections}{$connection->identifier()} = $connection;
      
      #check if there is data available already
      if($connection->messagesAvailable()){
        $self->{m_dataAvailCallback}->($connection);
      }
      
      #register to connection events
      $connection->reg_cb( {data_available => $self->_dataAvailableCallback() });
    }
  }
}

sub _dataAvailableCallback (){
  my $self = shift;
  return sub {
        my ($connection) = @_;
        
        while($connection->messagesAvailable()){
          my $message = $connection->nextMessage();
          warn "Reveived Message: ".$message;
          
          my %command = $self->{m_parser}->parseMessage($message);
          if(%command){
            invokeCommand(%command);
          }else{
            #do Error handling
          }
        }
    }
}

sub invokeCommand() {
  my $self = shift;
  my $connection = shift;
  my %command = shift;
  
  #first try to invoke build in commands
  if(exists $self->{m_buildinCommands}{$command{'name'}}){
    $self->{m_buildinCommands}{$command{'name'}}->( @{ $command{'args'} } );
  }
}

sub _sendCommandCallback (){
  my $self    = shift;
  
  return sub{
    my $channel = shift;
    my $message = shift;
    
    foreach my $k (keys %{$self->{m_connections}}){
      warn "Key: ".$k;
      if(defined($self->{m_connections}{$k})){
          $self->{m_connections}{$k}->sendMessage($message);
      }  
    }
  }
}

sub _joinChannelCallback (){
  
}

sub _leaveChannelCallback (){
  
}

sub registerCommand (){
  my $self = shift;
  my $command = shift;
  my $cb = shift;
  
  if(!exists ${$self->{m_commands}}{$command}){
    ${$self->{m_commands}}{$command} = $cb;
    return;
  }
  warn "Command ".$command." already exists, did not register it"; 
}


1;