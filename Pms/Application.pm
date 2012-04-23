#!/usr/bin/perl -w

package Pms::Application;

use strict;
use utf8;
use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket;
use Object::Event;

use Pms::Core::Object;
use Pms::Event::Connect;
use Pms::Event::Disconnect;
use Pms::Event::Message;
use Pms::Event::Channel;
use Pms::Event::Join;
use Pms::Event::Leave;
use Pms::Event::NickChange;
use Pms::Event::Command;
use Pms::Event::Topic;

use Pms::Prot::Parser;
use Pms::Prot::Messages;
use Pms::Core::Connection;
use Pms::Core::ConnectionProvider;
use Pms::Core::Channel;

our @ISA = qw(Pms::Core::Object);

our $Debug = $ENV{'PMS_DEBUG'};

our %PmsEvents = ( 'client_connect_request' => 1        # Event is fired if a new Client tries to connect to the server
                 , 'client_connect_success' => 1        # Event is fired if a new Client connects to the server
                 , 'client_disconnect_success' => 1     # Any client closed the connection
                 , 'message_send_request' => 1          # Any client asks if he can send a message to any channel
                 , 'message_send_success' => 1              # Any client has sent a message to any channel
                 , 'join_channel_request' => 1          # User requests to join a channel
                 , 'join_channel_success' => 1           # A connected user entered a channel
                 , 'leave_channel_success' => 1     # A connected user left a channel
                 , 'create_channel_request' => 1       # A user tries to create a new channel
                 , 'create_channel_success' => 1       # A new channel was created on the server 
                 , 'channel_close_success' => 1      # A channel was deleted/closed
                 , 'change_nick_request' => 1        # A user tries to change his nickname
                 , 'change_nick_success' => 1        # A user has changed his nickname
                 , 'change_topic_request' => 1        # A user tries to change a channel topic
                 , 'change_topic_success' => 1        # A user has changed a channel topic
                 , 'execute_command_request' => 1     # A user tries to execute a custom command
                 );
  
sub new{
  my $class = shift;
  my $self = $class->SUPER::new( );
  bless ($self, $class);
  
  $self->{m_config} = shift;     
  
  warn $self->{m_config};
  
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

  $self->{m_modules}     = {};
  $self->{m_commands}    = {};
  $self->{m_connections} = {};
  $self->{m_users}       = {}; #users to connection map
  $self->{m_channels}    = {};
  $self->{m_lastError}   = undef;
  $self->{m_parser}      = Pms::Prot::Parser->new();
  $self->{m_connectionProvider} = undef;
  $self->{m_dataAvailCallback} = $self->_dataAvailableCallback();
  $self->{m_clientDisconnectCallback} = $self->_clientDisconnectCallback();
  
  #build in commands:
  %{$self->{m_buildinCommands}} = ('send' => $self->_sendCommandCallback(),
                                   'join' => $self->_joinChannelCallback(),
                                   'leave' => $self->_leaveChannelCallback(),
                                   'create' => $self->_createChannelCallback(),
                                   'list' => $self->_listChannelCallback(),
                                   'nick' => $self->_changeNickCallback(),
                                   'users' => $self->_listUsersCallback(),
                                   'topic' => $self->_topicCallback()
                                  );

  return $self;
}

sub execute{
  my $self = shift or die "Need Ref";
  
  $self->_loadConnectionProviders();
  $self->_loadModules();
  
  warn "Starting the Eventloop, listening for Connections";
  $self->{m_eventLoop} ->recv; #eventloop
}

sub _loadConnectionProviders{
  my $self = shift or die "Need Ref";
  if(!defined $self->{m_config}->{connectionProviders}){
    die "No Connectionprovider defined, edit Config.pm and add one";
  }
  
  foreach my $curr (@{ $self->{m_config}->{connectionProviders} }){
    if(!defined $curr->{name}){
      die "No name defined in ConnectionProvider";
    }
    
    warn "Trying to load ConnectionProvider: $curr->{name} ";
    
    my $name = $curr->{name};
    eval "require $name" or die "Could not load ConnectionProvider: $name error: $@";;
    
    my $module = $name->new($self,$curr->{config});
    $self->{m_connectionProvider}->{$name} = $module;
    $module->reg_cb('connectionAvailable' => $self->_newConnectionCallback());
  }
}

