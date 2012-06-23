use File::Spec;
use File::Basename qw(dirname);
my $basedir = File::Spec->rel2abs(File::Spec->catdir(dirname(__FILE__), '..'));
my $dbpath;
if ( -d '/home/dotcloud/') {
    $dbpath = "/home/dotcloud/development.db";
} else {
    $dbpath = File::Spec->catfile($basedir, 'db', 'development.db');
}
+{
    'DBI' => [
        "dbi:SQLite:dbname=$dbpath",
        '',
        '',
        +{
            sqlite_unicode => 1,
        }
    ],
    TokyoTyrant => {
        host => 'localhost',
        port => '1978',
    },
    Auth => {
        Twitter => {
            consumer_key       => $consumer_key, # your twitter consumer key
            consumer_secret    => $consumer_secret, # your twitter consumer secret
        },
    },
};
