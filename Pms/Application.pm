#!/usr/bin/perl -w

package Pms::Application;

use strict;
use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket;
use Object::Event;

use Pms::Core::Object;
use Pms::Event::Connect;
use Pms::Prot::Parser;
use Pms::Core::Connection;
use Pms::Core::ConnectionProvider;

use Pms::Prot::WebSocket::ConnectionProvider;

our @ISA = qw(Pms::Core::Object);

our $Debug = $ENV{'PMS_DEBUG'};

our %PmsEvents = ( 'client_connected' => 1      # Event is fired if a new Client connects to the server
                 , 'client_disconnected' => 1   # Any client closed the connection
                 , 'new_message' => 1           # Any client sent a message to any channel
                 , 'user_entered_channel' => 1  # A connected user entered a channel
                 , 'user_left_channel' => 1     # A connected user left a channel
                 , 'channel_created' => 1       # A new channel was created on the server 
                 , 'channel_closed' => 1);      # A channel was deleted/closed
  
sub new (){
  my $class = shift;
  my $self = $class->SUPER::new( );
  
  bless ($self, $class);
  
  if($Debug){
    my $test = Pms::Core::Object->new();
    if(!$test->_hasEvent("muhls")){
      warn "Test 1 ok";
    }else{
      warn "Test 2 failed";
    }
    
    if($test->_hasEvent("connectionAvailable")){
      warn "Test 2 ok";
    }else{
      warn "Test 2 failed";
    }
  }

  $self->{m_eventLoop}     = AnyEvent->condvar();

  #TODO check if we can read the name of the signal in the callback
  $self->{m_signalHandler} = AnyEvent->signal (
                              signal => "TERM", 
                              cb     => $self->_termSignalCallback() );

  $self->{m_timers}   = [];
  $self->{m_clients}  = [];
  $self->{m_modules}  = [];
  $self->{m_commands} = [];
  $self->{m_connections} = {};
  $self->{m_parser}   = Pms::Prot::Parser->new();
  $self->{m_connectionProvider} = undef;
  $self->{m_dataAvailCallback} = $self->_dataAvailableCallback();
  
  
  #build in commands:
  %{$self->{m_buildinCommands}} = ('send' => $self->_sendCommandCallback(),
                                   'join' => $self->_joinChannelCallback(),
                                   'leave' => $self->_leaveChannelCallback());

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
    my $connProvider = shift;
    my $count = $connProvider->connectionsAvailable;
    
    while($connProvider->connectionsAvailable()){
      my $connection = $connProvider->nextConnection();
      my $ident = $connection->identifier();
      $self->{m_connections}->{ $ident } = $connection;
      
      #check if there is data available already
      if($connection->messagesAvailable()){
        $self->{m_dataAvailCallback}->($connection);
      }
      #register to connection events
      $connection->reg_cb(dataAvailable => $self->{m_dataAvailCallback});
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
          if(keys %command){
            $self->invokeCommand($connection,%command);
          }else{
            warn "Empty ".$self->{m_parser}->{m_lastError};
            #do Error handling
          }
        }
    }
}

sub invokeCommand() {
  warn "@_";
  my ($self,$connection,%command) = @_;
  
  #first try to invoke build in commands
  if(exists $self->{m_buildinCommands}{$command{'name'}}){
    
    #command hash contains a reference to the arguments array
    my @args = @{$command{'args'}};
    $self->{m_buildinCommands}->{$command{'name'}}->( @args );
  }
}

sub _sendCommandCallback (){
  my $self    = shift;
  
  return sub{
    my $channel = shift;
    my $message = shift;
    
    foreach my $k (keys %{$self->{m_connections}}){
      warn "Key: ".$k;
      warn "Message: ".$message;
      if(defined($self->{m_connections}{$k})){
          $self->{m_connections}{$k}->postMessage("/message \"default\" \"".$message."\"");
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
  
  if(!exists $self->{m_commands}->{$command}){
    $self->{m_commands}->{$command} = $cb;
    return;
  }
  warn "Command ".$command." already exists, did not register it"; 
}


1;