sub _loadModules{
  my $self = shift or die "Need Ref";
  if(!defined $self->{m_config}->{modules}){
    return,
  }
  
  foreach my $curr (@{ $self->{m_config}->{modules} }){
    if(!defined $curr->{name}){
      die "No name defined in Module";
    }    
    if(defined $curr->{requires}){
      if(!$self->isModuleLoaded($curr->{requires})){
        die "Module $curr->{name} requires module $curr->{requires}";
      }
    }
    
    my $name = $curr->{name};
    warn "Trying to load Module: $curr->{name} ";
    
    eval "require $name" or die "Could not load module: $name error: $@";
    my $module = $name->new($self,$curr->{config});
    $self->{m_modules}->{$name} = $module;
  }
}

=begin nd
  Function: getModule
    Return the instance of a module when it was loaded.
  
  Access:
    Public
    
  Returns:
    The reference to the module instance
    undef if the module is not known or not loaded
=cut
sub getModule{
  my $self = shift or die "Need Ref";
  my $fqn  = shift or die "Need FQN";
  
  return $self->{m_modules}->{$fqn};
  
}

=begin nd
  Function: isModuleLoaded
    Checks if a module is loaded or not
  
  Access:
    Public
    
  Returns:
    1 for yes
    0 for no
=cut
sub isModuleLoaded{
  my $self = shift or die "Need Ref";
  my $fqn  = shift or die "Need FQN";
  
  if(defined $self->{m_modules}->{$fqn}){
    return 1;
  }
  return 0;
  
}

=begin nd
  Function: createUniqueNickname
    Creates and returns a Nickname that does not yet exist on the server
  
  Access:
    Public
    
  Returns:
    The new nickname
=cut
sub createUniqueNickname{
      my $self = shift or die "Need Ref";
      #TODO maybe use timestamp for generic username
      my $user = "User";
      my $cnt  = 0;
      while(exists($self->{m_users}->{$user.$cnt})){
        $cnt+=1;
      }
      return ($user.$cnt);
}

=begin nd
  Function: nicknameToConnection
    Returns the connection associated with the nickname
  
  Access:
    Public
    
  Parameters:
    $nickname - The nickname we are looking for
    
  Returns:
    The connection associated with the nickname or undef if none exists
=cut
sub nicknameToConnection{
  my $self = shift or die "Need Ref";
  my $nick = shift or die "Need Nickname";
  
  if(defined $self->{m_users}->{$nick}){
    return $self->{m_users}->{$nick};
  }
  return undef;
}

=begin nd
  Function: changeNick
    Changes the Nick of a connected User
    
  Note:
    changeNick will not send a change_nick_request event , 
    this has to be done by the caller
  
  Access:
    Public
    
  Parameters:
    $connection - The User connection Object
    $newNick    - The New Nickname 
    $force      - If the nick already exists , force the change (optional, default value is false)
    
  Returns:
    0 - for failed
    1 - for success
=cut
sub changeNick{
  my $self = shift or die "Need Ref";
  my $connection = shift or die "Need Connection Object";
  my $newNick    = shift or die "Need a new Nick Argument";
  my $force      = shift;
  if(!defined $force){
    warn "Setting force to 0";
    $force = 0;
  }
  
  $self->{m_lastError} = undef;
  
  #already the correct nick -> ignore it
  if($newNick eq $connection->username()){
      return;
  } 
  
  if(defined $self->{m_users}->{$newNick}){
    #If the nick already exists and force is set to 1 we have to rename a other connection
    #to set the nickname
    if($force == 1){
        my $newname = $self->createUniqueNickname();
        my $otherConnection = $self->nicknameToConnection($newNick);
        my $oldname = $otherConnection->username();
        
        my $event = Pms::Event::NickChange->new($otherConnection,$oldname,$newname);
        
        delete $self->{m_users}->{$otherConnection->username()};
        $self->{m_users}->{$newname} = $otherConnection;
        $otherConnection->setUsername($newname);
        
        #tell the modules we changed a nick
        $self->emitSignal('change_nick_success' => $event);   
        $self->sendBroadcast(Pms::Prot::Messages::nickChangeMessage($oldname,$newname));
    }else{
      $self->{m_lastError} = "User $newNick already exists";
      return 0;
    }
  }
  
  #do the actual nick change
  my $oldNick = $connection->username();
  my $event = Pms::Event::NickChange->new($connection,$oldNick,$newNick);
  
  delete $self->{m_users}->{$connection->username()};
  $self->{m_users}->{$newNick} = $connection;
  $connection->setUsername($newNick);
      
  $self->emitSignal('change_nick_success' => $event);
  $self->sendBroadcast(Pms::Prot::Messages::nickChangeMessage($oldNick,$newNick));
 
  return 1; #success
}

