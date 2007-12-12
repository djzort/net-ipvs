#------------------------------------------------------------------------------
# $Id$

use strict;
use warnings;

# Test Modules
use Test::More;
use Test::Exception;

# Extra Modules
use English qw(-no_match_vars);
use File::Spec;
use IO::Capture::Stderr;
#use Smart::Comments;

# Local Modules;
use Net::IPVS;

#------------------------------------------------------------------------------
# Setup

my $ipvs = Net::IPVS->new(command => 'echo ipvsadm');

#------------------------------------------------------------------------------
# Tests

plan tests => 5;

test_clear();
test_set();
test_zero();

#------------------------------------------------------------------------------
# Subroutines

sub test_clear {
    lives_ok { $ipvs->clear(); };
}

sub test_set {
    my $timeout = 300;
    my $capture = IO::Capture::Stderr->new;
    $capture->start;

    throws_ok { $ipvs->set(); } qr/Required option '\w+' is not provided/,
        'Dies with no arguments';

    $capture->stop;

    lives_ok {
        $ipvs->set( tcp => $timeout, tcpfin => $timeout, udpfin => $timeout );
    };
}

sub test_zero {
    my $capture = IO::Capture::Stderr->new;
    $capture->start;

    throws_ok { $ipvs->zero(); } qr/Required option '\w+' is not provided/,
        'Dies with no arguments';

    $capture->stop;

    lives_ok { $ipvs->zero( virtual => '10.1.2.3:20000' ); };
}

#------------------------------------------------------------------------------

__END__
