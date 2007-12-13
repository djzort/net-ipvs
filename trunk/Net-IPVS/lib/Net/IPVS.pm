#------------------------------------------------------------------------------
# $Id$
#
package Net::IPVS;

use warnings;
use strict;

our $VERSION = '0.01';

#------------------------------------------------------------------------------
# Load Modules

use 5.006;

# Standard Modules
use Carp;
use English qw(-no_match_vars);
use Pod::Usage;
use Readonly;

#use Smart::Comments;

# Specific Modules
use Params::Check 0.26 qw(check);
use Regexp::Common 2.120 qw(number net pattern);

#------------------------------------------------------------------------------
# Constants

$Params::Check::NO_DUPLICATES = 1;

Readonly my $ENOFUNC    => 'FUNCTION NOT YET IMPLEMENTED';
Readonly my $OPT_PREFIX => q{--};

Readonly my %VALID => (
    commands           => [qw(add edit delete)],
    protocols          => [qw(tcp udp fwmark)],
    schedulers         => [qw(wrr rr wlc lc lblc lblcr dh sh sed nq)],
    forwarding_methods => [qw(dr tun nat)],
    states             => [qw(master backup)],
    syncid             => [ 0 .. 255 ],
    service_address    => qr/\A$RE{net}{IPv4}:\d+\z/xms,
    server_address     => qr/\A$RE{net}{IPv4}(:\d+)?\z/xms,
);

Readonly my %DEFAULT => (
    protocol          => 'tcp',
    scheduler         => 'wlc',
    forwarding_method => 'dr',
    command           => '/sbin/ipvsadm',
    procfile          => {
        ip_vs       => q{/proc/net/ip_vs},
        ip_vs_conn  => q{/proc/net/ip_vs_conn},
        ip_vs_stats => q{/proc/net/ip_vs_stats}
    },
);

# Forwarding methods for the Net::IPVS interface map to these more obscure
# ipvsadm options
Readonly my %FORWARDING_METHOD_FOR => (
    dr  => 'gatewaying',
    tun => 'ipip',
    nat => 'masquerading',
);

# Regex patterns via Regexp::Common.
#
# 'pattern create' requires a string so we can't use whitespace and
# explanatory comments within the regex itself.

# Match a virtual service address line in the ip_vs table
#     \A
#     (\w+)       # Protocol
#     \s+
#     ([^ ]+)     # LocalAddress:Port
#     \s+
#     (\w+)       # Scheduler
#     \s+
#     (\w+)?      # Flags
pattern
    name   => [qw(ipvs virtual)],
    create => q{\A(\w+)\s+([^ ]+)\s+(\w+)\s+(\w+)?},
    ;

# Match a server address line in the ip_vs table
#    \A\s\s->\s
#    ([^ ]+)     # RemoteAddress:Port
#    \s+
#    (\w+)       # Forward
#    \s+
#    (\d+)       # Weight
#    \s+
#    (\d+)       # Active Connections
#    \s+
#    (\d+)       # InActive Connections
pattern
    name   => [qw(ipvs server)],
    create => q{\A\s\s->\s([^ ]+)\s+(\w+)\s+(\d+)\s+(\d+)\s+(\d+)},
    ;

#------------------------------------------------------------------------------
# Methods

sub new {
    my $class = shift;
    my %argv  = @_;

    my %has = (
        command  => { default => $DEFAULT{command} },
        procfile => {
            default     => $DEFAULT{procfile},
            strict_type => 1,
        }
    );

    my $self = check( \%has, \%argv )
        or croak q{Error: }, Params::Check->last_error;

    bless $self, $class;
    ### $self

    return $self;
}

sub add_service    { return (shift)->_modify_service( cmd => 'add',    @_ ); }
sub edit_service   { return (shift)->_modify_service( cmd => 'edit',   @_ ); }
sub delete_service { return (shift)->_modify_service( cmd => 'delete', @_ ); }

sub add_server    { return (shift)->_modify_server( cmd => 'add',    @_ ); }
sub edit_server   { return (shift)->_modify_server( cmd => 'edit',   @_ ); }
sub delete_server { return (shift)->_modify_server( cmd => 'delete', @_ ); }

