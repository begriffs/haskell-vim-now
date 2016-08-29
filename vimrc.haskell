" HVN paths {{{
" stack bin path symlink
let hvn_stack_bin = expand(resolve(hvn_config_dir . "/.stack-bin"))
" Find custom built hasktags, codex etc
let $PATH = expand(hvn_stack_bin) . ':' . $PATH

" }}}

" Conceal {{{
" Use same color behind concealed unicode characters
hi clear Conceal

" Pretty unicode haskell symbols
let g:haskell_conceal_wide = 1
let g:haskell_conceal_enumerations = 1
let hscoptions="𝐒𝐓𝐄𝐌xRtB𝔻w"

" }}}

" Tags {{{

set tags+=codex.tags;/

let g:tagbar_type_haskell = {
    \ 'ctagsbin'  : 'hasktags',
    \ 'ctagsargs' : '-x -c -o-',
    \ 'kinds'     : [
        \  'm:modules:0:1',
        \  'd:data: 0:1',
        \  'd_gadt: data gadt:0:1',
        \  't:type names:0:1',
        \  'nt:new types:0:1',
        \  'c:classes:0:1',
        \  'cons:constructors:1:1',
        \  'c_gadt:constructor gadt:1:1',
        \  'c_a:constructor accessors:1:1',
        \  'ft:function types:1:1',
        \  'fi:function implementations:0:1',
        \  'o:others:0:1'
    \ ],
    \ 'sro'        : '.',
    \ 'kind2scope' : {
        \ 'm' : 'module',
        \ 'c' : 'class',
        \ 'd' : 'data',
        \ 't' : 'type'
    \ },
    \ 'scope2kind' : {
        \ 'module' : 'm',
        \ 'class'  : 'c',
        \ 'data'   : 'd',
        \ 'type'   : 't'
    \ }
\ }

" Generate haskell tags with codex and hscope
map <leader>tg :!codex update --force<CR>:call system("git-hscope -X TemplateHaskell")<CR><CR>:call LoadHscope()<CR>

set csprg=hscope
set csto=1 " search codex tags first

nnoremap <silent> <C-\> :cs find c <C-R>=expand("<cword>")<CR><CR>
" Automatically make cscope connections
function! LoadHscope()
  let db = findfile("hscope.out", ".;")
  if (!empty(db))
    let path = strpart(db, 0, match(db, "/hscope.out$"))
    set nocscopeverbose " suppress 'duplicate connection' error
    exe "cs add " . db . " " . path
    set cscopeverbose
  endif
endfunction
au BufEnter /*.hs call LoadHscope()

" }}}

" Hoogle {{{
" Hoogle the word under the cursor
nnoremap <silent> <leader>hh :Hoogle<CR>

" Hoogle and prompt for input
nnoremap <leader>hH :Hoogle 

" Hoogle for detailed documentation (e.g. "Functor")
nnoremap <silent> <leader>hi :HoogleInfo<CR>

" Hoogle for detailed documentation and prompt for input
nnoremap <leader>hI :HoogleInfo 

" Hoogle, close the Hoogle window
nnoremap <silent> <leader>hz :HoogleClose<CR>

" }}}

" Formatting {{{
" Use hindent instead of par for haskell buffers
autocmd FileType haskell let &formatprg="hindent --tab-size 2 -XQuasiQuotes"

" Enable some tabular presets for Haskell
let g:haskell_tabular = 1

" Delete trailing white space on save
augroup whitespace
  autocmd!
  autocmd BufWrite *.hs :call DeleteTrailingWS()
augroup END

" }}}

"Completion, Syntax check, Lint & Refactor {{{

augroup haskell
  autocmd!
  autocmd FileType haskell map <silent> <leader><cr> :noh<cr>:GhcModTypeClear<cr>
  autocmd FileType haskell setlocal omnifunc=necoghc#omnifunc
augroup END

" Provide (neco-ghc) omnicompletion
if has("gui_running")
  imap <c-space> <c-r>=SuperTabAlternateCompletion("\<lt>c-x>\<lt>c-o>")<cr>
else " no gui
  if has("unix")
    inoremap <Nul> <c-r>=SuperTabAlternateCompletion("\<lt>c-x>\<lt>c-o>")<cr>
  endif
endif

" Disable hlint-refactor-vim's default keybindings
let g:hlintRefactor#disableDefaultKeybindings = 1

" hlint-refactor-vim keybindings
map <silent> <leader>hr :call ApplyOneSuggestion()<CR>
map <silent> <leader>hR :call ApplyAllSuggestions()<CR>

" Show types in completion suggestions
let g:necoghc_enable_detailed_browse = 1
" Resolve ghcmod base directory
au FileType haskell let g:ghcmod_use_basedir = getcwd()

" Type of expression under cursor
nmap <silent> <leader>ht :GhcModType<CR>
" Insert type of expression under cursor
nmap <silent> <leader>hT :GhcModTypeInsert<CR>
" GHC errors and warnings
nmap <silent> <leader>hc :Neomake ghcmod<CR>

" open the neomake error window automatically when an error is found
let g:neomake_open_list = 2

" Fix path issues from vim.wikia.com/wiki/Set_working_directory_to_the_current_file
let s:default_path = escape(&path, '\ ') " store default value of 'path'
" Always add the current file's directory to the path and tags list if not
" already there. Add it to the beginning to speed up searches.
autocmd BufRead *
      \ let s:tempPath=escape(escape(expand("%:p:h"), ' '), '\ ') |
      \ exec "set path-=".s:tempPath |
      \ exec "set path-=".s:default_path |
      \ exec "set path^=".s:tempPath |
      \ exec "set path^=".s:default_path

" Haskell Lint
nmap <silent> <leader>hl :Neomake hlint<CR>

" Options for Haskell Syntax Check
let g:neomake_haskell_ghc_mod_args = '-g-Wall'

" }}}

" Point Conversion {{{

function! Pointfree()
  call setline('.', split(system('pointfree '.shellescape(join(getline(a:firstline, a:lastline), "\n"))), "\n"))
endfunction
vnoremap <silent> <leader>h. :call Pointfree()<CR>

function! Pointful()
  call setline('.', split(system('pointful '.shellescape(join(getline(a:firstline, a:lastline), "\n"))), "\n"))
endfunction
vnoremap <silent> <leader>h> :call Pointful()<CR>

" }}}
