vim9script

const W_THRESHOLD = 160

var shout_job: job

def Vertical(): string
    var result = ""
    # if the overall vim width is too narrow or
    # there are >=2 vertical windows, split below
    if &columns >= W_THRESHOLD && winlayout()[0] != 'row'
        result ..= "vertical"
    endif
    return result
enddef

def FindOtherWin(): number
    var result = -1
    var winid = win_getid()
    for wnd in range(1, winnr('$'))
        if win_getid(wnd) != winid
            result = win_getid(wnd)
            break
        endif
    endfor
    return result
enddef

def ShoutWinId(): number
    var buffers = getbufinfo()->filter((_, v) => fnamemodify(v.name, ":t") =~ '^\[shout\]$')
    for shbuf in buffers
        if len(shbuf.windows) > 0
            return shbuf.windows[0]
        endif
    endfor
    return -1
enddef

def PrepareBuffer(shell_cwd: string): number
    var bufname = '[shout]'
    var buffers = getbufinfo()->filter((_, v) => fnamemodify(v.name, ":t") == bufname)

    var bufnr = -1

    if len(buffers) > 0
        bufnr = buffers[0].bufnr
    else
        bufnr = bufadd(bufname)
    endif

    var windows = win_findbuf(bufnr)
    var initial_winid = win_getid()

    if windows->len() == 0
        exe "botright" Vertical() "sbuffer" bufnr
        b:shout_initial_winid = initial_winid
        setl filetype=shout
    else
        win_gotoid(windows[0])
    endif

    silent :%d _

    b:shout_cwd = shell_cwd
    exe "silent lcd" shell_cwd

    setl undolevels=-1

    return bufnr
enddef