sub start_daemon {
    my $self = shift;
    my %argv = @_;

    my %has = (
        state => {
            required => 1,
            allow    => $VALID{states},
        },
        'mcast-interface' => {},
        syncid            => {
            default => 0,
            allow   => $VALID{syncid}
        },
    );

    my $arg = check( \%has, \%argv )
        or croak q{Error: }, Params::Check->last_error;

    $arg->{ delete $arg->{state} } = q{};

    return $self->_run_ipvsadm( cmd => 'start-daemon', opt => $arg );
}

sub stop_daemon { return (shift)->_run_ipvsadm( cmd => 'stop-daemon' ); }
sub clear       { return (shift)->_run_ipvsadm( cmd => 'clear' ); }

sub zero {
    my $self = shift;
    my %argv = @_;
    my $protocol;

    my %has = (
        virtual => {
            required => 1,
            allow    => $VALID{service_address},
        },
        protocol => {
            default => $DEFAULT{protocol},
            allow   => $VALID{protocols},
            store   => \$protocol,
        },
    );

    my $arg = check( \%has, \%argv )
        or croak q{Error: }, Params::Check->last_error;

    $arg->{ $protocol . '-service' } = delete $arg->{virtual};

    return $self->_run_ipvsadm( cmd => 'zero', opt => $arg );
}

sub set {
    my $self = shift;
    my %argv = @_;

    my %has = (
        tcp    => { required => 1 },
        tcpfin => { required => 1 },
        udpfin => { required => 1 },
    );

    my $arg = check( \%has, \%argv )
        or croak q{Error: }, Params::Check->last_error;

    my @cmd = ( 'set', @$arg{ keys %has } );

    return $self->_run_ipvsadm( cmd => qq{@cmd} );

}

#------------------------------------------------------------------------------

sub get_table {
    my $self = shift;
    my %ipvs = ();
    my $virtual;

    open my $fh, '<', $self->{procfile}{ip_vs}
        or croak 'Unable to open proc file ', $self->{procfile}{ip_vs}, ': ',
        $OS_ERROR;

    # /proc/net/ip_vs looks like this:
    #
    # IP Virtual Server version 1.2.1 (size=4096)
    # Prot LocalAddress:Port Scheduler Flags
    #   -> RemoteAddress:Port Forward Weight ActiveConn InActConn
    # TCP  0A010A14:4E20 wlc
    #   -> 0A010A15:4E20      Route   1      0          0

    # Skip the header (first three lines)
    <$fh> for 1 .. 3;

    while (<$fh>) {
        if ( my @matches = m/$RE{ipvs}{virtual}/xms ) {
            $virtual = $self->_parse_netaddr( address => $matches[1] );
            @{ $ipvs{$virtual} }{qw(Protocol Scheduler Flags)}
                = @matches[ 0, 2, 3 ];
        }
        elsif ( @matches = m/$RE{ipvs}{server}/xms ) {
            my $server = $self->_parse_netaddr( address => $matches[0] );
            @{ $ipvs{$virtual}{$server} }
                {qw(Forward Weight ActiveConn InActiveConn)}
                = @matches[ 1 .. 4 ];
        }
        else {
            ### Malformed line in ip_vs table!
        }
    }

    return wantarray ? %ipvs : \%ipvs;
}

sub get_connection_table {
    my $self             = shift;
    my @ipvs_connections = ();

    open my $fh, '<', $self->{procfile}{ip_vs_conn}
        or croak 'Unable to open proc file ', $self->{procfile}{ip_vs_conn},
        ': ', $OS_ERROR;

    # /proc/net/ip_vs_conn looks like this:
    #
    # Pro FromIP   FPrt ToIP     TPrt DestIP   DPrt State       Expires
    # TCP 0AFA0032 9EED 0AD20321 0FBA 0AD20328 0FBA FIN_WAIT         55

    # Skip the header (first line)
    <$fh>;

    CONNECTION:
    while (<$fh>) {
        my @cols = split;

        if ( @cols != 9 ) {
            ### Malformed connection entry in IPVS table!
            next CONNECTION;
        }

        push @ipvs_connections,
            {
            protocol => $cols[0],
            source =>
                $self->_parse_netaddr( address => qq{$cols[1]:$cols[2]} ),
            virtual =>
                $self->_parse_netaddr( address => qq{$cols[3]:$cols[4]} ),
            destination =>
                $self->_parse_netaddr( address => qq{$cols[5]:$cols[6]} ),
            state  => $cols[7],
            expire => $cols[8],
            };
    }

    return wantarray ? @ipvs_connections : \@ipvs_connections;
}

