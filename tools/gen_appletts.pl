#!/usr/bin/perl
#
# FreeSWITCH Sound File Generator using Apple TTS engine.
# 
# Created by CbS Ghost, 2021.
# Copyright (c) 2021 CbS Ghost. All rights reserved.
# (This special version is licensed under MPL-2.0)
#
use strict;
use warnings;

use Cwd;
use Getopt::Long;
use File::Path;
use Pod::Usage;
use XML::LibXML;

my @locale = split(/_|-/, $ARGV[0]);

my $help   = undef;
my $voice  = undef;
my $rate   = undef;

GetOptions('help|h|?'  => \$help,
           'voice|v=s' => \$voice,
           'rate|r=i'  => \$rate);

pod2usage(1) if ($help || !$locale[0] || !$locale[1] || $locale[2]);

$voice = undef if ($voice && $voice eq '');
$rate  = undef if ($rate && $rate < 1);

my $phrase_filename = 'phrase/phrase_' . lc($locale[0]) . '_'
                                       . uc($locale[1]) . '.xml';

my $phrase_dom = XML::LibXML->load_xml(location => $phrase_filename);
my @phrase_nodelist = $phrase_dom->findnodes('/language/' . lc($locale[0])
                                                    . '_' . uc($locale[1])
                                                    . '/*');

my $build_root_path = Cwd::getcwd($0) . '/build/' . lc($locale[0]) . '/'
                      . lc($locale[1]) . '/'
                      . (lc($voice =~ s/([^[:alpha:]])//gr) || '_apple');
my @build_bitrates = ('8000', '16000', '32000', '48000');

sub process_phrase_node {
    my $path = $_[0];
    my $node = $_[1];

    return if ($node->nodeType != XML::LibXML::XML_ELEMENT_NODE);

    if ($node->nodeName eq 'prompt') {
        my $filename = $node->getAttribute('filename');
        my $sentence = $node->getAttribute('phrase');
        $sentence = ($sentence eq 'NULL') ? ' ' : $sentence;

        for my $bitrate (@build_bitrates) {
            my $cwd_path = $path . '/' . $bitrate;
            if (! -d $cwd_path) {
                unlink $cwd_path if (-e $cwd_path);
                File::Path::make_path($cwd_path);
            }
            my $file_path = $cwd_path . '/' . $filename;
            
            my $tts_cmd = 'say ' . ($voice ? ("-v $voice ") : '')
                                 . ($rate ? ("-r $rate ") : '')
                                 . "-o '$file_path' "
                                 . "--data-format=I16\@$bitrate "
                                 . "'$sentence'";

            print($file_path . "\n");

            `$tts_cmd`;
        }
    } else {
        $path = $path . '/' . $node->nodeName;
    }

    for my $child_node ($node->childNodes) {
        process_phrase_node($path, $child_node);
    }
}

for my $phrase_node (@phrase_nodelist) {
    process_phrase_node($build_root_path, $phrase_node);
}

print("All done!!\n");

__END__

=head1 SYNOPSIS

./gen_appletts.pl [options] [lang_tag]

  Options:
    -h | --help         brief help message
    -v | --voice        specify speaking voice
    -r | --rate         specify speaking rate
