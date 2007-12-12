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

plan tests => 2;

test_parse_netaddr();

#------------------------------------------------------------------------------
# Subroutines

sub test_parse_netaddr {
    my $hexaddr = '0A010A15:4E20';
    my $capture = IO::Capture::Stderr->new;
    $capture->start;

    throws_ok { $ipvs->_parse_netaddr() }
    qr/Required option '\w+' is not provided/, 'Dies with no arguments';

    $capture->stop;

    lives_ok { $ipvs->_parse_netaddr( address => $hexaddr ); };
}

#------------------------------------------------------------------------------

__END__