export def CaptureOutput(command: string, follow: bool = false)
    var cwd = getcwd()
    var bufnr = PrepareBuffer(cwd->substitute('#', '\\&', 'g'))

    setbufvar(bufnr, "shout_exit_code", "")

    setbufline(bufnr, 1, $"$ {command}")
    setbufline(bufnr, 2, "")

    if shout_job->job_status() == "run"
        shout_job->job_stop()
    endif

    var job_command: any
    if has("win32")
        job_command = command
    else
        job_command = [&shell, &shellcmdflag, escape(command, '\')]
    endif

    shout_job = job_start(job_command, {
        cwd: cwd,
        out_io: 'buffer',
        out_buf: bufnr,
        out_msg: 0,
        err_io: 'out',
        err_buf: bufnr,
        err_msg: 0,
        close_cb: (channel) => {
            if !bufexists(bufnr)
                return
            endif
            var winid = bufwinid(bufnr)
            var exit_code = job_info(shout_job).exitval
            if get(g:, "shout_print_exit_code", true)
                var msg = [""]
                msg += ["Exit code: " .. exit_code]
                appendbufline(bufnr, line('$', winid), msg)
            endif
            if follow
                win_execute(winid, "normal! G")
            endif
            setbufvar(bufnr, "shout_exit_code", $"{exit_code}")
            win_execute(winid, "setl undolevels&")
        }
    })

    b:shout_cmd = command

    if follow
        normal! G
    endif
enddef

export def OpenFile()
    var shout_cwd = get(b:, "shout_cwd", "")
    if !empty(shout_cwd)
        exe "silent lcd" b:shout_cwd
    endif

    # re-run the command if on line 1
    if line('.') == 1
        var cmd = getline(".")->matchstr('^\$ \zs.*$')
        if cmd !~ '^\s*$'
            var pos = getcurpos()
            CaptureOutput(cmd, false)
            setpos('.', pos)
        endif
        return
    endif

    # Windows has : in `isfname` thus for ./filename:20:10: gf can't find filename cause
    # it sees filename:20:10: instead of just filename
    # So the "hack" would be:
    # - take <cWORD> or a line under cursor
    # - extract file name, line, column
    # - edit file name

    # python
    var fname = getline('.')->matchlist('^\s\+File "\(.\{-}\)", line \(\d\+\)')

    # erlang escript
    if empty(fname)
        fname = getline('.')->matchlist('^\s\+in function\s\+.\{-}(\(.\{-}\), line \(\d\+\))')
    endif

    # rust
    if empty(fname)
        fname = getline('.')->matchlist('^\s\+--> \(.\{-}\):\(\d\+\):\(\d\+\)')
    endif

    # regular filename:linenr:colnr:
    if empty(fname)
        fname = getline('.')->matchlist('^\(.\{-}\):\(\d\+\):\(\d\+\).*')
    endif

    # regular filename:linenr:
    if empty(fname)
        fname = getline('.')->matchlist('^\(.\{-}\):\(\d\+\):\?.*')
    endif

    # regular filename:
    if empty(fname)
        fname = getline('.')->matchlist('^\(.\{-}\):.*')
    endif

    if fname->len() > 0 && filereadable(fname[1])
        try
            var should_split = false
            var buffers = getbufinfo()->filter((_, v) => v.name == fnamemodify(fname[1], ":p"))
            fname[1] = fname[1]->substitute('#', '\\&', 'g')
            # goto opened file if it is visible
            if len(buffers) > 0 && len(buffers[0].windows) > 0
                win_gotoid(buffers[0].windows[0])
            # goto first non shout window otherwise
            elseif win_gotoid(FindOtherWin())
                if !&hidden && &modified
                    should_split = true
                endif
            else
                should_split = true
            endif

            exe $"lcd {shout_cwd}"

            if should_split
                exe Vertical() "split" fname[1]
            else
                exe "edit" fname[1]
            endif

            if !empty(fname[2])
                exe $":{fname[2]}"
                exe "normal! 0"
            endif

            if !empty(fname[3]) && fname[3]->str2nr() > 1
                exe $"normal! {fname[3]->str2nr() - 1}l"
            endif
            normal! zz
        catch
        endtry
    endif
enddef

export def Kill()
    if shout_job != null
        job_stop(shout_job)
    endif
enddef

export def CloseWindow()
    var winid = ShoutWinId()
    if winid == -1
        return
    endif
    var winnr = getwininfo(winid)[0].winnr
    exe $":{winnr}close"
enddef

export def NextError()
    # Search for python error
    var rxError = '^.\{-}:\d\+\(:\d\+:\?\)\?'
    var rxPyError = '^\s*File ".\{-}", line \d\+,'
    var rxErlEscriptError = '^\s\+in function\s\+.\{-}(.\{-}, line \d\+)'
    search($'\({rxError}\)\|\({rxPyError}\)\|\({rxErlEscriptError}\)', 'W')
enddef

export def FirstError()
    :2
    NextError()
enddef

export def PrevError(accept_at_curpos: bool = false)
    var rxError = '^.\{-}:\d\+\(:\d\+:\?\)\?'
    var rxPyError = '^\s*File ".\{-}", line \d\+,'
    var rxErlEscriptError = '^\s\+in function\s\+.\{-}(.\{-}, line \d\+)'
    search($'\({rxError}\)\|\({rxPyError}\)\|\({rxErlEscriptError}\)', 'bW')
enddef

export def LastError()
    :$
    if getline('$') =~ "^Exit code: .*$"
        PrevError()
    else
        PrevError(true)
    endif
enddef

export def NextErrorJump()
    if win_gotoid(ShoutWinId())
       :exe "normal ]]\<CR>"
    endif
enddef

export def FirstErrorJump()
    if win_gotoid(ShoutWinId())
       :exe "normal [{\<CR>"
    endif
enddef

export def PrevErrorJump()
    if win_gotoid(ShoutWinId())
       :exe "normal [[\<CR>"
    endif
enddef

export def LastErrorJump()
    if win_gotoid(ShoutWinId())
       :exe "normal ]}\<CR>"
    endif
enddef
