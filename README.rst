################################################################################
                                   VIM-SHOUT
################################################################################

Run and Capture Shell Command Output
####################################

.. note::

  Should work with Vim9 (compiled with ``HUGE`` features).


I always wanted a simpler way to run an arbitrary shell command with the output
being captured into some throwaway buffer. Mostly for the simple scripting
(press a button, script is executed and the output is immediately visible).

I have used (and still use) relevant builtin commands (``:make``, ``:!cmd``,
``:r !cmd`` and all the jazz with quickfix/location-list windows) but ... I
didn't feel it worked my way.

This works my way though.

.. image:: https://asciinema.org/a/DaVumBuy1qtyXoIsNveok70dF.svg
  :target: https://asciinema.org/a/DaVumBuy1qtyXoIsNveok70dF


Mappings
========

In a ``[shout]`` buffer:

:kbd:`Enter`
  - While on line 1, re-execute the command.
  - Switch (open) to the file under cursor.

:kbd:`Space` + :kbd:`Enter`
  Open file under cursor in a new tabpage.

:kbd:`CTRL-C`
  Kill the shell command.

:kbd:`]]`
  Goto next error.

:kbd:`[[`
  Goto previous error.

:kbd:`[{`
  Goto first error.

:kbd:`]}`
  Goto last error.


Commands
========

``:Sh {command}``
  Start ``{command}`` in background, open existing ``[shout]`` buffer or create
  a new one and print output of ``stdout`` and ``stderr`` there.
  Put cursor to the end of buffer.

  .. code::

    :Sh ls -lah
    :Sh make
    :Sh python

``:Sh! {command}``
  Same as ``Sh`` but keep cursor on line 1.

  .. code::

    :Sh! rg -nS --column "\b(TODO|FIXME|XXX):" .

``:Shut``
  Close shout window.


Examples of User Commands
=========================

``:Rg searchpattern``, search using ripgrep::

  command! -nargs=1 Rg Sh! rg -nS --column "<args>" .

``:Todo``, search for all TODOs, FIXMEs and XXXs using ripgrep::

  command! Todo Sh! rg -nS --column "\b(TODO|FIXME|XXX):" .


Examples of User Mappings
=========================

Search word under cursor::

  nnoremap <space>8 <scriptcmd>exe "Rg" expand("<cword>")<cr>

Run python script (put into ``~/.vim/after/ftplugin/python.vim``)::

  nnoremap <buffer> <F5> <scriptcmd>exe "Sh python" expand("%:p")<cr>

Build and run rust project (put into ``~/.vim/after/ftplugin/rust.vim``)::

  nnoremap <buffer> <F5> <scriptcmd>Sh cargo run<cr>
  nnoremap <buffer> <F6> <scriptcmd>Sh cargo build<cr>
  nnoremap <buffer> <F7> <scriptcmd>Sh cargo build --release<cr>


Build and run a single c-file without ``Makefile`` or project with ``Makefile``
(put into ``~/.vim/after/ftplugin/c.vim``)::

  vim9script

  def Make()
      if filereadable("Makefile")
          Sh make
      else
          var fname = expand("%:p:r")
          exe $"Sh make {fname} && chmod +x {fname} && {fname}"
      endif
  enddef

  nnoremap <buffer><F5> <scriptcmd>Make()<cr>


.. image:: https://asciinema.org/a/566982.svg
  :target: https://asciinema.org/a/566982


Options, Variables
==================

``g:shout_print_exit_code``
  Add empty line followed by "Exit code: X" line to the end of ``[shout]`` buffer if set to ``true``:
  Default is ``true``.

``b:shout_exit_code``
  Buffer local varibale. Contains exit code of the latest executed command.
  Could be useful in custom statuslines.

``b:shout_cmd``
  Buffer local variable. Contains latest executed command.
  Could be useful in custom statuslines.
