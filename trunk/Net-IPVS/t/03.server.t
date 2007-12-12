#------------------------------------------------------------------------------
# $Id$

use strict;
use warnings;

# Test Modules
use Test::More;
use Test::Exception;

# Extra Modules
use English qw(-no_match_vars);
use IO::Capture::Stderr;
#use Smart::Comments;

# Local Modules;
use Net::IPVS;

#------------------------------------------------------------------------------
# Setup

my $ipvs = Net::IPVS->new(command => 'echo ipvsadm');

my $svcaddr = '10.1.2.3:20000';

#------------------------------------------------------------------------------
# Tests

plan tests => 7;

test_modify_server();
test_add_server();
test_edit_server();
test_delete_server();

#------------------------------------------------------------------------------
# Subroutines

sub test_modify_server {
    my $capture = IO::Capture::Stderr->new;
    $capture->start;

    throws_ok { $ipvs->_modify_server() }
    qr/Required option '\w+' is not provided/, 'Dies with no arguments';

    throws_ok { $ipvs->_modify_server( cmd => 'add' ) }
    qr/Required option '\w+' is not provided/, 'Dies with no virtual service addresst';

    throws_ok {
        $ipvs->_modify_server( cmd => 'add', virtual => $svcaddr );
    }
    qr/Required option '\w+' is not provided/, 'Dies with no server addresst';

    $capture->stop;

    lives_ok {
        $ipvs->_modify_server(
            cmd     => 'add',
            virtual => $svcaddr,
            server  => '10.1.2.10:2000',
        );
    };
}

sub test_add_server {
    lives_ok {
        $ipvs->add_server( virtual => $svcaddr, server => '10.1.2.10:2000' );
    };
}

sub test_edit_server {
    lives_ok {
        $ipvs->edit_server(
            virtual => $svcaddr,
            server  => '10.1.2.10:2000',
            weight  => 2
        );
    };
}

sub test_delete_server {
    lives_ok {
        $ipvs->delete_server(
            virtual => $svcaddr,
            server  => '10.1.2.10:2000'
        );
    };
}

#------------------------------------------------------------------------------

__END__
