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

my $ipvs = Net::IPVS->new( command => 'echo ipvsadm' );

#------------------------------------------------------------------------------
# Tests

plan tests => 3;

test_start_daemon();
test_stop_daemon();

#------------------------------------------------------------------------------
# Subroutines

sub test_start_daemon {
    my $capture = IO::Capture::Stderr->new;
    $capture->start;

    throws_ok { $ipvs->start_daemon() }
    qr/Required option '\w+' is not provided/, 'Dies with no arguments';

    $capture->stop;

    lives_ok { $ipvs->start_daemon( state => 'master' ); };
}

sub test_stop_daemon {
    lives_ok { $ipvs->stop_daemon() };
}

#------------------------------------------------------------------------------

__END__
