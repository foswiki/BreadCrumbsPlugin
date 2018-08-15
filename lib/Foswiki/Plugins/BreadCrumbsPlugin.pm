# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006-2018 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::BreadCrumbsPlugin;

use strict;
use warnings;

our $VERSION = '3.20';
our $RELEASE = '15 Aug 2018';
our $NO_PREFS_IN_TOPIC = 1;
our $SHORTDESCRIPTION = 'A flexible way to display breadcrumbs navigation';
our $core;

###############################################################################
sub initPlugin {

  Foswiki::Func::registerTagHandler(
    'BREADCRUMBS',
    sub {
      my $session = shift;
      return getCore($session)->renderBreadCrumbs(@_);
    }
  );

  my $doRecordTrail = Foswiki::Func::isTrue(Foswiki::Func::getPreferencesValue('BREADCRUMBSPLUGIN_RECORDTRAIL'), 0);
  if ($doRecordTrail) {
    getCore()->recordTrail($_[1], $_[0]);
  } else {

    #print STDERR "not recording the click path trail\n";
  }

  return 1;
}

###############################################################################
sub finishPlugin {
  if (defined $core) {
    $core->finish();
    undef $core;
  }
}

###############################################################################
sub getCore {

  unless (defined $core) {
    require Foswiki::Plugins::BreadCrumbsPlugin::Core;
    $core = Foswiki::Plugins::BreadCrumbsPlugin::Core->new(@_);
  }

  return $core;
}

1;
