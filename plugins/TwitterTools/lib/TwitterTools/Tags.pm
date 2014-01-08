package TwitterTools::Tags;
use strict;

use MT::Util qw( decode_html epoch2ts );
use TwitterTools::Util qw( autolink_tweet );
use HTTP::Date qw( str2time );


sub twitter_short_url {
    my ($ctx, $args) = @_;
    my $entry = $ctx->stash('entry');
    return $entry->meta('twitter_short_url') || '';
}

sub _hdlr_tweets {
    my($ctx, $args, $cond) = @_;
	my $query = $args->{query};
	my $lastn = $args->{lastn} || 15;
	my $results;
	my $blog = $ctx->stash('blog');
	
use Data::Dumper;


	# determine whetehr to hit the API or the DB?  save last API check in a session?
	
	my $expiry = 60 * 10;   # 10 minutes    TODO:  Make a settings or config dir
	require MT::Session;
	my $sess_obj = MT::Session::get_unexpired_value($expiry,{ name => $query . $lastn, kind => 'TW' });
	if ($sess_obj) {
		$results = $sess_obj->thaw_data;
	#	return 'from session: ' . Dumper($results);
	} else {
		use Net::Twitter::Lite;
		my $tw = Net::Twitter::Lite->new;
		my $lang = $args->{lang} || $blog->language || 'en';
		$results = $tw->search({ q => $query, lang => $lang, rpp => $lastn });
		$results->{blog_id} = 104;													## CHANGE THIS !!!!!!!!!!!!!!!!!!!!!!!!!!
# MT->log("results is: " . Dumper($results));
		insert_import_worker($results);
		$sess_obj = MT->model('session')->new;
		my @alpha = ( 'a' .. 'z', 'A' .. 'Z', 0 .. 9 );
	    my $token = join '', map $alpha[ rand @alpha ], 1 .. 40;
		$sess_obj->id($token);
	    $sess_obj->email($results->{max_id});
	    $sess_obj->name($query . $lastn);
	    $sess_obj->start(time);
	    $sess_obj->kind("TW");
		require MT::Serialize;
	    my $ser = MT::Serialize->serialize(\$results);
	    $sess_obj->data($ser);
	    $sess_obj->save();
	}
	
	
	MT->log("results are: " . Dumper($results));
	
	# if new tweets, add them to the DB?
	
	
	# now pull requested tweets from the DB and stash them
	
	my @tweets = @{$results->{results}};
	
    my $res = '';
    my $tok = $ctx->stash('tokens');
    my $builder = $ctx->stash('builder');
	my $i = 0;
    my $glue = $args->{glue};
    my $vars = $ctx->{__stash}{vars} ||= {};
    for my $tweet (@tweets) {
        local $vars->{__first__} = !$i;
        local $vars->{__last__} = !defined $tweets[$i+1];
        local $vars->{__odd__} = ($i % 2) == 0; # 0-based $i
        local $vars->{__even__} = ($i % 2) == 1;
        local $vars->{__counter__} = $i+1;
   #     local $ctx->{__stash}{blog} = $e->blog;
   #     local $ctx->{__stash}{blog_id} = $e->blog_id;
        local $ctx->{__stash}{tweet} = $tweet;
    #    local $ctx->{current_timestamp} = $e->authored_on;
    #    local $ctx->{modification_timestamp} = $e->modified_on;

        my $out = $builder->build($ctx, $tok, {
            %$cond,
            TweetsHeader => !$i,
            TweetsFooter => !defined $tweets[$i+1],
        });
        return $ctx->error( $builder->errstr ) unless defined $out;
        $res .= $glue if defined $glue && $i && length($res) && length($out);
        $res .= $out;
        $i++;
    }
    if (!@tweets) {
        return MT::Template::Context::_hdlr_pass_tokens_else(@_);
    }
	return $res;
}

sub _hdlr_tweet_source {
	my ($ctx, $args) = @_;
	my $tweet = $ctx->stash('tweet');
	return decode_html($tweet->{source});
}

sub _hdlr_tweet_from_user {
	my ($ctx, $args) = @_;
	my $tweet = $ctx->stash('tweet');
	return $tweet->{from_user};
}

sub _hdlr_tweet_profile_image_url {
	my ($ctx, $args) = @_;
	my $tweet = $ctx->stash('tweet');
	return $tweet->{profile_image_url};
}

sub _hdlr_tweet_status {
	my ($ctx, $args) = @_;
	my $tweet = $ctx->stash('tweet');
	my $status = $tweet->{text};
	$status = autolink_tweet($status) if $args->{autolink_tweet};
	return $status;
}

sub _hdlr_tweet_to_user {
	my ($ctx, $args) = @_;
	my $tweet = $ctx->stash('tweet');
	return $tweet->{to_user};
}

sub _hdlr_tweet_status_id {
	my ($ctx, $args) = @_;
	my $tweet = $ctx->stash('tweet');
	return $tweet->{id};
}

sub _hdlr_tweet_date {
	my ($ctx, $args) = @_;
	my $tweet = $ctx->stash('tweet');
	my $tweet_date = $tweet->{created_at};
	if (my $format = $args->{format}) {
		my $epoch = str2time($tweet_date);
#		MT->log("tweet epoch is $epoch");
		my $ts = epoch2ts($ctx->stash('blog'),$epoch);
#		MT->log("tweet ts is $ts");
		$args->{ts} = $ts;
	    $tweet_date = MT::Template::Context::_hdlr_date($ctx, $args);
#		MT->log("formatted date is $tweet_date");
	}
	return $tweet_date;
}

sub insert_import_worker {
	my ($results, $expiry) = @_;
    require MT::TheSchwartz;
    require TheSchwartz::Job;
    my $job = TheSchwartz::Job->new();
    $job->funcname('TwitterTools::Pro::Worker::SubscribeSearch');
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

sub autolink_urls {
    my ($str, $val, $ctx) = @_;
    $str =~ s!(^|\s|>)(https?://[^\s<]+)!$1<a href="$2">$2</a>!gs;
	$str;
}

sub autolink_hashtags {
    my ($str, $val, $ctx) = @_;
	my $url = 'http://mt-hacks.com/apple-links/tag/';				# CHANGE THIS !!!!!!!!!!!!!!!!!!!!!!!
    $str =~ s!(\A|\s)\#(\w+)!$1#<a href="$url$2">$2</a>!gs;
	$str;
}

1;