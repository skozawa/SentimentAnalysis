package SentimentAnalysis::Web::Dispatcher;
use strict;
use warnings;
use utf8;
use Amon2::Web::Dispatcher::Lite;
use Data::Dumper;

any '/' => sub {
    my ($c) = @_;

    my $query = $c->req->param('query');
    my $page = $c->req->param('page') || 1;
    my $tweets;
    if ( $query ) {
        my $nt = $c->twitter;
        my $r = $nt->search($query, { page => $page });
        $tweets = $r->{results};
        $c->mrph_analysis($tweets);
    }

    $c->render('index.tt', {
        query  => $query,
        tweets => $tweets,
        page => $page,
    });
};

post '/account/logout' => sub {
    my ($c) = @_;
    $c->session->expire();
    $c->redirect('/');
};

1;
