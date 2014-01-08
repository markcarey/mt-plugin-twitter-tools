package TwitterTools::Pro::Worker::SubscribeSearch;

use strict;
use base qw( TheSchwartz::Worker );

use MT::Util qw( epoch2ts );
use HTTP::Date qw( str2time );

use TheSchwartz::Job;

sub work {
    my $class                = shift;
    my TheSchwartz::Job $job = shift;
 	my $results              = $job->arg;
use Data::Dumper;
    get_tweets($results);
    eval {
MT->log('inside subscribe eval block');
    };
	if ( $@ ) {
        $job->failed( qq{TwitterTools::Pro::Worker::SubscribeSearch could not get tweets } .
                $job->uniqkey . ': ' . $@ );
    } else {
		my $freq = 300; #seconds
		my $new_job = $job->clone;
		$new_job->run_after(time + $freq);
#MT->log("before replace with");
		$job->replace_with($new_job)
			|| MT->log("Cannot replace with new job: " . $job->errstr);
#MT->log("after replace with");
#		$job->completed();
#		require MT::TheSchwartz;
#		MT::TheSchwartz->insert($new_job)
#			|| MT->log("Cannot insert new job: " . MT::TheSchwartz->errstr);
    }
}

sub grab_for    {600}
sub max_retries {300}
sub retry_delay {120}
sub keep_exit_status_for { 600 }

sub get_tweets {
#MT->log("inside get tweets");
#	my ($results) = @_;
	my $blog_id = 105;
	my $blog = MT->model('blog')->load($blog_id);
	my $query = q{ipod OR iphone OR imac OR macbook OR itunes OR aapl OR mac filter:links};
#MT->log("after my query");
	use Net::Twitter::Lite;
	my $tw = Net::Twitter::Lite->new;
#MT->log("after NTL new");
	my $lang = 'en';
#MT->log("after lang $lang");
	my $results = $tw->search({ q => $query, lang => $lang, rpp => '100' });
#MT->log("after tw search");
	$results->{blog_id} = $blog->id;
use Data::Dumper;
#MT->log("get_tweets results is: " . Dumper($results));
	insert_import_worker($results);
}

sub insert_import_worker {
	my ($results, $expiry) = @_;
    require MT::TheSchwartz;
    my $job = TheSchwartz::Job->new();
    $job->funcname('TwitterTools::Pro::Worker::Import');
	my @alpha = ( 'a' .. 'z', 'A' .. 'Z', 0 .. 9 );
    my $token = join '', map $alpha[ rand @alpha ], 1 .. 40;
    $job->uniqkey($token);
	$job->arg($results);
    my $priority ||= MT->config('TwitterToolsImportWorkerPriority');
    $priority ||= 5;
	$expiry ||= 0;
    $job->priority($priority);
	$job->run_after(time + $expiry);
    MT::TheSchwartz->insert($job) or return;
    return 1;
}

1;