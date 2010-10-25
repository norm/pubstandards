package PubStandards::Dates;

use Modern::Perl;
use Moose::Role;
use MooseX::Method::Signatures;

use constant MONTHS => qw( 
        0
        January  February  March      April    May       June 
        July     August    September  October  November  December
    );



method get_name_for_month ( Int $month ) {
    return (MONTHS)[$month];
}

1;
