use Test::More tests => 1;

BEGIN {
    use_ok('Net::IPVS');
}

diag("Testing Net::IPVS $Net::IPVS::VERSION");
