use Modern::Perl;
use Test::Most      tests => 12;

use PubStandards;
my $ps = PubStandards->new();




is( 1287075600,
    $ps->get_middle_thursday_of_month( 2010, 10 ),
    'October 2010'
);
is( 1290099600,
    $ps->get_middle_thursday_of_month( 2010, 11 ),
    'November 2010'
);
is( 1292518800,
    $ps->get_middle_thursday_of_month( 2010, 12 ),
    'December 2010'
);
is( 1294938000,
    $ps->get_middle_thursday_of_month( 2011, 1 ),
    'January 2011'
);
is( 1297962000,
    $ps->get_middle_thursday_of_month( 2011, 2 ),
    'February 2011'
);
is( 1300381200,
    $ps->get_middle_thursday_of_month( 2011, 3 ),
    'March 2011'
);
is( 1302800400,
    $ps->get_middle_thursday_of_month( 2011, 4 ),
    'April 2011'
);
is( 1305219600,
    $ps->get_middle_thursday_of_month( 2011, 5 ),
    'May 2011'
);
is( 1308243600,
    $ps->get_middle_thursday_of_month( 2011, 6 ),
    'June 2011'
);
is( 1310662800,
    $ps->get_middle_thursday_of_month( 2011, 7 ),
    'July 2011'
);
is( 1313686800,
    $ps->get_middle_thursday_of_month( 2011, 8 ),
    'August 2011'
);
is( 1316106000,
    $ps->get_middle_thursday_of_month( 2011, 9 ),
    'September 2011'
);
