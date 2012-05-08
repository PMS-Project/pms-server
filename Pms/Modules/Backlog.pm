#!/usr/bin/perl -w

=begin nd

  Package: Pms::Modules::Backlog
  
  Description:
    This module implements a Backlog functionality for the pms server.
    A backlog is a chat history for users who just joined the channel,
    so they know about the current conversations.
=cut

package Pms::Modules::Backlog;

use strict;
use utf8;
use Pms::Event::Message;
use Pms::Event::Join;
use Pms::Event::Leave;
use Pms::Core::Connection;
use Pms::Prot::Messages;
use AnyEvent;
use AnyEvent::DBI;
use Data::Dumper;

=begin nd
  Constructor: new
    Initializes the Object
    
  Parameters:
    parent - the <Pms::Application> object
    config - the module config hash
=cut
sub new{
  my $class = shift;
  my $self  = {};
  bless ($self, $class);
  
  $self->{m_parent} = shift;
  $self->{m_config} = shift;
  $self->{m_eventGuard} = undef;
  
  my $host = $self->{m_config}->{db_host}     || "localhost";
  my $db   = $self->{m_config}->{db_database} || "pms";
  my $user = $self->{m_config}->{db_user}     || "pms";
  my $pass = $self->{m_config}->{db_pass}     || "secret";
  
  $self->{m_dbh} = new AnyEvent::DBI("DBI:mysql:$db:$host", $user, $pass,
                                   on_connect  => $self->_onDbConnectCallback(),
                                   on_error    => $self->_dbErrorCallback(),
                                   exec_server => 1,
                                   mysql_auto_reconnect => 1,
                                   mysql_enable_utf8 => 1
  );
  warn "PMS-Core> ". "Backlog Module created";
  return $self;
}

sub DESTROY{
  my $self = shift;
  $self->shutdown();
}

=begin nd
  Function: _onDbConnectCallback
    Returns a function that is called when the
    connection to the database is finished
  
  Access:
    Private
    
  Returns:
    sub - a callback function
=cut
sub _onDbConnectCallback{
  my $self = shift;
  return sub{
    my $dbh = shift;
    my $success = shift;
    
    if(!$success){
      warn "PMS-Core> ". "Could not connect to database, no Backlog functions will be registered";
      return;
    }
    
    warn "PMS-Core> ". "Database connection success, creating Backlog Hooks";
    $self->initialize();
  };
}

=begin nd
  Function: _dbErrorCallback
    Returns a function that is called when there
    was a error in communication with the database
  
  Access:
    Private
    
  Returns:
    sub - a callback function
=cut
sub _dbErrorCallback{
  my $self = shift;
  return sub{
    warn "PMS-Core> ". "DBI Error: $@ at $_[1]:$_[2]";
  };
}

=begin nd
  Function: initialize
    Called by the constructor, initializes the module
    and connects to all the required signals and events
  
  Access:
    Public
=cut
sub initialize{
  my $self = shift;
  
  #deleting old Backlogs
  my @args;
  $self->{m_dbh}->exec ("CALL mod_backlog_emptyTable();"
  , @args
  , sub{
    return;
  });
  
  warn "PMS-Core> ". "Registering Events";
  $self->{m_eventGuard} = $self->{m_parent}->connect(
    message_send_success  => $self->_messageSendSuccessCallback(),
    join_channel_success  => $self->_joinChannelSuccessCallback(),
    channel_close_success => $self->_channelCloseSuccessCallback()
  );
}

=begin nd
  Function: shutdown
    Cleans up the modules resources.
    Is automatically called by the destructor
  
  Access:
    Public
=cut
sub shutdown{
  my $self = shift;
  warn "PMS-Core> ". "Shutting Down";
  $self->{m_parent}->disconnect($self->{m_eventGuard});
}

=begin nd
  Function: _messageSendSuccessCallback
    Creates the callback that is used to 
    handle <Pms::Event::Message> events.
    
    The callback stores every message in the database.
  
  Access:
    Private
    
  Returns:
    sub - a callback function
=cut
sub  _messageSendSuccessCallback{
  my $self = shift or die "Need Ref";
  return sub{
    my $eventChain = shift;
    my $eventType  = shift;   
    
    my @args;
    push(@args,$eventType->connection()->username());
    push(@args,$eventType->when());
    push(@args,$eventType->channel());
    push(@args,$eventType->message());

    $self->{m_dbh}->exec ("CALL mod_backlog_write(?,?,?,?);"
    , @args
    , sub{
      return;
    });
    
  };
}

=begin nd
  Function: _joinChannelSuccessCallback
    Creates the callback that is used to 
    handle <Pms::Event::Join> events.
    
    The callback tries to find the last 100 messages 
    from the channel and send it to the user.
  
  Access:
    Private
    
  Returns:
    sub - a callback function
=cut
sub _joinChannelSuccessCallback{
  my $self = shift or die "Need Ref";
  return sub{
    my $eventChain = shift;
    my $eventType  = shift; 
    
    my @args;
    push(@args,$eventType->channelName());
    $self->{m_dbh}->exec ("CALL mod_backlog_get(?,100);"
    , @args
    , sub{
        my $dbh = shift;
        my $rows = shift;
        my $rv = shift;
             
        if(@{$rows} > 0){
          $eventType->connection()->postMessage(Pms::Prot::Messages::chatMessage($eventType->channelName(),"BACKLOG-MODULE",time(),"-----------START BACKLOG------------"));
          foreach my $curr ( @{$rows} ){   
            my $channel = $eventType->channelName();
            my $who     = $curr->[0];
            my $when    = $curr->[1];
            my $what    = $curr->[2];
                        
            $eventType->connection()->postMessage(Pms::Prot::Messages::chatMessage($eventType->channelName(),$who,$when,$what));
          }
          $eventType->connection()->postMessage(Pms::Prot::Messages::chatMessage($eventType->channelName(),"BACKLOG-MODULE",time(),"----------- END BACKLOG ------------"));
        }
    });
    
  };
}


=begin nd
  Function: _channelCloseSuccessCallback
    Creates the callback that is used to 
    handle <Pms::Event::Channel> events.
    
    The callback removes the backlog from the 
    database if a channel is closed.
  
  Access:
    Private
    
  Returns:
    sub - a callback function
=cut
sub _channelCloseSuccessCallback{
  my $self = shift or die "Need Ref";
  return sub{
    my $eventChain = shift;
    my $eventType  = shift;   
    
    my @args;
    push(@args,$eventType->channelName());

    $self->{m_dbh}->exec ("CALL mod_backlog_delChannel(?);"
    , @args
    , sub{
      return;
    });
  };
}

1;
