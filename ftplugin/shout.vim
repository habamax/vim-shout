vim9script

if exists("b:did_ftplugin")
    finish
endif

b:did_ftplugin = 1

b:undo_ftplugin = 'exe "nunmap <buffer> <cr>"'
b:undo_ftplugin ..= '| exe "nunmap <buffer> <C-c>"'
b:undo_ftplugin ..= '| exe "nunmap <buffer> ]]"'
b:undo_ftplugin ..= '| exe "nunmap <buffer> [["'
b:undo_ftplugin ..= '| exe "nunmap <buffer> ]}"'
b:undo_ftplugin ..= '| exe "nunmap <buffer> [{"'
b:undo_ftplugin ..= '| exe "nunmap <buffer> gq"'

import autoload 'shout.vim'

nnoremap <buffer> <cr> <scriptcmd>shout.OpenFile()<cr>
nnoremap <buffer> <C-c> <scriptcmd>shout.Kill()<cr><C-c>
nnoremap <buffer> ]] <scriptcmd>shout.NextError()<cr>
nnoremap <buffer> [[ <scriptcmd>shout.PrevError()<cr>
nnoremap <buffer> [{ <scriptcmd>shout.FirstError()<cr>
nnoremap <buffer> ]} <scriptcmd>shout.LastError()<cr>
nnoremap <buffer> gq <C-w>c