#------------------------------------------------------------------------------

# TODO
#
# sub list_timeout         { croak $ENOFUNC }
# sub list_stats           { croak $ENOFUNC }
# sub list_rate            { croak $ENOFUNC }
# sub list_thresholds      { croak $ENOFUNC }
# sub list_persistent_conn { croak $ENOFUNC }
# sub restore              { croak $ENOFUNC }
# sub save                 { croak $ENOFUNC }

#------------------------------------------------------------------------------
# Internal Methods

sub _modify_service {
    my $self = shift;
    my %argv = @_;
    my ( $cmd, $protocol );

    my %has = (
        cmd => {
            required => 1,
            allow    => $VALID{commands},
            store    => \$cmd,
        },
        virtual => {
            required => 1,
            allow    => $VALID{service_address},
        },
        protocol => {
            default => $DEFAULT{protocol},
            allow   => $VALID{protocols},
            store   => \$protocol,
        },
        scheduler => {
            default => $DEFAULT{scheduler},
            allow   => $VALID{schedulers},
        },
        netmask => {
            default => '255.255.255.255',
            allow   => qr/\A$RE{net}{IPv4}\z/xms
        },
    );

    my $arg = check( \%has, \%argv )
        or croak 'Error: ', Params::Check->last_error;

    # The protocol and command should really have '-service'; it's not
    # required in the initial arguments for brevity. Fix that here...
    #
    # Technically the service address isn't a parameter of the protocol but
    # since the service address requires a protocol, add it here to keep
    # ipvsadm happy. The final argument will end up as:
    #
    #   --tcp-service IPADDR:PORT
    #
    $arg->{ $protocol . '-service' } = delete $arg->{virtual};

    # The delete command should only have the service and server address
    if ( $cmd eq 'delete' ) {
        for ( keys %$arg ) {
            delete $arg->{$_} if !/serv/;
        }
    }

    $cmd .= '-service';

    return $self->_run_ipvsadm( cmd => $cmd, opt => $arg );
}

sub _modify_server {
    my $self = shift;
    my %argv = @_;
    my ( $cmd, $protocol, $forwarding );

    my %has = (
        cmd => {
            required => 1,
            allow    => $VALID{commands},
            store    => \$cmd,
        },
        virtual => {
            required => 1,
            allow    => $VALID{service_address},
        },
        server => {
            required => 1,
            allow    => $VALID{server_address},
        },
        protocol => {
            default => $DEFAULT{protocol},
            allow   => $VALID{protocols},
            store   => \$protocol,
        },
        forwarding => {
            default => $DEFAULT{forwarding_method},
            allow   => $VALID{forwarding_methods},
            store   => \$forwarding,
        },
        weight => {
            default => 1,
            allow   => qr/\A$RE{num}{int}\z/xms,
        },
        'u-threshold' => {
            default => 0,
            allow   => qr/\A$RE{num}{int}\z/xms,
        },
        'l-threshold' => {
            default => 0,
            allow   => qr/\A$RE{num}{int}\z/xms,
        },
    );

    my $arg = check( \%has, \%argv )
        or croak q{Error: }, Params::Check->last_error;

    # Since '--forwarding' isn't a valid parameter, add the proper parameter
    # from the list of forwarding methods (see above).
    $arg->{ $FORWARDING_METHOD_FOR{$forwarding} } = q{};

    # Protocol should really have '-service'; it's not required in the
    # initial arguments for brevity. Fix that here...
    #
    # Assign the service address to the protocol (see previous comments in
    # _modify_service) and assign the server address to 'real-server'.
    $arg->{ $protocol . '-service' } = delete $arg->{virtual};
    $arg->{'real-server'} = delete $arg->{server};

    # The delete command should only have the service and server address
    if ( $cmd eq 'delete' ) {
        for ( keys %$arg ) {
            delete $arg->{$_} if !/serv/;
        }
    }

    # Command should really have '-server'; it's not required in the initial
    # arguments for brevity. Fix that here...
    $cmd .= '-server';

    return $self->_run_ipvsadm( cmd => $cmd, opt => $arg );
}

