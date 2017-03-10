# Sonarr-Menu
#####OSX Status Menu for Sonarr 

[![No Maintenance Intended](http://unmaintained.tech/badge.svg)](http://unmaintained.tech/)
####I've stopped using MacOS for Sonarr, so will no longer be maintaining this project. Forking is welcome!



This is a small utility that adds a menu to the Status Bar for managing [Sonarr](https://sonarr.tv).

Features include:
* Easy access to web interface
* Enable Run-at-login behavior from gui
* View running state of Sonarr daemon

Version 3 strips out code that managed downloading prerequisites and updates in favor of using Homebrew Cask.
Now it's easier than ever to install Sonarr with a menu on OSX:

First install [Homebrew](http://brew.sh/),  
$ `ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"`  

Next install [Homebrew Cask](http://caskroom.io/),  
$ `brew install caskroom/cask/brew-cask`

Then install Sonarr-Menu,  
$ `brew cask install sonarr-menu`
