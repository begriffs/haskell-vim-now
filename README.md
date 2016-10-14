[![Build Status](https://travis-ci.org/begriffs/haskell-vim-now.svg?branch=master)](https://travis-ci.org/begriffs/haskell-vim-now)
<img src="img/haskell.png" align="right" />
<img src="img/vim.png" align="right" />

<h2 align="left">Haskell Vim IDE</h2>

<br />

In less than **ten minutes** your Vim will transform into a beautiful
Haskell paradise.  (Don't worry, it backs up your original
configuration to `~/.config/haskell-vim-now/backup/.vimrc.yearmonthdate_time`.) It also builds all necessary support binaries
including `codex`, `hscope`, `ghc-mod`, `hasktags`, `hoogle` and more.

No more wading through plugins trying to make them all work together.
In ten minutes you will have a fully functional Vim that looks great
and lets you

* inspect types
* evaluate Haskell
* lint and check
* manipulate tags
* hoogle lookup
* pointfree refactor
* tab complete
* unicode symbols
* highlight DSLs
* work with git


## Installation

Just download and run the installer:

```sh
curl -L https://git.io/haskell-vim-now > /tmp/haskell-vim-now.sh
bash /tmp/haskell-vim-now.sh
```
**WARNING**: this command, once successful, will _make backups and **remove**_ your existing VIM configurations (`.vim`, plugins etc). You can later [customize](#customizing) HVN configurations.

## Keybindings and commands

The commands are organized into logical groups to help you remember
them.

### Types, autocomplete, refactoring, and linting

<table>
<tbody>
  <tr>
    <td>&lt;Tab&gt;</td><td>Autocomplete with words in file</td>
  </tr>
  <tr>
    <td>&lt;C-space&gt;</td><td>Autocomplete with symbols in your Cabal sandbox</td>
  </tr>
  <tr>
    <td>,ht</td><td>Show type of expression under cursor</td>
  </tr>
  <tr>
    <td>,hT</td><td>Insert type of expression into previous line</td>
  </tr>
  <tr>
    <td>,hr</td><td>Apply one refactoring hint at cursor position</td>
  </tr>
  <tr>
    <td>,hR</td><td>Apply all refactoring suggestions in the file</td>
  </tr>
  <tr>
    <td>,hl</td><td>Run Haskell linter on file</td>
  </tr>
  <tr>
    <td>,hc</td><td>Run Haskell compile check on file</td>
  </tr>
  <tr>
    <td>,&lt;cr&gt;</td><td>Clear type selection</td>
  </tr>
</tbody>
</table>

### Hoogle

<table>
<tbody>
  <tr>
    <td>,hh</td><td>Run Hoogle on the word under the cursor</td>
  </tr>
  <tr>
    <td>,hH</td><td>Run Hoogle and prompt for input</td>
  </tr>
  <tr>
    <td>,hi</td><td>Run Hoogle for detailed information on word under cursor</td>
  </tr>
  <tr>
    <td>,hI</td><td>Run Hoogle for detailed information and prompt for input</td>
  </tr>
  <tr>
    <td>,hz</td><td>Close the Hoogle search window</td>
  </tr>
</tbody>
</table>

### GHCI repl

If you open a tmux terminal alongside MacVim then you can send Vim
selections to it. This works well for evaluating things in GHCI.

<table>
<tbody>
  <tr>
    <td>,rs</td><td>Send selected text to tmux</td>
  </tr>
  <tr>
    <td>,rv</td><td>Change tmux session, window, and pane attachment</td>
  </tr>
</tbody>
</table>

### Git

<table>
<tbody>
  <tr>
    <td>,g?</td><td>Last-committed files (Monday morning key)</td>
  </tr>
  <tr>
    <td>,gs</td><td>Git status (fugitive)</td>
  </tr>
  <tr>
    <td>,gg</td><td>Git grep</td>
  </tr>
  <tr>
    <td>,gl</td><td>Git log (extradition)</td>
  </tr>
  <tr>
    <td>,gd</td><td>Git diff</td>
  </tr>
  <tr>
    <td>,gb</td><td>Git blame</td>
  </tr>
</tbody>
</table>

### Commenting

<table>
<tbody>
  <tr>
    <td>gc</td><td>Comment / Uncomment selection</td>
  </tr>
</tbody>
</table>

### Aligning

<table>
<tbody>
  <tr>
    <td>,a=</td><td>Align on equal signs</td>
  </tr>
  <tr>
    <td>,a,</td><td>Align on commas</td>
  </tr>
  <tr>
    <td>,a|</td><td>Align on vertical bar</td>
  </tr>
  <tr>
    <td>,ap</td><td>Align on character of your choice</td>
  </tr>
</tbody>
</table>

### Splits and find file

<table>
<tbody>
  <tr>
    <td>,&lt;space&gt;</td><td>Fuzzy file find (CtrlP)</td>
  </tr>
  <tr>
    <td>,f</td><td>Toggle file browser, find file</td>
  </tr>
  <tr>
    <td>,F</td><td>Toggle file browser</td>
  </tr>
  <tr>
    <td>,sj</td><td>Open split below</td>
  </tr>
  <tr>
    <td>,sk</td><td>Open split above</td>
  </tr>
  <tr>
    <td>,sh</td><td>Open split leftward</td>
  </tr>
  <tr>
    <td>,sl</td><td>Open split rightward</td>
  </tr>
</tbody>
</table>

### Tags

<table>
<tbody>
  <tr>
    <td>,tg</td><td>Generate tags with codex</td>
  </tr>
  <tr>
    <td>,tt</td><td>Open/close the tag bar</td>
  </tr>
  <tr>
    <td>C-]</td><td>Jump to definition of symbol (codex + hasktags)</td><td>Note: You must generate the tags for your project (with <code>,tg</code>) prior to using the jump command.</td> 
  </tr>
  <tr>
    <td>C-\</td><td>Show uses of symbol (hscope)</td>
  </tr>
</tbody>
</table>

### Conversions

<table>
<tbody>
  <tr>
    <td>,h.</td><td>Transform visual selection to pointfree style</td>
  </tr>
  <tr>
    <td>,h&gt;</td><td>Transform visual selection to pointed style</td>
  </tr>
</tbody>
</table>

### Buffers

<table>
<tbody>
  <tr>
    <td>,bp</td><td>Previous buffer</td>
  </tr>
  <tr>
    <td>,bn</td><td>Next buffer</td>
  </tr>
  <tr>
    <td>,b&lt;space&gt;</td><td>Buffer fuzzy finder</td>
  </tr>
  <tr>
    <td>,bd</td><td>Delete buffer, keep window open (bbye)</td>
  </tr>
  <tr>
    <td>,bo</td><td>Close all buffers except the current one</td>
  </tr>
</tbody>
</table>

### Misc

<table>
<tbody>
  <tr>
    <td>,ma</td><td>Enable mouse mode (default)</td>
  </tr>
  <tr>
    <td>,mo</td><td>Disable mouse mode</td>
  </tr>
  <tr>
    <td>,ig</td><td>Toggle indentation guides</td>
  </tr>
  <tr>
    <td>,u</td><td>Interactive undo tree</td>
  </tr>
  <tr>
    <td>,ss</td><td>Enable spell checking</td>
  </tr>
  <tr>
    <td>,e</td><td>Open file prompt with current path</td>
  </tr>
  <tr>
    <td>,&lt;cr&gt;</td><td>Clear search highlights</td>
  </tr>
  <tr>
    <td>,r</td><td>Redraw screen</td>
  </tr>
  <tr>
    <td>C-h</td><td>Move cursor to leftward pane</td>
  </tr>
  <tr>
    <td>C-k</td><td>Move cursor to upward pane</td>
  </tr>
  <tr>
    <td>C-j</td><td>Move cursor to downward pane</td>
  </tr>
  <tr>
    <td>C-l</td><td>Move cursor to rightward pane (redraw is `,r` instead)</td>
  </tr>
  <tr>
    <td>gq</td><td>Format selection using `hindent` for haskell buffers (`par` for others)</td>
  </tr>
  <tr>
    <td>,y</td><td>Yank to OS clipboard</td>
  </tr>
  <tr>
    <td>,d</td><td>Delete to OS clipboard</td>
  </tr>
  <tr>
    <td>,p</td><td>Paste from OS clipboard</td>
  </tr>
</tbody>
</table>

(If you prefer to restore the default screen redraw action of `C-l`
then add `unmap <c-l>` to your vimrc.local)

## Customizing

After installing this configuration, your `.vimrc` and `.vim` will
be under version control. Don't alter these files. Instead, add
your own settings to `~/.config/haskell-vim-now/vimrc.local.pre`,
`~/.config/haskell-vim-now/vimrc.local`.

## Adding Vim Plugins

Haskell-Vim-Now uses [vim-plug](https://github.com/junegunn/vim-plug)
to install plugins. It uses the following vim configuration structure
to determine what to install:

```viml
call plug#begin('~/.vim/plugged')

" The plugins are named in github short form, for example:
Plug 'junegunn/vim-easy-align'

" All plug statements must be between plug#begin and plug#end
call plug#end()
```

However the `.vimrc` file in Haskell-Vim-Now is under version control
so you shouldn't edit it directly. To add a plugin what you should
do is add `Plug` statements to `~/.config/haskell-vim-now/plugins.vim`.
When ready reload `.vimrc` and run `:PlugInstall` to install plugins.

## Neovim support

The `.vimrc` configuration is fully compatible with Neovim, and adds a few
Neovim specific mappings for the terminal mode (terminal emulation is activated
with `:terminal`). The mappings make `Esc` and `c-[hjkl]` function as one would
expect them to from normal mode.

The Neovim configuration is found at `.config/nvim`, and is symlinked just like
regular vim, which means you should only add your own settings to
`~/.config/haskell-vim-now/vimrc.local.pre`, `~/.config/haskell-vim-now/vimrc.local`
and `~/.config/haskell-vim-now/plugins.vim`.

You can quickly backup and replace your Neovim setup by running the `scripts/neovim.sh`
script.

## Docker image

If you are into developing with Docker, you can use the image.

    docker pull haskell:7.8
    docker build -t haskell-vim .
    docker run --rm -i -t haskell-vim /bin/bash

If instead you want to extract the vim setup from the image that is easy enough

    docker build -t haskell-vim .
    mkdir ~/.haskell-vim-now
    cd ~/.haskell-vim-now
    docker run --rm haskell-vim tar -cz -C /root/.haskell-vim-now . > haskell-vim-now.tgz
    tar -xzf haskell-vim-now.tgz

However, some things (for example the hoogle database) use absolute paths and don't work correctly.

## Advanced install methods

### Basic install
In case you want to skip the haskell specific components and want to install
just the common vim config you can use:
```sh
bash <(curl -sL https://git.io/haskell-vim-now) --basic
```

### Installing from a fork or clone
If you have a modified fork you can use the `--repo` option to tell the install
script the location of your repository:
```sh
bash <(curl -sL INSTALL-SCRIPT-URL) --repo FORK-URL
```

For example:

```sh
bash <(curl -sL https://raw.githubusercontent.com/begriffs/haskell-vim-now/master/install.sh) --repo https://github.com/begriffs/haskell-vim-now
```

If you have a local git clone you can use `install.sh` directly
to install from your clone:
```sh
install.sh --repo CLONE-PATH
```

## Troubleshooting

See this [wiki](https://github.com/begriffs/haskell-vim-now/wiki/Installation-Troubleshooting)
page for tips on fixing installation problems.

## Thank you!

Big thanks to [contributors](https://github.com/begriffs/haskell-vim-now/graphs/contributors). I'd especially like to thank [@SX91](https://github.com/SX91) for rewriting the installer and for other major improvements.
