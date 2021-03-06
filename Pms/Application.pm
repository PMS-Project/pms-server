#!/usr/bin/perl -w

=begin nd

  Package: Pms::Application
  
  Description:
  
=cut

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

our %PmsEvents = ( 'client_connect_request' => 1
                 , 'client_connect_success' => 1
                 , 'client_disconnect_success' => 1
                 , 'message_send_request' => 1
                 , 'message_send_success' => 1
                 , 'join_channel_request' => 1
                 , 'join_channel_success' => 1
                 , 'leave_channel_success' => 1
                 , 'create_channel_request' => 1
                 , 'create_channel_success' => 1
                 , 'channel_close_success' => 1
                 , 'change_nick_request' => 1
                 , 'change_nick_success' => 1
                 , 'change_topic_request' => 1
                 , 'change_topic_success' => 1
                 , 'execute_command_request' => 1
                 );

=begin nd
  Signal: client_connect_request
  
  Description:
    Event is fired if a new Client tries to connect to the server
    
  Parameters:
    event - <Pms::Event::Connect> instance
=cut    

=begin nd  
  Signal: client_connect_success
  
  Description:
    Event is fired if a new Client connects to the server
    
  Parameters:
    event - <Pms::Event::Connect> instance
 =cut    

=begin nd     
  Signal: client_disconnect_success
  
  Description:
    Any client closed the connection
    
  Parameters:
    event - <Pms::Event::Disconnect> instance
=cut    

=begin nd      
  Signal: message_send_request
  
  Description:
    Any client asks if he can send a message to any channel
    
  Parameters:
    event - <Pms::Event::Message> instance
=cut    

=begin nd      
  Signal: message_send_success
  
  Description:
    Any client has sent a message to any channel
    
  Parameters:
    event - <Pms::Event::Message> instance
=cut    

=begin nd      
  Signal: join_channel_request
  
  Description:
    User requests to join a channel
    
  Parameters:
    event - <Pms::Event::Join> instance
=cut    

=begin nd      
  Signal: join_channel_success
  
  Description: 
    A connected user entered a channel
    
  Parameters:
    event - <Pms::Event::Join> instance
=cut    

=begin nd      
  Signal: leave_channel_success
  
  Description:
    A connected user left a channel
    
  Parameters:
    event - <Pms::Event::Leave> instance
=cut    

=begin nd      
  Signal: create_channel_request
  
  Description: 
    A user tries to create a new channel
    
  Parameters:
    event - <Pms::Event::Channel> instance
=cut    

=begin nd      
  Signal: create_channel_success
  
  Description:
    A new channel was created on the server 
    
  Parameters:
    event - <Pms::Event::Channel> instance
=cut    

=begin nd      
  Signal: channel_close_success
  
  Description:
    A channel was deleted/closed
    
  Parameters:
    event - <Pms::Event::Channel> instance
=cut    

=begin nd      
  Signal: change_nick_request
  
  Description:
    A user tries to change his nickname
    
  Parameters:
    event - <Pms::Event::NickChange> instance
=cut    

=begin nd      
  Signal: change_nick_success
  
  Description: 
    A user has changed his nickname
    
  Parameters:
    event - <Pms::Event::NickChange> instance
=cut    

=begin nd      
  Signal: change_topic_request
  
  Description:
    A user tries to change a channel topic
    
  Parameters:
    event - <Pms::Event::Topic> instance
=cut    

=begin nd      
  Signal: change_topic_success
  
  Description:
    A user has changed a channel topic
    
  Parameters:
    event - <Pms::Event::Topic> instance
=cut    

=begin nd  
  Signal: execute_command_request
  
  Description:
    A user tries to execute a custom command
    
  Parameters:
    event - <Pms::Event::Command> instance
=cut
                 
=begin nd
  Constructor: new
    Initializes the Object