sub _parse_netaddr {
    my $self = shift;
    my %argv = @_;

    my %has = (
        address => {
            required => 1,
            allow => qr/\A$RE{net}{IPv4}{hex}{-sep => q[]}:$RE{num}{hex}/xms,
        }
    );

    my $arg = check( \%has, \%argv )
        or croak q{Error: }, Params::Check->last_error;

    my ( $ip, $port ) = split /:/, $arg->{address};

    return $self->_hex2ip($ip) . q{:} . hex $port;
}

sub _hex2ip {
    my ( $self, $ip ) = @_;

    return join q{.},
        (
        hex substr( $ip, 0, 2 ),
        hex substr( $ip, 2, 2 ),
        hex substr( $ip, 4, 2 ),
        hex substr( $ip, 6, 2 ),
        );
}

sub _run_ipvsadm {
    my $self = shift;
    my %argv = @_;
    my ( $cmd, $option_ref );

    my %has = (
        cmd => {
            required => 1,
            defined  => 1,
            store    => \$cmd,
        },
        opt => {
            default     => {},
            strict_type => 1,
            store       => \$option_ref,
        }
    );

    my $arg = check( \%has, \%argv )
        or croak q{Error: }, Params::Check->last_error;

    my @options
        = map { $OPT_PREFIX . $_, $option_ref->{$_} } keys %$option_ref;

    my $ipvsadm = $self->{command} . qq{ $OPT_PREFIX$cmd @options};
    ### Running command: $ipvsadm

    # System calls return 0 on success, >0 on failure.
    system($ipvsadm) == 0
        or croak "Unable to run '$ipvsadm': ", $OS_ERROR;

    return 1;
}

#------------------------------------------------------------------------------

1;    # Magic true value required at end of module
__END__

=head1 NAME

Net::IPVS - Perl interface to IP Virtual Server administration


=head1 VERSION

This document describes Net::IPVS version 0.01


=head1 SYNOPSIS

    use Net::IPVS;

    my $ipvs => Net::IPVS->new();

    # Add a TCP virtual service to the IPVS table with the default 
    # weighted least connection scheduler
    $ipvs->add_service( virtual => '10.1.2.3:20000' );

    # Edit the virtual service by changing the scheduler to weighted 
    # round robin
    $ipvs->edit_service( 
        virtual   => '10.1.2.3:2000', 
        scheduler => 'wrr'
    );

    # Remove the virtual service
    $ipvs->delete_service( virtual => '10.1.2.3:20000' );


    # Add two servers with equal weights to an existing TCP 
    # virtual service.
    $ipvs->add_server( 
        virtual => '10.1.2.3:2000',
        server  => '10.1.2.11',
    );

    $ipvs->add_server( 
        virtual => '10.1.2.3:2000',
        server  => '10.1.2.12',
    );

    # Edit one of the servers and change the weight to 2
    $ipvs->edit_server(
        virtual => '10.1.2.3:2000',
        server  => '10.1.2.12',
        weight  => 2,
    );

    # Remove a server from a virtual service
    $ipvs->delete_server(
        virtual => '10.1.2.3:2000',
        server  => '10.1.2.11',
    );

    # Get the current IPVS table
    my %ipvs_table = $ipvs->get_table();

    # Get the current connection table
    my @conn_table = $ipvs->get_connection_table();
  

=head1 DESCRIPTION

