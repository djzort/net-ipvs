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

my $ipvs = Net::IPVS->new( command => 'echo ipvsadm' );

#------------------------------------------------------------------------------
# Tests

plan tests => 6;

test_modify_service();
test_add_service();
test_edit_service();
test_delete_service();

#------------------------------------------------------------------------------
# Subroutines

sub test_modify_service {
    my $capture = IO::Capture::Stderr->new;
    $capture->start;

    throws_ok { $ipvs->_modify_service() }
    qr/Required option '\w+' is not provided/, 'Dies with no arguments';

    throws_ok { $ipvs->_modify_service( cmd => 'add' ) }
    qr/Required option '\w+' is not provided/,
        'Dies with no virtual service addresst';

    $capture->stop;

    lives_ok {
        $ipvs->_modify_service(
            cmd     => 'add',
            virtual => '10.1.2.3:2000',
        );
    };
}

sub test_add_service {
    lives_ok { $ipvs->add_service( virtual => '10.1.2.3:2000' ) };
}

sub test_edit_service {
    lives_ok {
        $ipvs->edit_service( virtual => '10.1.2.3:2000', scheduler => 'wrr' );
    };
}

sub test_delete_service {
    lives_ok {
        $ipvs->delete_service( virtual => '10.1.2.3:2000' );
    };
}

#------------------------------------------------------------------------------

__END__
