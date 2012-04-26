#!/usr/bin/perl -w

=begin nd

  Package: Pms::Modules::Backlog
  
  Description:
  
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
    xxxx - description
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
  warn "Backlog Module created";
  return $self;
}

sub DESTROY{
  my $self = shift;
  $self->shutdown();
}

=begin nd
  Function: _onDbConnectCallback
    <function_description>
  
  Access:
    Private
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
=cut
sub _onDbConnectCallback{
  my $self = shift;
  return sub{
    my $dbh = shift;
    my $success = shift;
    
    if(!$success){
      warn "Could not connect to database, no Backlog functions will be registered";
      return;
    }
    
    warn "Database connection success, creating Backlog Hooks";
    $self->initialize();
  };
}

sub _dbErrorCallback{
  my $self = shift;
  return sub{
    warn "DBI Error: $@ at $_[1]:$_[2]";
  };
}

sub initialize{
  my $self = shift;
  
  #deleting old Backlogs
  my @args;
  $self->{m_dbh}->exec ("CALL mod_backlog_emptyTable();"
  , @args
  , sub{
    return;
  });
  
  warn "Registering Events";  
  $self->{m_eventGuard} = $self->{m_parent}->connect(
    message_send_success  => $self->_messageSendSuccessCallback(),
    join_channel_success  => $self->_joinChannelSuccessCallback(),
    channel_close_success => $self->_channelCloseSuccessCallback()
  );
}

sub shutdown{
  my $self = shift;
  warn "Shutting Down";
  $self->{m_parent}->disconnect($self->{m_eventGuard});
}

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

sub _joinChannelSuccessCallback{
  my $self = shift or die "Need Ref";
  return sub{
    my $eventChain = shift;
    my $eventType  = shift; 
    
    my @args;
    push(@args,$eventType->channelName());
    $self->{m_dbh}->exec ("CALL mod_backlog_get(?,10);"
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