=begin nd
  Function: joinChannel
    Adds a connection to a existing Channel
  
  Access:
    Public
    
  Parameters:
    $connection  - The User connection Object
    $channelName - The Channel Name
    $force       - Don't ask for Permission (don't send the  join_channel_request event)
    
  Returns:
    0 - for failed
    1 - for success
=cut
sub joinChannel{
  my $self = shift or die "Need Ref";
  my $connection = shift or die "Need Connection";
  my $channelName = shift or die "Need Channel Name";
  my $force       = shift;
  
  if(!defined $force){
    $force = 0;
  }
  
  if(!defined $self->{m_channels}{$channelName}){
    $self->{m_lastError} = "Channel $channelName does not exist";
    return 0;
  }
  
  my $channel = $self->{m_channels}{$channelName};
  if($channel->hasConnection($connection->identifier())){
    #we are already in the channel
    $connection->postMessage(Pms::Prot::Messages::serverMessage("default","You are already in the Channel $channelName"));
    return 1;
  }
  my $event = Pms::Event::Join->new($connection,$channel);
  if(!$force){
    $self->emitSignal('join_channel_request' => $event);

    if($event->wasRejected()){
      if($Debug){
        warn "Join was rejected, reason: ".$event->reason();
      }
      $self->{m_lastError} = $event->reason();
      return 0;
    }
  }
  
  $channel->addConnection($connection);
  $self->emitSignal('join_channel_success' => $event); 
  
  return 1;
}

=begin nd
  Function: createChannel
    Creates and opens a Channel. If the connection Object is valid,
    the Connection is added to the Channel (join)
  
  Access:
    Public
    
  Parameters:
    $connection  - The User connection Object (optional)
    $channelName - The Channel Name
    $force       - Don't ask for Permission (don't send the  create_channel_request event)
    
  Returns:
    0 - for failed
    1 - for success
=cut
sub createChannel{
  my $self = shift or die "Need Ref";
  my $connection = shift;
  my $channelName= shift or die "Need Channel Name";
  my $force      = shift;
  
  if(!defined $force){
    $force = 0;
  }
  
  if($channelName =~ m/[^\d\w]+/){
    $self->{m_lastError} = "Channelname can only contain digits and letters";
    return 0;
  }
  
  if(defined $self->{m_channels}{$channelName}){
    $self->{m_lastError} = "Channel $channelName already exists";
    return 0;
  }
  
  if(!$force){
    my $event = Pms::Event::Channel->new($connection,$channelName);
    $self->emitSignal(create_channel_request => $event);
    if($event->wasRejected()){
      $self->{m_lastError} = $event->reason();
      return 0;
    }   
  }
  
  $self->{m_channels}{$channelName} = new Pms::Core::Channel($self,$channelName);
  
  if(defined $connection){
    #let the user enter the channel
    $self->joinChannel($connection,$channelName,1);
  }
  
  #tell all modules the channel was created
  my $event = Pms::Event::Channel->new($connection,$channelName);
  $self->emitSignal(create_channel_success => $event);
  return 1;
}

sub channel{
  my $self = shift or die "Need Ref";
  my $channelName = shift or die "Need Channel Name";
  
  if(!defined $self->{m_channels}->{$channelName}){
    $self->{m_lastError} = "Channel not known";
    return undef;
  }
  
  return $self->{m_channels}->{$channelName};
  
}

sub registerCommand{
  my $self = shift or die "Need Ref";
  my $command = shift or die "Need Command";
  my $cb = shift or die "Need Callback";
  
  if(!exists $self->{m_commands}->{$command}){
    $self->{m_commands}->{$command} = $cb;
    return;
  }
  warn "Command ".$command." already exists, did not register it"; 
}

sub channels{
  my $self = shift or die "Need Ref";
  return keys(%{ $self->{m_channels} });        
}

