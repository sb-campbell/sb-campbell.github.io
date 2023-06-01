---
title: Build A Static Blog Website Hosted On GitHub Pages With Jekyll
date: 2023-06-01 12:00:00 -0500
categories: [How-to, GitHub]
tags: [github,jekyll,blog]     # TAG names should always be lowercase
---

GitHub is an excellent tool to source a static website. Among the many benefits are..
* integrates easily with git and repos
* CI/CD automation can be integrated with GitHub Actions
* sub-domains named specifically for the GitHub account holder are available
* availability of a large number of themes using a static website builder such as Jekyll
* blog articles can be written in [GitHub MarkDown language format](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax) 

Jekyll is a static site generator that transforms your plain text into beautiful static web sites and blogs. It can be used for a documentation site, a blog, an event site, or really any web site you like. It’s fast, secure, easy, and open source. 

Chirpy is a Jekyll theme with a lot of great features...

* Dark / Light Theme Mode
* Localized UI language
* Pinned Posts
* Hierarchical Categories
* Trending Tags
* Table of Contents
* Last Modified Date of Posts
* Syntax Highlighting
* Mathematical Expressions
* Mermaid Diagram & Flowchart
* Dark / Light Mode Images
* Embed Videos
* Disqus / Utterances / Giscus Comments
* Search
* Atom Feeds
* Google Analytics
* Page Views Reporting
* SEO & Performance Optimization

Let's get started...

## Install Jekyll

### MacOS (via HomeBrew) [guide](https://jekyllrb.com/docs/installation/macos/)

### ***Pre-requisite:*** Ruby<br>

* xz - a general purpose data compression format with a  high compression ratio and relatively fast decompression
* [chruby](https://mac.install.guide/ruby/12.html) - a version manager for ruby similar to pyenv for python (other options include asdf, frum, rbenv and rvm)
  * [How to install and use different versions of ruby with chruby](https://www.moncefbelyamani.com/how-to-install-xcode-homebrew-git-rvm-ruby-on-mac/#how-to-install-different-versions-of-ruby-and-switch-between-them)
* ruby-install - ruby homebrew package

```bash
brew install chruby ruby-install xz
```

* add ruby version support to shell environment by adding to .bash_profile and restarting shell

```bash
# Add the following to the ~/.bash_profile or ~/.zshrc file:
source /usr/local/opt/chruby/share/chruby/chruby.sh
# To enable auto-switching of Rubies specified by .ruby-version files, add the following to ~/.bash_profile or ~/.zshrc:
source /usr/local/opt/chruby/share/chruby/auto.sh
chruby ruby-3.2.2
```

* verify the version of ruby-install

```bash
ruby-install -V
```

* check the latest version(s) of ruby (or [documentation](https://www.ruby-lang.org/en/downloads/))

```bash
ruby-install --latest
```

* install the latest version of ruby (may take 30+ min)

```bash
ruby-install --latest ruby    # or choose a specific version (ie. 3.2.2)
```

* restart the terminal session and verify ruby version

```bash
ruby -v
```

### Install the latest Jekyll and bundler gems

```bash
gem install jekyll bundler
```

## Build the blog website using the Chirpy theme's starter

### GitHub repo for the blog website

Visit [https://chirpy.cotes.page/posts/getting-started/](https://chirpy.cotes.page/posts/getting-started/)

* Follow instructions for ...<br>
'Option 1. Using the Chirpy Starter'<br>
... and create a GitHub repository to hold the blog website
  * Name the new repo '{GitHub username}.github.io'

* Clone the repo to your local workstation

### Basic Chirpy setup and config...

* Execute 'bundle' locally to update Jekyll with all required dependencies based on the Chirpy them

```bash
bundle
```
* Test the site locally

```bash
bundle exec jekyll s
```

Via browser, visit [http://127.0.0.1:4000/](http://127.0.0.1:4000/)

Edit common site settings in '_config.yml' ...

* baseurl
* lang
* timezone
* title
* tagline
* description
* url
* github -> username
* twitter -> username
* social -> name & links (Twitter, GitHub, LinkedIn)
* avatar (see below to use Twitter profile image)
* comments (optional)
* theme_mode (I set mine to 'dark' only)

### __ISSUE__: Skipping post with future date

I resolved this issue by adding a parameter to '_config.yml'...

* future: true

The issue is discussed [here](https://github.com/jekyll/jekyll/issues/6536)

### Twitter profile image as avatar

It is useful to use your Twitter profile image as the remote avatar for your blog website. To obtain the URL to the image follow these steps and add the URL to the avatar setting in _config.yml...

* Visit [Twitter](https://twitter.com/home) and click on your avatar to bring up your profile page
* View page source - (Firefox - Context click on white-space on your profile page and click -> View Page Source)
* Search for '*pbs.twimg.com/profile_images*'
* Copy the full URL
  * Substitute the word '*normal*' in the URL with '*bigger*' or '*400x400*' (this is what I used)
* Test the edited URL in the browser
* __NOTE__: This [Twitter API doc](https://developer.twitter.com/en/docs/twitter-api/v1/accounts-and-users/user-profile-images-and-banners) may be helpful if issues persist

## Write you first blog post

The Chirpy developer's own [wiki](https://chirpy.cotes.page/posts/write-a-new-post/) is the best place for details on how to create blog posts.

* Edit a new *.md file in the ./_posts/ directory and name it like 'YYYY-MM-DD-TITLE.md'
* Place the following 'front matter' in the header of the new document
```yaml
---
title: TITLE
date: YYYY-MM-DD HH:MM:SS +/-TTTT
categories: [TOP_CATEGORIE, SUB_CATEGORIE]
tags: [TAG]     # TAG names should always be lowercase
---
```
* Write your blog article

There are a lot of additional post config options available. See the developer's documentation above for details.

## Launch Jekyll locally to verify

Make sure you're in the root of your local clone of the GitHub repository. I was accidentally in the _posts/ directory and it did not go well.

Launch your local website

```bash
bundle exec jekyll s
```

Test via browser at [http://127.0.0.1:4000](http://127.0.0.1:4000)

## Deploy your blog to GitHub Pages

These instructions seem to change somewhat frequently so it's best to follow the developer's instructions [here](https://chirpy.cotes.page/posts/getting-started/#deploy-by-using-github-actions)

## Links
> Jekyll [Home](https://jekyllrb.com), 
> [Documentation](https://jekyllrb.com/docs/)

> Themes:<br>
>* __Our Choice ->__ [Chirpy](https://github.com/cotes2020/jekyll-theme-chirpy) ([wiki](https://github.com/cotes2020/jekyll-theme-chirpy/wiki)) ([Getting Started](https://chirpy.cotes.page/posts/getting-started/) instructions) (basic blog w/ light/dark modes and other advanced features)<br>
>* [Academic Pages](https://github.com/academicpages/academicpages.github.io) (student theme)<br>
>* [JekFlix](https://github.com/thiagorossener/jekflix-template) (similar to Netflix theme)<br>
>* [Al-folio](https://alshedivat.github.io/al-folio/) (personal)

## Special thanks
> [Techno Tim](https://www.youtube.com/watch?v=F8iOU1ci19Q)<br>
> [Spencer Pao](https://www.youtube.com/watch?v=g6AJ9qPPoyc)