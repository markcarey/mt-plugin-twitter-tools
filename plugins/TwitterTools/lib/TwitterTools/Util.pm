package TwitterTools::Util;

use strict;
use base 'Exporter';

our @EXPORT_OK = qw( autolink_tweet shorten truncate_string twtools_pro );

use MT::Util qw( trim );

sub autolink_tweet {
	my ($str) = @_;
	# autolink URLs
    $str =~ s!(^|\s|>)(https?://[^\s<]+)!$1<a href="$2">$2</a>!gs;
	# autolink @mentions
	$str =~ s!\@([a-zA-Z_]+)!\@<a href="http://twitter.com/$1">$1</a>!gs;
	return $str;
}

sub shorten {
	my ($long_url, $config) = @_;
	return $long_url if $config->{never_shorten};
	return $long_url if (length($long_url) < 26);
	my $service = $config->{shortner_service};
	$service = 'Bitly' if ($service eq 'Bit.ly');
	my $user = $config->{shortner_username};
	my $api_key = $config->{shortner_apikey};
	return $long_url if !$service;
	my $class = "WWW::Shorten " . "'" . $service . "'";
	eval "use $class";
	if ($@) {
		MT->log("Twitter Tools shorten Error: " . $@);
		return $long_url;
	}
	my $api_url = MT->config('URLShortenerAPIBaseURL');
    my $short_url = makeashorterlink($long_url,$user,$api_key,$api_url);	
	return $short_url;
}

sub truncate_string {
    my($text, $max) = @_;
	$max = $max - 3;
	my $len = length($text);
	return $text if $len <= $max;
    my @words = split /\s+/, $text;
	$text = '';
	foreach my $word (@words) {
		if (length($text . $word) <= $max) {
			$text .= $word . ' ';
		}
	}
	$text = trim($text);
	$text .= '...' if ($len > length($text));
    return $text;
}

sub twtools_pro {
    eval{ require TwitterTools::Pro::Callbacks };
}

1;