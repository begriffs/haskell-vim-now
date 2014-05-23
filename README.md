<img src="img/haskell.png" align="right" />
<img src="img/vim.png" align="right" />

<h2 align="left">Haskell Vim IDE</h2>

<br />

### Installation

One command does it all:

```sh
curl -o - https://raw.githubusercontent.com/begriffs/haskell-vim-now/master/install.sh | sh
```

In less than **ten minutes** your Vim will transform into a beautiful
Haskell paradise.  (Don't worry, it backs up your original
configuration.) It also builds all necessary support binaries
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
* tab compelete
* unicode symbols
* highlight DSLs
* work with git

## Keybindings and commands

The commands are organized into logical groups to help you remember
them.

### Types, autocomplete, and linting

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
    <td>\\</td><td>Comment / Uncomment selection</td>
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
    <td>C-]</td><td>Jump to definition of symbol (codex + hasktags)</td>
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

### Misc

<table>
<tbody>
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
    <td>C-s</td><td>Toggle nerd tree, find file</td>
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
    <td>C-l</td><td>Move cursor to rightward pane</td>
  </tr>
</tbody>
</table>

## Customizing

After installing this configuration, your `.vimrc` and `.vim` will
be under version control. Don't alter them, add your own settings to
`~/.vimrc.local` instead and your additions will be loaded.