B<Warning:> This module is still in the experimental stages. The API may
change so use with caution.

Net::IPVS is a Perl interface to IP Virtual Server administration via
ipvsadm(8). It can be used to configure or inspect the virtual server table.

=head2 IPVS Administration

Administration of the IPVS tables generally involves modification of two main
components: services and servers. A common scenario might involve periodically
checking the health of a pool servers and removing unresponsive ones from a
service.

=head3 Virtual Services

A virtual service is an address that is available for client connections. This
address is typically configured on a server known as the LVS Director.
Connections to the this virtual service address are forwarded to one or more
servers for the actual response. A service has three components: a protocol,
an IP address, and a port. The TCP protocol is used by default but UDP and
fwmark are also available.

When clients connect to the virtual service, a server from the pool is
selected by using a scheduler. The default scheduler is Weighted Least
Connection (wlc) in which each connections are assigned to the server
with the least amount of jobs (relative to the weight of the server).

List of schedulers:

    rr    - Round Robin
    wrr   - Weighted Round Robin
    lc    - Least Connection
    wlc   - Weighted Least Connection
    lblc  - Locality-Based Least Connection
    lblcr - Locality-Based Least Connection with Replication
    dh    - Destination Hashing
    sh    - Source Hashing
    sed   - Shortest Expected Delay
    nq    - Never Queue


For a complete explanation of schedulers, see ipvsadm(8).

=head3 Real Servers

A real server is a destination for forwarded client connections and consists
of an IP address. (A port may be specified in special cases but generally the
server should use the same port defined by the virtual service.)

When a server address is added to the service, a method for forwarding
connections to the server must be selected. If no method is selected, the
Direct Routing (dr) method is used. There are three forwarding methods
available:

    dr  - Direct Routing
    tun - IP Encapsulation (Tunneling)
    nat - Network Address Translation (Masquerading)

For a complete explanation of forwarding methods, see ipvsadm(8).

B<Note:> The C<dr> and C<tun> forwarding methods require the virtual service
and the server to use the same port.

=head2 IPVS Inspection

TODO

=head1 INTERFACE 

=over

=item new()

=item new( command => '/path/to/ipvsadm' )

The constructor C<new> creates a new Net::IPVS object. No arguments are
required.

Optional arguments:

  command  - Location of the ipvsadm binary as a fully qualified path.
    Default: /sbin/ipvsadm

  procfile - Locations of the ip_vs proc files as a hash reference.
    Default: {
        ip_vs      => /proc/net/ip_vs
        ip_vs_conn => /proc/net/ip_vs_conn
    }

=back

=head2 Public Methods

All public methods take arguments in in 'key => value' form.

=over

=item add_service( virtual => 'Host:Port', %options )

=item edit_service( virtual => 'Host:Port', %options )

=item delete_service( virtual => 'Host:Port', %options )

Modify a virtual service address in the IPVS table. The only required argument
is the service address (C<virtual>).

Optional arguments:

    protocol   - tcp (default), udp, or fwmark
    scheduler  - A valid LVS scheduler (default: rr)
    persistent - A timeout (in seconds) for persistent connections
    netmask    - Default: 255.255.255.255

=item add_server( virtual => 'Host:Port', server => 'Host', %options )

=item edit_server( virtual => 'Host:Port', server => 'Host', %options )

=item delete_server( virtual => 'Host:Port', server=> 'Host', %options )

Modify a real server associated with a virtual service. The virtual service
address and the server address are required.

Optional arguments:

    protocol    - tcp (default), udp, or fwmark
    forwarding  - dr (default), tun, or nat
    weight      - Integer for server's relative capacity (default: 1)
    u-threshold - Integer for upper connection threshold (default: 0)
    l-threshold - Integer for lower connection threshold (default: 0)

=item clear()

Clear the virtual server table.

=item set( tcp => Int, tcpfin => Int, udpfin => Int )

Change the timeout values (in seconds) )for IPVS connections. There are three
required arguments:

   tcp    - Timeout for TCP sessions
   tcpfin - Timeout for TCP sessions after receiving a FIN packet
   udpfin - Timeout for UDP sessions after receiving a FIN packet

