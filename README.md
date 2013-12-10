<img src="img/haskell.png" align="left" />
<img src="img/vim.png" align="left" />

<h2 align="right">Edit Haskell right now!</h2>

<br />

Fine, run this command and your Vim will be fully configured to do
magical Haskell things.

```sh
curl -o - https://raw.github.com/begriffs/haskell-vim-now/master/install.sh | sh
```

Running this command will back up your existing Vim configuration and
replace it with settings fully tuned to edit and evaluate Haskell. Sure,
you could assemble it yourself from various plugins, but why bother?

## Keybindings and commands

The commands are organized into logical groups to help you remember
them.

### Types, autocomplete, and linting

<table>
<tbody>
  <tr>
    <td>,ht</td><td>Show type of expression under cursor</td>
  </tr>
  <tr>
    <td>,hl</td><td>Run Haskell linter on file</td>
  </tr>
  <tr>
    <td>,hc</td><td>Run Haskell compile check on file</td>
  </tr>
  <tr>
    <td>,<enter></td><td>Clear type selection</td>
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

### Conversion

<table>
<tbody>
  <tr>
    <td>,2s</td><td>Convert symbol under cursor from symbol to string</td>
  </tr>
  <tr>
    <td>,2y</td><td>Convert string under cursor from string to symbol</td>
  </tr>
  <tr>
    <td>,2_</td><td>Convert string under cursor to snake_case</td>
  </tr>
  <tr>
    <td>,2c</td><td>Convert string under cursor to camelCase</td>
  </tr>
  <tr>
    <td>,2m</td><td>Convert string under cursor to MixedCase</td>
  </tr>
  <tr>
    <td>,2u</td><td>Convert string under cursor to SNAKE_UPPERCASE</td>
  </tr>
  <tr>
    <td>,2-</td><td>Convert string under cursor to dash-case</td>
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
    <td>,ff</td><td>Toggle MacVim fullscreen mode</td>
  </tr>
</tbody>
</table>

## Upgrading

```sh
cd ~/.haskell-vim-now
git pull
vim -u .vimrc +BundleUpdate +qall
```

## Customizing

After installing this configuration, your `.vimrc` and `.vim` will
be under version control. Don't alter them, add your own settings to
`~/.vimrc.local` instead and your additions will be loaded.
