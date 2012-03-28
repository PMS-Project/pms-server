#!/usr/bin/perl -w

package Pms::Application;

use strict;
use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket;
use Object::Event;

use Pms::Core::Object;
use Pms::Event::Connect;
use Pms::Event::Message;
use Pms::Event::Channel;
use Pms::Event::Join;
use Pms::Event::Leave;

use Pms::Prot::Parser;
use Pms::Core::Connection;
use Pms::Core::ConnectionProvider;
use Pms::Core::Channel;

use Pms::Prot::WebSocket::ConnectionProvider;

our @ISA = qw(Pms::Core::Object);

our $Debug = $ENV{'PMS_DEBUG'};

our %PmsEvents = ( 'client_connected' => 1      # Event is fired if a new Client connects to the server
                 , 'client_disconnected' => 1   # Any client closed the connection
                 , 'new_message' => 1           # Any client sent a message to any channel
                 , 'user_entered_channel' => 1  # A connected user entered a channel
                 , 'user_left_channel' => 1     # A connected user left a channel
                 , 'about_to_create_channel' => 1       # A user tries to create a new channel
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
  $self->{m_users}       = {}; #users to connection map
  $self->{m_channels} = {};
  $self->{m_parser}   = Pms::Prot::Parser->new();
  $self->{m_connectionProvider} = undef;
  $self->{m_dataAvailCallback} = $self->_dataAvailableCallback();
  $self->{m_clientDisconnectCallback} = $self->_clientDisconnectCallback();
  
  $self->{m_channels}{"Test"} = Pms::Core::Channel->new($self,"Test");
  
  
  #build in commands:
  %{$self->{m_buildinCommands}} = ('send' => $self->_sendCommandCallback(),
                                   'join' => $self->_joinChannelCallback(),
                                   'leave' => $self->_leaveChannelCallback(),
                                   'create' => $self->_createChannelCallback(),
                                   'list' => $self->_listChannelCallback(),
                                   'nick' => $self->_changeNickCallback()
                                  );

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
      
      my $event = Pms::Event::Connect->new($connection);
      $self->emitSignal('client_connected' => $event);
    
      if($event->wasRejected()){
        warn "Connection was rejected, reason: ".$event->reason();
        $connection->sendMessage("/serverMessage \"default\" \"Connection rejected: ".$event->reason()."\" ");
        $connection->close();
        next;
      }
      
      #TODO maybe use timestamp for generic username
      my $user = "User";
      my $cnt  = 0;
      while(exists($self->{m_users}->{$user.$cnt})){
        $cnt+=1;
      }
      
      $connection->setUsername($user.$cnt);
      $self->{m_connections}->{ $ident } = $connection;
      $self->{m_users}->{$user.$cnt} = $connection;
      
      #check if there is data available already
      if($connection->messagesAvailable()){
        $self->{m_dataAvailCallback}->($connection);
      }
      #register to connection events
      $connection->connect(dataAvailable => $self->{m_dataAvailCallback},
                           disconnect    => $self->{m_clientDisconnectCallback}
      );
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

sub _clientDisconnectCallback (){
  my $self = shift;
  return sub{
    my ($connection) = @_;
    
    delete $self->{m_connections}->{$connection->identifier()};
    delete $self->{m_users}->{$connection->username()};
  }
}

sub invokeCommand() {
  warn "@_";
  my ($self,$connection,%command) = @_;
  
  #first try to invoke build in commands
  if(exists $self->{m_buildinCommands}{$command{'name'}}){
    warn "Invoking Command: ".$command{'name'};
    #command hash contains a reference to the arguments array
    my @args = @{$command{'args'}};
    $self->{m_buildinCommands}->{$command{'name'}}->( $connection,@args );
  }
}

sub _sendCommandCallback (){
  my $self    = shift;
  
  return sub{
    my $connection = shift;
    my $channel = shift;
    my $message = shift; 
    
    if(!defined $connection){
      #TODO add some error handling
      return;
    }
    
    if(!defined $channel || !defined $message){
      $connection->postMessage("/serverMessage \"default\" \"Wrong Parameters for send command\"");
      return;
    }
    
    if(!defined $self->{m_channels}->{$channel}){
      $connection->postMessage("/serverMessage \"default\" \"Channel does not exist\" ");
    }
    
    my $who  = $connection->username();
    my $when = time();
    
    #TODO put who and when in the event
    my $event = Pms::Event::Message->new($connection,$channel,$message);
    $self->emitSignal('new_message' => $event);
    
    if($event->wasRejected()){
      if($Debug){
        warn "Message was rejected, reason: ".$event->reason();
      }
      $connection->postMessage("/serverMessage \"".$channel."\" \"Message rejected: ".$event->reason()."\" ");
      return;
    }
    
    if($channel eq "default"){
      $connection->postMessage("/message \"".$channel."\" \"".$message."\"");
    }else{
      $self->{m_channels}->{$channel}->sendMessage($who,$when,$message);
    }
  }
}

sub _createChannelCallback(){
  my $self = shift or die "Need Ref";
  
  return sub{
    my $connection = shift;
    my $channel    = shift;
    
    if(!defined $connection){
      #TODO add some error handling
      return;
    }
    
    if(!defined $channel){
      $connection->postMessage("/serverMessage \"default\" \"Wrong Parameters for createChannel command\"");
      return;
    }

    if($channel =~ m/[^\d\w]+/){
      $connection->postMessage("/message \"default\" \"Channelname can only contain digits and word characters\"");
      return;
    }
    
    if(defined $self->{m_channels}{$channel}){
      $connection->postMessage("/serverMessage \"default\" \"Channel $channel already exists\"");
      return;
    }
    
    my $event = Pms::Event::Channel->new($connection,$channel);
    $self->emitSignal(about_to_create_channel => $event);
    if($event->wasRejected()){
      $connection->postMessage("/serverMessage \"default\" \"Can not create the channel: $channel Reason: $event->reason()\"");
      return;
    }
    
    $self->{m_channels}{$channel} = new Pms::Core::Channel($self,$channel);
    
    #let the user enter the channel
    $self->{m_buildinCommands}->{'join'}->($connection,$channel);
    
    #tell all modules the channel was created
    $event = new Pms::Event::Channel($connection,$channel);
    $self->emitSignal(channel_created => $event);
    
  }
}

sub _joinChannelCallback (){
  my $self = shift or die "Need Ref";
  
  return sub{
    my $connection = shift;
    my $channel = shift;
    
    if(!defined $connection){
      #TODO add some error handling
      return;
    }

    if(!defined $channel){
      $connection->postMessage("/serverMessage \"default\" \"Wrong Parameters for join command\"");
      return;
    }

    my $event = Pms::Event::Join->new($connection,$channel);
    $self->emitSignal('user_entered_channel' => $event);

    if($event->wasRejected()){
      if($Debug){
        warn "Join was rejected, reason: ".$event->reason();
      }
      $connection->postMessage("/serverMessage \"default\" \"Join rejected: ".$event->reason()."\" ");
      return;
    }

    if(defined $self->{m_channels}{$channel}){
      $self->{m_channels}{$channel}->addConnection($connection);
    }else{
      $connection->postMessage("/serverMessage \"default\" \"Channel ".$channel." does not exist\" ");
    }
  }
}

sub _leaveChannelCallback (){
  my $self = shift or die "Need Ref";
  
  return sub{
    my $connection = shift;
    my $channel = shift;
    
    if(!defined $connection){
      #TODO add some error handling
      return;
    }
    
    if(!defined $channel){
      $connection->postMessage("/serverMessage \"default\" \"Wrong Parameters for leave command\"");
      return;
    }
    
    my $event = Pms::Event::Leave->new($connection,$channel);
    $self->emitSignal('user_left_channel' => $event);
    
    if(defined $self->{m_channels}{$channel}){
      $self->{m_channels}{$channel}->removeConnection($connection);
    }
    
  }  
}

sub _listChannelCallback (){
  my $self = shift or die "Need Ref";

  return sub{
    my $connection = shift;
    
    if(!defined $connection){
      #TODO add some error handling
      return;
    }

    $connection->postMessage("/serverMessage \"default\" \"Available channels:\"");
    foreach(keys %{ $self->{m_channels} }){
      $connection->postMessage("/serverMessage \"default\" \"$_\"");
    }
  }
}

sub _changeNickCallback (){
  my $self = shift or die "Need Ref";
  
  return sub{
    my $connection = shift;
    my $newname = shift;
    if(!defined $connection){
      #TODO add some error handling
      return;
    }
    
    if(!defined $newname){
      $connection->postMessage("/serverMessage \"default\" \"Wrong Parameters for nick command\"");
      return;     
    }
    
    if($newname eq $connection->username()){
      return;
    }
    
    if(!defined $self->{m_users}->{$newname}){
      delete $self->{m_users}->{$connection->username()};
      $self->{m_users}->{$newname} = $connection;
      $connection->setUsername($newname);
    }else{
      $connection->postMessage("/serverMessage \"default\" \"User $newname already exists\"");
    }
    
  }
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