sub sendBroadcast{
  my $self = shift or die "Need Ref";
  my $message = shift or die "Need Message";
  foreach my $curr(keys %{$self->{m_connections}}){
    $self->{m_connections}->{$curr}->postMessage($message);
  }
}

sub _termSignalCallback{
  my $self = shift;
  return sub {
    warn "Received TERM Signal\n";
    $self->{m_eventLoop}->send; #die from Eventloop
  }  
}

sub _newConnectionCallback{
  my $self = shift or die "Need Ref";

  return sub{
    my $connProvider = shift;
    my $count = $connProvider->connectionsAvailable;
    
    while($connProvider->connectionsAvailable()){
      my $connection = $connProvider->nextConnection();
      my $ident = $connection->identifier();
      
      my $event = Pms::Event::Connect->new($connection);
      $self->emitSignal('client_connect_request' => $event);
    
      if($event->wasRejected()){
        warn "Connection was rejected, reason: ".$event->reason();
        $connection->sendMessage("/serverMessage \"default\" \"Connection rejected: ".$event->reason()."\" ");
        $connection->close();
        next;
      }
      
      my $username = $self->createUniqueNickname();
      
      $connection->setUsername($username);
      $self->{m_connections}->{ $ident } = $connection;
      $self->{m_users}->{$username} = $connection;
      
      #register to connection events
      $connection->connect(dataAvailable => $self->{m_dataAvailCallback},
                           disconnect    => $self->{m_clientDisconnectCallback}
      );

      $self->emitSignal('client_connect_success' => $event);
      
      #tell the client its nick
      $connection->postMessage(Pms::Prot::Messages::nickChangeMessage("",$username));
      
      #check if there is data available already
      if($connection->messagesAvailable()){
        $self->{m_dataAvailCallback}->($connection);
      }
    }
  }
}

sub _dataAvailableCallback{
  my $self = shift or die "Need Ref";
  return sub {
        my ($connection) = @_;
        while($connection->messagesAvailable()){
          my $message = $connection->nextMessage();
          warn "Reveived Message: ".$message if($Debug);
          
          my %command = $self->{m_parser}->parseMessage($message);
          if(keys %command){
            $self->invokeCommand($connection,\%command);
          }else{
            warn "Empty ".$self->{m_parser}->{m_lastError};
            #do Error handling
          }
        }
    }
}

sub _clientDisconnectCallback{
  my $self = shift or die "Need Ref";
  return sub{
    my ($connection) = @_;
    
    my $event = Pms::Event::Disconnect->new($connection);
    $self->emitSignal('client_disconnect_success' => $event);
    
    delete $self->{m_connections}->{$connection->identifier()};
    delete $self->{m_users}->{$connection->username()};
  }
}

sub invokeCommand{
  my $self       = shift or die "Need Ref";
  my $connection = shift or die "Need Connection Object";
  my $command    = shift or die "Need Command";
  
  #first try to invoke build in commands
  if(exists $self->{m_buildinCommands}->{$command->{'name'}}){
    warn "Invoking Command: ".$command->{'name'} if($Debug);
    #command hash contains a reference to the arguments array
    my @args = @{$command->{'args'}};
    $self->{m_buildinCommands}->{$command->{'name'}}->( $connection,@args );
    return;
  }
  
  #now try the registered
  if(exists $self->{m_commands}->{$command->{'name'}}){
    
    my $event = Pms::Event::Command->new($command->{'name'},$command->{'args'});
    $self->emitSignal('execute_command_request' => $event);

    if($event->wasRejected()){
      warn "Execute command was rejected, reason: ".$event->reason();
      $connection->postMessage(Pms::Prot::Messages::serverMessage("default",$event->reason()));
      return;
    }
    
    warn "Invoking Custom Command: ".$command->{'name'} if($Debug);
    #command hash contains a reference to the arguments array
    my @args = @{$command->{'args'}};
    $self->{m_commands}->{$command->{'name'}}->( $connection,@args );
  }else{
    $connection->postMessage(Pms::Prot::Messages::serverMessage("default","Unknown Command: ".$command->{name}));
  }
}

