" claude_complete.vim
" File (@) and slash-command (/) completion for Claude Code temp editor.
" Only activates when the CLAUDE_EDITOR=1 environment variable is set,
" which is injected by the vim-claude wrapper script.

if exists('g:loaded_claude_complete')
  finish
endif
if !exists('$CLAUDE_EDITOR') || $CLAUDE_EDITOR !=# '1'
  finish
endif
let g:loaded_claude_complete = 1

" ============================================================
" Helpers
" ============================================================

" Fuzzy match: every char of needle must appear in order in haystack
function! s:FuzzyMatch(haystack, needle)
  if empty(a:needle) | return 1 | endif
  let h = tolower(a:haystack)
  let n = tolower(a:needle)
  let hi = 0
  for char in split(n, '\zs')
    let found = stridx(h, char, hi)
    if found < 0 | return 0 | endif
    let hi = found + 1
  endfor
  return 1
endfunction

" Score for sorting: 0 = filename prefix match, 1 = path contains needle, 2 = fuzzy
function! s:FuzzyScore(path, needle)
  if empty(a:needle) | return 2 | endif
  let name = tolower(fnamemodify(a:path, ':t'))
  let n    = tolower(a:needle)
  if stridx(name, n) == 0                        | return 0 | endif
  if stridx(tolower(a:path), n) >= 0             | return 1 | endif
  return 2
endfunction

" ============================================================
" @ File completion – recursive fuzzy search
" ============================================================

let s:file_cache      = []
let s:file_cache_time = 0
let s:exclude_dirs    = ['node_modules', '.git', '__pycache__', 'dist', 'build',
                        \ '.next', 'target', 'vendor', '.cache', '.DS_Store']

function! s:GetFiles()
  " Cache for 30 s to avoid hammering the filesystem on every keystroke
  if !empty(s:file_cache) && localtime() - s:file_cache_time < 30
    return copy(s:file_cache)
  endif
  let all    = globpath('.', '**/*', 0, 1)
  let result = []
  for f in all
    if isdirectory(f) | continue | endif
    let skip = 0
    for ex in s:exclude_dirs
      if f =~# '\/' . ex . '\/' || f =~# '\/' . ex . '$'
        let skip = 1 | break
      endif
    endfor
    if !skip | call add(result, f) | endif
  endfor
  let s:file_cache      = result
  let s:file_cache_time = localtime()
  return copy(result)
endfunction

