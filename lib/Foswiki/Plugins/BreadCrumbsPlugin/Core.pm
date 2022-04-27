# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006-2022 Michael Daum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

package Foswiki::Plugins::BreadCrumbsPlugin::Core;

use strict;
use warnings;
use constant TRACE => 0; # toggle me

use Foswiki::Func ();
use Foswiki::Plugins ();

###############################################################################
sub new {
  my $class = shift;
  my $session = shift || $Foswiki::Plugins::SESSION;

  my $this = bless({
    session => $session,
    homeTopic =>
       Foswiki::Func::getPreferencesValue('HOMETOPIC')
      || $Foswiki::cfg{HomeTopicName}
      || 'WebHome',
    @_
  }, $class);

  return $this;

  if ($Foswiki::Plugins::VERSION < 1.1) {
    $this->{lowerAlphaRegex} = Foswiki::Func::getRegularExpression('lowerAlpha');
    $this->{upperAlphaRegex} = Foswiki::Func::getRegularExpression('upperAlpha');
    $this->{numericRegex} = Foswiki::Func::getRegularExpression('numeric');
  }

  return $this;
}

###############################################################################
sub finish {
  my $this = shift;

  undef $this->{homeTopic};
  undef $this->{lowerAlphaRegex};
  undef $this->{upperAlphaRegex};
  undef $this->{numericRegex};
  undef $this->{i18n};
}

###############################################################################
sub recordTrail {
  my ($this, $web, $topic) = @_;

  _writeDebug("called recordTrail($web, $topic)");

  ($web, $topic) = Foswiki::Func::normalizeWebTopicName($web, $topic);
  my $here = "$web.$topic";
  my $trail = Foswiki::Func::getSessionValue('BREADCRUMB_TRAIL') || '';
  my @trail = split(',', $trail);

  # Detect cycles by scanning back along the trail to see if we've been here
  # before
  for (my $i = scalar(@trail) - 1; $i >= 0; $i--) {
    my $place = $trail[$i];
    if ($place eq $here) {
      splice(@trail, $i);
      last;
    }
  }
  push(@trail, $here);

  Foswiki::Func::setSessionValue('BREADCRUMB_TRAIL', join(',', @trail));
}