sub _sendCommandCallback{
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
      return
    }
    
    if(!$self->{m_channels}->{$channel}->hasConnection($connection->identifier())){
      $connection->postMessage("/serverMessage \"default\" \"You must join the Channel first\" ");
      return
    }
    
    my $who  = $connection->username();
    my $when = time();
    
    #TODO put who and when in the event
    my $event = Pms::Event::Message->new($connection,$channel,$message,$when);
    $self->emitSignal('message_send_request' => $event);
    
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
    
    $self->emitSignal('message_send_success' => $event);
  }
}

sub _createChannelCallback{
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
    
    if(!$self->createChannel($connection,$channel)){
      $connection->postMessage(Pms::Prot::Messages::serverMessage("default",$self->{m_lastError}));
    }
  }
}



sub _joinChannelCallback{
  my $self = shift or die "Need Ref";
  
  return sub{
    my $connection = shift;
    my $channelName = shift;
    
    if(!defined $connection){
      #TODO add some error handling
      return;
    }

    if(!defined $channelName){
      $connection->postMessage("/serverMessage \"default\" \"Wrong Parameters for join command\"");
      return;
    }
    
    #if(!defined $self->{m_channels}{$channelName}){
    #  $connection->postMessage("/serverMessage \"default\" \"Channel ".$channelName." does not exist\" ");
    #}
    
    if(!$self->joinChannel($connection,$channelName)){
      $connection->postMessage(Pms::Prot::Messages::serverMessage("default",$self->{m_lastError}));
    }
  }
}

sub _leaveChannelCallback{
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
    
    my $event = Pms::Event::Leave->new($connection,$self->{m_channels}->{$channel});
    $self->emitSignal('leave_channel_success' => $event);
    
    if(defined $self->{m_channels}{$channel}){
      $self->{m_channels}{$channel}->removeConnection($connection);
    }
    
  }  
}

sub _listChannelCallback{
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

sub _changeNickCallback{
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
    
    my $oldname = $connection->username();
    my $event = Pms::Event::NickChange->new($connection,$connection->username(),$newname);
    $self->emitSignal('change_nick_request' => $event);

    if($event->wasRejected()){
      if($Debug){
        warn "Nick was rejected, reason: ".$event->reason();
      }
      $connection->postMessage("/serverMessage \"default\" \"".$event->reason()."\" ");
      return;
    }
    
    if($self->changeNick($connection,$newname) == 0){
      #a error happened
      $connection->postMessage("/serverMessage \"default\" \"$self->{m_lastError}\"");
    }  
  }
}

sub _listUsersCallback{
  my $self = shift or die "Need Ref";
  
  return sub{
    my $connection = shift;
    my $channel = shift;
    
    if(!defined $channel){
      $connection->postMessage("/serverMessage \"default\" \"Wrong Parameters for users command\"");
      return;
    }
    
    if(!defined $self->{m_channels}->{$channel}){
      $connection->postMessage("/serverMessage \"default\" \"No such channel\"");
      return;
    }
    
    my $message = Pms::Prot::Messages::userListMessage($self->{m_channels}->{$channel});
    $connection->postMessage($message);
  }
}

sub _topicCallback{
  my $self = shift or die "Need Ref";
  
  return sub{
    my $connection = shift;
    my $channel    = shift;
    my $topic      = shift;
    
    if(!defined $connection){
      return;
    }
    
    if(!defined $channel){
      $connection->postMessage(Pms::Prot::Messages::serverMessage("default","Wrong Parameters for topic command"));
      return;
    }
    
    if(!defined $self->{m_channels}->{$channel}){
      $connection->postMessage(Pms::Prot::Messages::serverMessage("default","Channel $channel does not exist"));
      return;
    } 
    
    my $channelObj = $self->{m_channels}->{$channel};
    
    #if the user does not send a topic, he wants to know the current one
    if(!defined $topic){
      $connection->postMessage(Pms::Prot::Messages::topicMessage($channelObj->channelName(),$channelObj->topic()));
    }else{
      
      my $event = Pms::Event::Topic->new($connection,$channelObj,$topic);
      $self->emitSignal('change_topic_request' => $event);
      
      if($event->wasRejected()){
        if($Debug){
          warn "Change Topic was rejected, reason: ".$event->reason();
        }
        $connection->postMessage(Pms::Prot::Messages::serverMessage("default",$event->reason()));
        return;
      }
      $self->{m_channels}->{$channel}->setTopic($topic);
      $self->emitSignal('change_topic_success' => $event);
    }
  }
}
1;
