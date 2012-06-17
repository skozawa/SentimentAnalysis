use strict;
use warnings;
use utf8;
use Test::More;

use_ok $_ for qw(
    SentimentAnalysis
    SentimentAnalysis::Web
    SentimentAnalysis::Web::Dispatcher
);

done_testing;
