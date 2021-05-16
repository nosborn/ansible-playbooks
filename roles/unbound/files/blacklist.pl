#!/usr/bin/perl -w

use strict;
use warnings;
use 5.010;

use Digest::SHA1 qw(sha1_hex);
use File::Copy;
use HTTP::Tiny;

use constant LISTS => (
  "https://raw.githubusercontent.com/nextdns/cname-cloaking-blocklist/master/domains",

  "https://raw.githubusercontent.com/nextdns/metadata/master/privacy/native/alexa",
  "https://raw.githubusercontent.com/nextdns/metadata/master/privacy/native/apple",
  "https://raw.githubusercontent.com/nextdns/metadata/master/privacy/native/huawei",
  "https://raw.githubusercontent.com/nextdns/metadata/master/privacy/native/roku",
  "https://raw.githubusercontent.com/nextdns/metadata/master/privacy/native/samsung",
  "https://raw.githubusercontent.com/nextdns/metadata/master/privacy/native/sonos",
  "https://raw.githubusercontent.com/nextdns/metadata/master/privacy/native/windows",
  "https://raw.githubusercontent.com/nextdns/metadata/master/privacy/native/xiaomi",

  "https://raw.githubusercontent.com/nextdns/metadata/master/security/parked-domains-cname",

  # https://github.com/nextdns/metadata/blob/master/privacy/blocklists/nextdns-recommended.json
  "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts",
  "https://raw.githubusercontent.com/jdlingyu/ad-wars/master/hosts",
  "https://raw.githubusercontent.com/VeleSila/yhosts/master/hosts",
  "https://raw.githubusercontent.com/tiuxo/hosts/master/ads",

  # https://github.com/nextdns/metadata/blob/master/privacy/blocklists/disconnect-ads.json
  "https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt",

  # https://github.com/nextdns/metadata/blob/master/privacy/blocklists/disconnect-ads.json
  "https://s3.amazonaws.com/lists.disconnect.me/simple_malvertising.txt",

  # https://github.com/nextdns/metadata/blob/master/privacy/blocklists/disconnect-tracking.json
  "https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt",

  # https://github.com/nextdns/metadata/blob/master/privacy/blocklists/perflyst-smarttv.json
  "https://raw.githubusercontent.com/Perflyst/PiHoleBlocklist/master/SmartTV.txt",

  # https://github.com/nextdns/metadata/blob/master/privacy/blocklists/someonewhocares.json
  "https://someonewhocares.org/hosts/hosts",

  # https://github.com/nextdns/metadata/blob/master/security/cryptojacking.json
  "https://raw.githubusercontent.com/hoshsadiq/adblock-nocoin-list/master/hosts.txt",
  "https://zerodot1.gitlab.io/CoinBlockerLists/hosts_browser",
);

my %names = (
  "com\t7hor9gul4s"                        => 1,
  "com\ta3yqjsrczwwp"                      => 1,
  "com\ta4mt150303tl"                      => 1,
  "com\tau79nt5wic4x"                      => 1,
  "com\tbrandmetrics"                      => 1,
  "com\tchatango\tst"                      => 1,
  "com\tduckduckgo\ticons"                 => 1,
  "com\tfacebook\tgraph"                   => 1,
  "com\tgoogle\tdns"                       => 1, # DoH
  "com\tgoogle\tl\tgstaticadssl"           => 1,
  "com\tgoogleapis\tcrashlyticsreports-pa" => 1,
  "com\ticloud\tmetrics"                   => 1,
  "com\tmeethue\tdiagnostics"              => 1,
  "com\tmicrosoft\tipv6\twin10"            => 1,
  "com\tmicrosoft\tipv6\twin1710"          => 1,
  "com\tmyadcash"                          => 1,
  "com\tnvidia\tgfe\tevents"               => 1,
  "com\tr023m83skv5v"                      => 1,
  "com\treddit\te"                         => 1,
  "com\trevenuecat\tapi"                   => 1,
  "com\troku\tcaptive"                     => 1,
  "com\troku\tcto\ttis"                    => 1,
  "com\tsnapchat\app-analytics"            => 1,
  "com\tsocialbars-web1"                   => 1,
  "com\tsocialbars-web5"                   => 1,
  "com\tubnt\tunifi-report"                => 1,
  "com\tw7zglmcdreij"                      => 1,
  "com\tximad\tadserver"                   => 1,
  "com\tximad\tmjp-analytics"              => 1,
  "com\tximad\tmpuzzlesanalytics"          => 1,
  "com\tzav4gln44kez"                      => 1,
  "la\tsoom\tteleport"                     => 1,
  "net\tapple-dns\tfe\tmetrics"            => 1,
  "net\tbdurl\tdig"                        => 1, # DoH
  "today\tgetup"                           => 1,
  "uk\tco\tbbci\tfiles\tmybbc-analytics"   => 1,
);
my $verbose = 0;

chdir('/var/cache/unbound') or die;

my $ht = HTTP::Tiny->new;

foreach my $url (LISTS) {
  my $file = sha1_hex($url);
  print STDERR "Start $url ($file)\n" if $verbose;

  my $response = $ht->mirror($url, $file);
  if ($response->{success}) {
    open(my $fh, '<', $file) or die;

    LINE: while (my $line = <$fh>) {
      chomp $line;
      $line =~ s/#.*$//;
      $line =~ s/\s+$//;
      next unless $line;

      my @fields = split /\s+/, $line;

      if (scalar @fields == 2) {
        next if $fields[0] eq '255.255.255.255';
        shift @fields if ($fields[0] =~ /^(0|0\.0\.0\.0|127\.0\.0\.1|::|::1)$/);
        next if ($fields[0] =~ /^(0|0\.0\.0\.0|127\.0\.0\.1|::|::1)$/); # StevenBlack
      }
      unless (scalar @fields == 1) {
        print STDERR "Ignoring: $line\n" if $verbose;
        next;
      }

      my $name = lc($fields[0]);
      $name =~ s/\.+$//;
      if (length($name) > 253) {
        printf"Ignoring: $name\n" if $verbose;
        next;
      }
      my @labels = split /\./, $name;
      if (scalar(@labels) < 2) {
        print "Ignoring: $name\n" if $verbose;
        next;
      }
      if (grep { length() < 1 or length() > 63 or /[^-a-zA-Z0-9_]/ or /^-/ or /-$/ } @labels) {
        print "Ignoring: $name\n" if $verbose;
        next;
      }
      my $rname = join("\t", reverse @labels);

      $names{$rname}++;
    }
  } else {
    say "$url";
    say "Failed: $response->{status} $response->{reasons}";
  }
}

print "\$TTL 2h\n";
printf("@ IN SOA localhost. root.localhost. (%u 6h 1h 1w 2h)\n", time());
print "  IN NS localhost.";
my $prefix = "\t";
foreach my $rname (sort(keys %names)) {
  next if rindex($rname, $prefix, 0) == 0;
  my $name = join('.', reverse split("\t", $rname));
  # print "local-zone: \"$name.\" static\n";
  print "$name CNAME .\n";
  $prefix = "${rname}\t";
}