=cut
sub new{
  my $class = shift;
  my $self = $class->SUPER::new( );
  bless ($self, $class);
  
  $self->{m_config} = shift;     
  
  warn "PMS-Core> ". $self->{m_config};
  
  if($Debug){
    my $test = Pms::Core::Object->new();
    if(!$test->_hasEvent("muhls")){
      warn "PMS-Core> ". "Test 1 ok";
    }else{
      warn "PMS-Core> ". "Test 2 failed";
    }
    
    if($test->_hasEvent("connectionAvailable")){
      warn "PMS-Core> ". "Test 2 ok";
    }else{
      warn "PMS-Core> ". "Test 2 failed";
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

=begin nd
  Function: execute
    Loads the ConnectionProviders, Modules
    and start the eventloop.
  
  Access:
    Public
=cut
sub execute{
  my $self = shift or die "Need Ref";
  
  $self->_loadConnectionProviders();
  $self->_loadModules();
  
  warn "PMS-Core> ". "Starting the Eventloop, listening for Connections";
  $self->{m_eventLoop} ->recv; #eventloop
}

=begin nd
  Function: _loadConnectionProviders
    Tries to load all ConnectionProviders mentioned 
    in the config-file.
  
  Access:
    Private
=cut
sub _loadConnectionProviders{
  my $self = shift or die "Need Ref";
  if(!defined $self->{m_config}->{connectionProviders}){
    die "No Connectionprovider defined, edit Config.pm and add one";
  }
  
  foreach my $curr (@{ $self->{m_config}->{connectionProviders} }){
    if(!defined $curr->{name}){
      die "No name defined in ConnectionProvider";
    }
    
    warn "PMS-Core> ". "Trying to load ConnectionProvider: $curr->{name} ";
    
    my $name = $curr->{name};
    eval "require $name" or die "Could not load ConnectionProvider: $name error: $@";;
    
    my $module = $name->new($self,$curr->{config});
    $self->{m_connectionProvider}->{$name} = $module;
    $module->reg_cb('connectionAvailable' => $self->_newConnectionCallback());
  }
}

=begin nd
  Function: _loadModules
    Tries to load all modules mentioned 
    in the config-file.
  
  Access:
    Private
=cut
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
    warn "PMS-Core> ". "Trying to load Module: $curr->{name} ";
    
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
    warn "PMS-Core> ". "Setting force to 0";
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
        warn "PMS-Core> ". "Join was rejected, reason: ".$event->reason();
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

=begin nd
  Function: channel
    Tries to find the <Pms::Core::Channel> Object
    by name.
  
  Access:
    Public
    
  Parameters:
    $channelName - the name of the channel we are looking for
    
  Returns:
    undef - if nothing was found
    ref   - <Pms::Core::Channel> if the object was found
=cut
sub channel{
  my $self = shift or die "Need Ref";
  my $channelName = shift or die "Need Channel Name";
  
  if(!defined $self->{m_channels}->{$channelName}){
    $self->{m_lastError} = "Channel not known";
    return undef;
  }
  
  return $self->{m_channels}->{$channelName};
  
}

=begin nd
  Function: registerCommand
    Registers a custom command in the server,
    if its not available already.
  
  Access:
    Public
    
  Parameters:
    $command - the command name
    $cb      - the callback to be executed when the command is issued
=cut
sub registerCommand{
  my $self = shift or die "Need Ref";
  my $command = shift or die "Need Command";
  my $cb = shift or die "Need Callback";
  
  if(!exists $self->{m_buildinCommands}->{$command} && 
     !exists $self->{m_commands}->{$command}){
    $self->{m_commands}->{$command} = $cb;
    return;
  }
  warn "PMS-Core> ". "Command ".$command." already exists, did not register it";
}

=begin nd
  Function: channels
    Get a list of all channels
  
  Access:
    Public
    
  Returns:
    array - a list of all channels 
=cut
sub channels{
  my $self = shift or die "Need Ref";
  return keys(%{ $self->{m_channels} });        
}

=begin nd
  Function: sendBroadcast
    Sends a broadcast message to all connected clients
  
  Access:
    Public
    
  Parameters:
    $message - the message we want to send
=cut
sub sendBroadcast{
  my $self = shift or die "Need Ref";
  my $message = shift or die "Need Message";
  foreach my $curr(keys %{$self->{m_connections}}){
    $self->{m_connections}->{$curr}->postMessage($message);
  }
}

=begin nd
  Function: _termSignalCallback
    Creates a callback that is called when the OS send the
    TERM signal to the server. 
    This stops the eventloop and starts to shutdown the server.
  
  Access:
    Private
=cut
sub _termSignalCallback{
  my $self = shift;
  return sub {
    warn "PMS-Core> ". "Received TERM Signal\n";
    $self->{m_eventLoop}->send; #die from Eventloop
  }  
}

=begin nd
  Function: _newConnectionCallback
    Creates a callback that handles new incoming connections
  
  Access:
    Private
    
  Returns:
    sub - the callback
=cut
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
        warn "PMS-Core> ". "Connection was rejected, reason: ".$event->reason();
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

=begin nd
  Function: _dataAvailableCallback
    Creates a callback that handles all new messages from the client
  
  Access:
    Private
    
  Returns:
    sub - the callback
=cut
sub _dataAvailableCallback{
  my $self = shift or die "Need Ref";
  return sub {
        my ($connection) = @_;
        while($connection->messagesAvailable()){
          my $message = $connection->nextMessage();
          warn "PMS-Core> ". "Reveived Message: ".$message if($Debug);
          
          my %command = $self->{m_parser}->parseMessage($message);
          if(keys %command){
            $self->invokeCommand($connection,\%command);
          }else{
            warn "PMS-Core> ". "Empty ".$self->{m_parser}->{m_lastError};
            #do Error handling
          }
        }
    }
}

=begin nd
  Function: _clientDisconnectCallback
    Creates a callback that handles all disconnects from the clients
  
  Access:
    Private
    
  Returns:
    sub - the callback
=cut
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

=begin nd
  Function: invokeCommand
    Tries to invoke one of the buildin or registered commands
  
  Access:
    Public
    
  Parameters:
    $connection - the connection object that wants to invoke the command
    $command    - the command name
    @args       - the arguments to the command (optional)
=cut
sub invokeCommand{
  my $self       = shift or die "Need Ref";
  my $connection = shift or die "Need Connection Object";
  my $command    = shift or die "Need Command";
  
  #first try to invoke build in commands
  if(exists $self->{m_buildinCommands}->{$command->{'name'}}){
    warn "PMS-Core> ". "Invoking Command: ".$command->{'name'} if($Debug);
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
      warn "PMS-Core> ". "Execute command was rejected, reason: ".$event->reason();
      $connection->postMessage(Pms::Prot::Messages::serverMessage("default",$event->reason()));
      return;
    }
    
    warn "PMS-Core> ". "Invoking Custom Command: ".$command->{'name'} if($Debug);
    #command hash contains a reference to the arguments array
    my @args = @{$command->{'args'}};
    $self->{m_commands}->{$command->{'name'}}->( $connection,@args );
  }else{
    $connection->postMessage(Pms::Prot::Messages::serverMessage("default","Unknown Command: ".$command->{name}));
  }
}

=begin nd
  Function: _sendCommandCallback
    Creates a callback that handles the /send command
  
  Access:
    Private
    
  Returns:
    sub - the command callback
=cut
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
        warn "PMS-Core> ". "Message was rejected, reason: ".$event->reason();
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

=begin nd
  Function: _createChannelCallback
    Creates the callback that handles the /create command
  
  Access:
    Private
=cut
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

=begin nd
  Function: _joinChannelCallback
    Creates the callback that handles the /join command
  
  Access:
    Private
=cut
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

=begin nd
  Function: _leaveChannelCallback
    Creates the callback that handles the /leave command
  
  Access:
    Private
    
  Returns:
    sub - the callback
=cut
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

=begin nd
  Function: _listChannelCallback
    Creates the callback that handles the /list command
  
  Access:
    Private
    
  Returns:
    sub - the callback
=cut
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

=begin nd
  Function: _changeNickCallback
    Creates a callback that handles the /nick command
  
  Access:
    Private
    
  Returns:
    sub - the callback
=cut
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
        warn "PMS-Core> ". "Nick was rejected, reason: ".$event->reason();
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

=begin nd
  Function: _listUsersCallback
    Creates a callback that handles the /users command
  
  Access:
    Private
    
  Returns:
    sub - the callback
=cut
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

=begin nd
  Function: _topicCallback
    Creates a callback that handles the /topic command
  
  Access:
    Private
    
  Returns:
    sub - the callback
=cut
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
          warn "PMS-Core> ". "Change Topic was rejected, reason: ".$event->reason();
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