###############################################################################
sub renderBreadCrumbs {
  my ($this, $params, $currentTopic, $currentWeb) = @_;

  _writeDebug("called renderBreadCrumbs($currentWeb, $currentTopic)");

  # return an empty string if the current location is unknown
  return '' if $currentWeb eq 'Unknown' && $currentTopic eq 'Unknown';

  # get parameters
  my $webTopic = $params->{_DEFAULT} || "$currentWeb.$currentTopic";
  my $header = $params->{header} || '';
  my $format = $params->{format};
  my $topicformat = $params->{topicformat};
  my $newTopicFormat = $params->{newtopicformat};
  my $newWebFormat = $params->{newwebformat};
  my $footer = $params->{footer} || '';
  my $separator = $params->{separator};
  my $recurse = $params->{recurse} || 'on';
  my $include = $params->{include} || '';
  my $exclude = $params->{exclude} || '';
  my $type = $params->{type} || 'location';
  my $maxlength = $params->{maxlength} || 0;
  my $ellipsis = $params->{ellipsis};
  my $spaceout = $params->{spaceout} || 'off';
  my $spaceoutsep = $params->{spaceoutsep};
  my $translate = Foswiki::Func::isTrue($params->{translate}, 1);
  my @relation = split(/\s*,\s*/, $params->{relation} // 'parent');

  $separator = ' ' unless defined $separator;
  $separator = '' if $separator eq 'none';
  $format = '[[$webtopic][$name]]' unless defined $format;
  $topicformat = $format unless defined $topicformat;
  $newTopicFormat = '<nop>$topic' unless defined $newTopicFormat;
  $newWebFormat = '<nop>$name' unless defined $newWebFormat;
  $ellipsis = ' ... ' unless defined $ellipsis;
  $spaceout = ($spaceout eq 'on') ? 1 : 0;
  $spaceoutsep = '-' unless defined $spaceoutsep;

  my %recurseFlags = map { $_ => 1 } split(/,\s*/, $recurse);

  #foreach my $key (keys %recurseFlags) {
  #  _writeDebug("recurse($key)=$recurseFlags{$key}");
  #}

  # compute breadcrumbs
  my ($web, $topic) = Foswiki::Func::normalizeWebTopicName($currentWeb, $webTopic);
  my $breadCrumbs;
  if ($type eq 'path') {
    $breadCrumbs = $this->getPathBreadCrumbs();
  } else {
    $breadCrumbs = $this->getLocationBreadCrumbs($web, $topic, \@relation, \%recurseFlags);
  }

  my $doneSplice = 0;
  if ($maxlength) {
    my $length = @$breadCrumbs;
    if ($length > $maxlength) {
      splice(@$breadCrumbs, 0, $length - $maxlength);
      $doneSplice = 1;
    }
  }

  # format result
  my @lines = ();

  foreach my $item (@$breadCrumbs) {
    next unless $item;
    my $line;

    if ($item->{istopic}) {
      next if $exclude ne '' && $item->{topic} =~ /^($exclude)$/;
      next if $include ne '' && $item->{topic} !~ /^($include)$/;
      $line = $item->{isnew}?$newTopicFormat:$topicformat;
    } else {
      next if $exclude ne '' && $item->{web} =~ /^($exclude)$/;
      next if $include ne '' && $item->{web} !~ /^($include)$/;
      $line = $item->{isnew}?$newWebFormat:$format;
    }

    my $webtopic = $item->{target};
    $webtopic =~ s/\//./g;

    my $name = $item->{name};

    $name = $this->spaceOutWikiWord($item->{name}, $spaceoutsep) if $spaceout;
    $name = $this->translate($name, $item->{web}, $item->{topic}) if $translate;
    $line =~ s/\$name/$name/g;
    $line =~ s/\$target/$item->{target}/g;
    $line =~ s/\$webtopic/$webtopic/g;
    $line =~ s/\$topic/$item->{topic}/g;
    $line =~ s/\$web/$item->{web}/g;

    #_writeDebug("... added");
    push @lines, $line;
  }
  my $result = $header . ($doneSplice ? $ellipsis : '') . join($separator, @lines) . $footer;

  return Foswiki::Func::decodeFormatTokens($result);
}

###############################################################################
sub getPathBreadCrumbs {
  my $this = shift;

  my $trail = Foswiki::Func::getSessionValue('BREADCRUMB_TRAIL') || '';
  my @trail = map {
    /^(.*)\.(.*?)$/;
    my $web = $1;
    my $topic = $2;
    my $name = Foswiki::Func::getTopicTitle($web, $topic);
    $name = $web if $name eq $topic && $topic eq $this->{homeTopic};
    {
      target => $_,
      name => $name,
      web => $web,
      topic => $topic,
      istopic => 1,
      isnew => Foswiki::Func::topicExists($web, $topic)?0:1,
    }
  } split(',', $trail);

  return \@trail;
}

###############################################################################
sub getLocationBreadCrumbs {
  my ($this, $thisWeb, $thisTopic, $relation, $recurse) = @_;

  my @breadCrumbs = ();
  #_writeDebug("called getLocationBreadCrumbs($thisWeb, $thisTopic, @relation)");

  # collect all parent webs as breadcrumbs
  if ($recurse->{off} || $recurse->{weboff}) {
    my $webName = $thisWeb;
    if ($webName =~ /^(.*)[\.\/](.*?)$/) {
      $webName = $2;
    }

    #_writeDebug("adding breadcrumb: target=$thisWeb/$this->{homeTopic}, name=$webName");
    push @breadCrumbs, {
      target => "$thisWeb/$this->{homeTopic}",
      name => $webName,
      web => $thisWeb,
      topic => $this->{homeTopic},
      istopic => 0,
      isnew => (Foswiki::Func::webExists($thisWeb) && Foswiki::Func::topicExists($thisWeb, $this->{homeTopic}))?0:1,
    };
  } else {
    my $parentWeb = '';
    my @webCrumbs;
    foreach my $parentName (split(/\//, $thisWeb)) {
      $parentWeb .= '/' if $parentWeb;
      $parentWeb .= $parentName;
      my $name = Foswiki::Func::getTopicTitle($parentWeb, $this->{homeTopic});
      $name = $parentName if $name eq $this->{homeTopic};

      #_writeDebug("adding breadcrumb: target=$parentWeb/$this->{homeTopic}, name=$name");
      push @webCrumbs, {
        target => "$parentWeb/$this->{homeTopic}",
        name => $name,
        web => $parentWeb,
        topic => $this->{homeTopic},
        istopic => 0,
        isnew => (Foswiki::Func::webExists($parentWeb) && Foswiki::Func::topicExists($parentWeb, $this->{homeTopic}))?0:1,
      };
    }
    if ($recurse->{once} || $recurse->{webonce}) {
      my @list;
      push @list, pop @webCrumbs;
      push @list, pop @webCrumbs;
      push @breadCrumbs, reverse @list;
    } else {
      push @breadCrumbs, @webCrumbs;
    }
  }

  # collect all parent topics
  my %seen;
  unless ($recurse->{off} || $recurse->{topicoff}) {
    my $web = $thisWeb;
    my $topic = $thisTopic;
    my @topicCrumbs;

    while (1) {

      # get parent
      my ($meta) = Foswiki::Func::readTopic($web, $topic);
      my $parentName;
      foreach my $rel (@$relation) {
        if ($rel eq 'parent') {
          my $parentField = $meta->get('TOPICPARENT');
          $parentName = $parentField->{name} if $parentField;
        } else {
          my $formfield = $meta->get('FIELD', $rel);
          $parentName = $formfield->{value} if $formfield
        }
        last if $parentName;
      }

      last unless $parentName;
      ($web, $topic) = Foswiki::Func::normalizeWebTopicName($web, $parentName);

      # check end of loop
      last
        if $topic eq $this->{homeTopic}
          || $seen{"$web.$topic"}
          || !Foswiki::Func::topicExists($web, $topic);

      # add breadcrumb
      #_writeDebug("adding breadcrumb: target=$web/$topic, name=$topic");
      unshift @topicCrumbs, {
        target => "$web/$topic",
        name => Foswiki::Func::getTopicTitle($web, $topic),
        web => $web,
        topic => $topic,
        istopic => 1,
        isnew => Foswiki::Func::topicExists($web, $topic)?0:1,
      };
      $seen{"$web.$topic"} = 1;

      # check for bailout
      last
        if $recurse->{once}
          || $recurse->{topiconce};
    }
    push @breadCrumbs, @topicCrumbs;
  }

  # add this topic if it was not covered yet
  unless ($seen{"$thisWeb.$thisTopic"} || $recurse->{topicoff} || $thisTopic eq $this->{homeTopic}) {

    #_writeDebug("finally adding breadcrumb: target=$thisWeb/$thisTopic, name=$thisTopic");
    push @breadCrumbs, {
      target => "$thisWeb/$thisTopic",
      name => Foswiki::Func::getTopicTitle($thisWeb, $thisTopic),
      web => $thisWeb,
      topic => $thisTopic,
      istopic => 1,
      isnew => Foswiki::Func::topicExists($thisWeb, $thisTopic)?0:1,
    };
  }

  return \@breadCrumbs;
}

###############################################################################
sub i18n {
  my $this = shift;

  unless (defined $this->{i18n}) {
    $this->{i18n} = $this->{session}->i18n();
  }

  return $this->{i18n};
}

###############################################################################
sub translate {
  my ($this, $string, $web, $topic) = @_;

  my $result;

  $string =~ s/^_+//; # strip leading underscore as maketext doesnt like it

  my $context = Foswiki::Func::getContext();
  if ($context->{'MultiLingualPluginEnabled'}) {
    require Foswiki::Plugins::MultiLingualPlugin;
    $result = Foswiki::Plugins::MultiLingualPlugin::translate($string, $web, $topic);
  } else {
    $result = $this->i18n->maketext($string);
  }

  return $result;
}

###############################################################################
sub spaceOutWikiWord {
  my ($this, $wikiWord, $separator) = @_;

  return Foswiki::Func::spaceOutWikiWord($wikiWord, $separator)
    if $Foswiki::Plugins::VERSION >= 1.13;

  $wikiWord =~ s/([$this->{lowerAlphaRegex}])([$this->{upperAlphaRegex}$this->{numericRegex}]+)/$1$separator$2/g;
  $wikiWord =~ s/([$this->{numericRegex}])([$this->{upperAlphaRegex}])/$1$separator$2/g;

  return $wikiWord;
}

###############################################################################
sub _writeDebug {
  return unless TRACE;

  #Foswiki::Func::writeDebug('- BreadCrumbPlugin - '.$_[0]);
  print STDERR '- BreadCrumbPlugin - ' . $_[0] . "\n";
}
1;