function! ClaudeFileComplete(findstart, base)
  if a:findstart
    let line  = getline('.')
    let start = col('.') - 1
    " Walk backwards past non-space, non-@ chars to find the word start
    while start > 0 && line[start - 1] !~ '[\t @]'
      let start -= 1
    endwhile
    return (start > 0 && line[start - 1] ==# '@') ? start : -1
  endif

  let files = s:GetFiles()
  " Fuzzy filter across full relative path
  if !empty(a:base)
    let files = filter(files, {_, v -> s:FuzzyMatch(v, a:base)})
  endif
  " Sort: exact filename-prefix first, then substring, then pure fuzzy
  call sort(files, {a, b ->
    \ s:FuzzyScore(a, a:base) - s:FuzzyScore(b, a:base)})
  " Cap at 50 entries for menu responsiveness
  return map(files[:49], {_, v -> {
    \ 'word': substitute(v, '^\./', '', ''),
    \ 'abbr': fnamemodify(v, ':t'),
    \ 'menu': fnamemodify(substitute(v, '^\./', '', ''), ':h'),
    \ }})
endfunction

" ============================================================
" / Slash-command & skill completion
" Mirrors the behaviour of Claude Code CLI's / command palette
" ============================================================

function! s:BuiltinCommands()
  return [
    \ {'word': '/help',        'menu': 'Show help and available commands'},
    \ {'word': '/clear',       'menu': 'Clear conversation history'},
    \ {'word': '/compact',     'menu': 'Compact conversation to save context'},
    \ {'word': '/config',      'menu': 'Open configuration settings'},
    \ {'word': '/cost',        'menu': 'Show token usage and cost'},
    \ {'word': '/exit',        'menu': 'Exit Claude Code'},
    \ {'word': '/quit',        'menu': 'Exit Claude Code'},
    \ {'word': '/memory',      'menu': 'View and edit memory files'},
    \ {'word': '/model',       'menu': 'Switch the AI model'},
    \ {'word': '/permissions', 'menu': 'View and manage tool permissions'},
    \ {'word': '/resume',      'menu': 'Resume a previous conversation'},
    \ {'word': '/review',      'menu': 'Review a pull request'},
    \ {'word': '/status',      'menu': 'Show account and system status'},
    \ {'word': '/init',        'menu': 'Initialize project CLAUDE.md'},
    \ {'word': '/doctor',      'menu': 'Check installation health'},
    \ {'word': '/commit',      'menu': '[skill] Create git commit'},
    \ {'word': '/simplify',    'menu': '[skill] Review and simplify code'},
    \ {'word': '/statusline',  'menu': '[skill] Configure statusline'},
    \ ]
endfunction

function! s:DiscoverInstalledSkills(builtins)
  let result        = []
  let builtin_words = map(copy(a:builtins), {_, v -> v.word})
  let seen          = {}

  " ~/.claude/skills/<skill-name>/   – each skill is a subdirectory
  let skills_dir = expand('~/.claude/skills')
  if isdirectory(skills_dir)
    for entry in glob(skills_dir . '/*', 0, 1)
      if !isdirectory(entry) | continue | endif
      " skill name is the dirname; strip any :namespace prefix for the abbr
      let raw  = fnamemodify(entry, ':t')          " e.g. "somto-dev-toolkit:commit"
      let name = '/' . split(raw, ':')[-1]         " e.g. "/commit"
      let full = '/' . raw                         " e.g. "/somto-dev-toolkit:commit"
      if has_key(seen, full) | continue | endif
      let seen[full] = 1
      if index(builtin_words, name) >= 0 | continue | endif
      call add(result, {'word': full, 'abbr': name, 'menu': '[skill]'})
    endfor
  endif

  return result
endfunction

let s:slash_commands      = []
let s:slash_commands_time = 0

function! s:GetSlashCommands()
  " Re-discover skills every 60 s in case new ones were installed
  if empty(s:slash_commands) || localtime() - s:slash_commands_time > 60
    let builtins          = s:BuiltinCommands()
    let s:slash_commands  = builtins + s:DiscoverInstalledSkills(builtins)
    let s:slash_commands_time = localtime()
  endif
  return s:slash_commands
endfunction

function! ClaudeSlashComplete(findstart, base)
  if a:findstart
    let line  = getline('.')
    let start = col('.') - 1
    " Walk back to the / that opens this command token
    while start > 0 && line[start - 1] !~ '[\t ]'
      let start -= 1
    endwhile
    " Return position only if the token starts with /
    return (line[start] ==# '/') ? start : -1
  endif

  let all = s:GetSlashCommands()
  " Empty or bare "/" -> show everything
  if empty(a:base) || a:base ==# '/'
    return all
  endif
  return filter(copy(all), {_, v -> s:FuzzyMatch(v.word, a:base)})
endfunction

" Decide what to do when the user presses /:
" - At start of line OR after whitespace -> slash-command palette
" - Anywhere else (path separator, regex, ...) -> literal /
function! s:TriggerSlash()
  let line = getline('.')
  let col  = col('.') - 1   " 0-indexed position before the about-to-be-typed /
  if col == 0 || line[col - 1] =~ '\s'
    setlocal completefunc=ClaudeSlashComplete
    return "/\<C-x>\<C-u>"
  endif
  return '/'
endfunction

" After a slash-command completion finishes, restore file completefunc
augroup ClaudeCompleteRestore
  autocmd!
  autocmd CompleteDone * if &l:completefunc ==# 'ClaudeSlashComplete'
                        \|   setlocal completefunc=ClaudeFileComplete
                        \| endif
augroup END

" ============================================================
" Mappings & options  (buffer-local so they don't leak)
" ============================================================

inoremap          @     @<C-x><C-u>
inoremap <expr>   /     <SID>TriggerSlash()

" Tab: accept selected completion item (or insert literal Tab if menu not visible)
inoremap <expr> <Tab>   pumvisible() ? "\<C-y>" : "\<Tab>"

setlocal completefunc=ClaudeFileComplete
setlocal completeopt=menuone,noselect,noinsert