=item zero()

=item zero( virtual => 'Host:Port' )

Zero the packet, byte and rate counters in a service or all services. This
method takes one optional argument: the virtual service address.

=item start_daemon( state => 'master|backup' )

Start the synchronization daemon.

Options:
  * state  - master or backup
  * syncid - synchronization id

=item stop_daemon()

Stop the synchronization daemon.

=item get_table()

Get the virtual server table as a hash structure. In list context this method
will return a hash; in scalar context a hash reference will be returned.

The hash will have each service address as a top level keys. Each service
address will have the following three static keys:
  
  * Flags     - Any flags specified for the service
  * Protocol  - TCP, UDP, or FWMARK
  * Scheduler - The current scheduler (see the list of schedulers)

In addition to these three keys, each real server address (IP and port) will
be a key with the following subkeys:

  * ActiveConn   - Active connections
  * Forward      - Forwarding method
  * InActiveConn - Inactive connections
  * Weight       - Relative weight

Example (YAML formatted):
    --- 
    10.1.10.20:20000: 
      10.1.10.21:20000: 
        ActiveConn: 0
        Forward: Route
        InActiveConn: 0
        Weight: 1
      Flags: ~
      Protocol: TCP
      Scheduler: wlc


=item get_connection_table()

Get the list of connections to the virtual services as a hash structure. In
list context this method will return an array; in scalar context an array
reference will be returned.

The connection table is a List of Hashes with each hash entry in the list
representing a single connection entry. Each entry has the following keys:

  * destination - Address of real server
  * expire      - Time (in seconds) the connection will expire
  * protocol    - TCP, UDP, or FWMARK
  * source      - IP and port of client connection
  * state       - Connection state (e.g. SYN_RECV, FIN_WAIT, etc.)
  * virtual     - Virtual service address

Example (YAML formatted):
    --- 
    - 
      destination: 10.1.10.121:20000
      expire: 18
      protocol: TCP
      source: 10.1.9.201:47504
      state: SYN_RECV
      virtual: 10.1.10.120:20000
    -
      destination: 10.1.10.121:20000
      expire: 18
      protocol: TCP
      source: 10.1.9.201:48702
      state: SYN_RECV
      virtual: 10.1.10.120:20000

=back

=head1 INTERNAL METHODS

=over

=item _modify_service()

=item _modify_server()

=item _parse_netaddr()

=item _hex2ip()

=item _run_ipvsadm()

=back

=head2 Metaclass Methods

=over

=item meta()

=back

=head1 DIAGNOSTICS

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

Net::IPVS requires no configuration files or environment variables.


=head1 DEPENDENCIES

=over

=item Readonly

=item Regexp::Common

=item Params::Check

=back

=head1 INCOMPATIBILITIES

None reported.


=head1 BUGS AND LIMITATIONS

Currently IPVS inspection is limited to parsing /proc/net/ip_vs* files.

Please report any bugs or feature requests through the web interface at
L<http://net-ipvs.googlecode.com>

=head1 AUTHOR

David Narayan  C<< <dnarayan@cpan.org> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2007, David Narayan  C<< <dnarayan@cpan.org> >>. 
All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

Because this software is licensed free of charge, there is no warranty for the
software, to the extent permitted by applicable law. Except when otherwise
stated in writing the copyright holders and/or other parties provide the
software "as is" without warranty of any kind, either expressed or implied,
including, but not limited to, the implied warranties of merchantability and
fitness for a particular purpose. The entire risk as to the quality and
performance of the software is with you. Should the software prove defective,
you assume the cost of all necessary servicing, repair, or correction.

In no event unless required by applicable law or agreed to in writing will any
copyright holder, or any other party who may modify and/or redistribute the
software as permitted by the above licence, be liable to you for damages,
including any general, special, incidental, or consequential damages arising
out of the use or inability to use the software (including but not limited to
loss of data or data being rendered inaccurate or losses sustained by you or
third parties or a failure of the software to operate with any other
software), even if such holder or other party has been advised of the
possibility of such damages.
