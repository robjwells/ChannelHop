# ChannelHop

An AppleScript to automate fetching and laying-out TV listings, developed for 
the [Morning Star][ms].

It prompts the user for a date, uses that to fetch the right listings files
from an FTP server, formats them and sets each channel’s listings in its own
frame in an InDesign document.

As it stands, ChannelHop specifically address the needs of the [Star][ms] but
hopefully it can be of some help if you face a similar problem of fetching, 
cleaning and setting text for publication.

However, if your company subscribes to [Red Bee Media’s listings service][bds]
then it shouldn’t take too much work to adapt ChannelHop to work for you.

This repository doesn’t have an example InDesign page, but it’s pretty
straightforward to set up. The frame name is specified in each call to
`grepChannel`, with modifiers for separate AM/PM listings, and again for
Saturday and Sunday listings (which the Star publishes on the same spread).

[bds]: http://bds.tv
[ms]: http://morningstaronline.co.uk