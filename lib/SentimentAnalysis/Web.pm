package SentimentAnalysis::Web;
use strict;
use warnings;
use utf8;
use parent qw/SentimentAnalysis Amon2::Web/;
use File::Spec;
use Net::Twitter::Lite;
use Text::MeCab;
use TokyoTyrant;
use DateTime;
use DateTime::Format::DateParse;
use Data::Dumper;
use Encode;

# dispatcher
use SentimentAnalysis::Web::Dispatcher;
sub dispatch {
    return (SentimentAnalysis::Web::Dispatcher->dispatch($_[0]) or die "response is not generated");
}

# nt
sub twitter {
    my $c = shift;
    my $nt = Net::Twitter::Lite->new(
        consumer_key    => $c->config->{Auth}{Twitter}{consumer_key},
        consumer_secret => $c->config->{Auth}{Twitter}{consumer_secret},
        );
    $nt->access_token($c->session->get('access_token'));
    $nt->access_token_secret($c->session->get('access_token_secret'));
    return $nt;
}

sub mrph_analysis {
    my ($c, $tweets) = @_;

    my $mecab = Text::MeCab->new(
        dicdir => "/usr/local/unidic/dic/unidic-mecab",
    );
    my $rdb = TokyoTyrant::RDB->new();
    if ( !$rdb->open($c->config->{TokyoTyrant}{host}, $c->config->{TokyoTyrant}{port}) ) {
        die "open error: ", $rdb->errmsg($rdb->ecode());
    }

    foreach my $tweet ( @$tweets ) {
        $tweet->{positive} = 0;
        $tweet->{negative} = 0;
        my @mrphs;
        my $node = $mecab->parse($tweet->{text});
        do {
            my @features = split /,/, $node->feature;
            my $polarity = 0;
            if ( my $value = $rdb->get($features[7]) ) {
                $polarity = $value;
            } elsif ( $value = $rdb->get($features[12]) ) {
                $polarity = $value;
            }
            my $text = $node->surface;
            if ($polarity) {
                $text = '<span =class"';
                if ( $polarity == 1 ) {
                    $text .= 'positive';
                } else {
                    $text .= 'negative';
                }
                $text .= '">' .$node->surface.'</span>';
            }
            push @mrphs, {
                surface => $node->surface,
                text => $text,
                lemma   => $features[7],
                lemma_reading => $features[12],
                polarity => $polarity,
            };
            if ( $polarity == 2 ) {
                $tweet->{positive}++;
            } elsif ( $polarity == 1 ) {
                $tweet->{negative}++;
            }
        } while ( $node = $node->next );

        for my $n ( 2 .. 6 ) {
            for my $i ( 0 .. $#mrphs-$n ) {
                my @surfaces;
                my @lemmas;
                map { push @surfaces, $_->{surface} || ' ';
                      push @lemmas, $_->{lemma} || $_->{surface} || ' ';
                  } @mrphs[$i..$i+$n];
                my $value;
                if ( ($value = $rdb->get( join " ", @lemmas )) ||
                     ($value = $rdb->get( join " ", @surfaces )) ){
                    $mrphs[$_]->{polarity} = $value for $i .. $n;
                    if ( $value == 2 ) {
                        $tweet->{positive}++;
                    } elsif ( $value == 1 ) {
                        $tweet->{negative}++;
                    }
                }
            }
        }

        $tweet->{mrphs} = \@mrphs;
        $tweet->{created} = DateTime::Format::DateParse->parse_datetime($tweet->{created_at});
    }

    if ( !$rdb->close() ) {
        die "close error: ", $rdb->errmsg($rdb->ecode());
    }
}

# setup view class
use Text::Xslate;
{
    my $view_conf = __PACKAGE__->config->{'Text::Xslate'} || +{};
    unless (exists $view_conf->{path}) {
        $view_conf->{path} = [ File::Spec->catdir(__PACKAGE__->base_dir(), 'tmpl') ];
    }
    my $view = Text::Xslate->new(+{
        'syntax'   => 'TTerse',
        'module'   => [ 'Text::Xslate::Bridge::Star' ],
        'function' => {
            c => sub { Amon2->context() },
            uri_with => sub { Amon2->context()->req->uri_with(@_) },
            uri_for  => sub { Amon2->context()->uri_for(@_) },
            static_file => do {
                my %static_file_cache;
                sub {
                    my $fname = shift;
                    my $c = Amon2->context;
                    if (not exists $static_file_cache{$fname}) {
                        my $fullpath = File::Spec->catfile($c->base_dir(), $fname);
                        $static_file_cache{$fname} = (stat $fullpath)[9];
                    }
                    return $c->uri_for($fname, { 't' => $static_file_cache{$fname} || 0 });
                }
            },
        },
        %$view_conf
    });
    sub create_view { $view }
}


# load plugins
__PACKAGE__->load_plugins(
    'Web::FillInFormLite',
    'Web::CSRFDefender',
);

# for your security
__PACKAGE__->add_trigger(
    AFTER_DISPATCH => sub {
        my ( $c, $res ) = @_;

        # http://blogs.msdn.com/b/ie/archive/2008/07/02/ie8-security-part-v-comprehensive-protection.aspx
        $res->header( 'X-Content-Type-Options' => 'nosniff' );

        # http://blog.mozilla.com/security/2010/09/08/x-frame-options/
        $res->header( 'X-Frame-Options' => 'DENY' );

        # Cache control.
        $res->header( 'Cache-Control' => 'private' );
    },
);

__PACKAGE__->add_trigger(
    BEFORE_DISPATCH => sub {
        my ( $c ) = @_;
        # ...
        return;
    },
);

1;
