" 进入终端时自动切换为插入模式
autocmd TermOpen * startinsert


" 插入模式下按 F5
inoremap <F5> <ESC>:call RunPK()<CR>

" 普通模式下按 F5
nnoremap <F5> :call RunPK()<CR>

function! RunPK()
    " 保存当前文件
    if &modified
        write
    endif
    
    " 检查是否已经有PK终端窗口，如果有则复用
    let win_count = 0
    let target_win = 0
    
    " 遍历所有窗口查找终端窗口
    for i in range(1, winnr('$'))
        let bufname = bufname(winbufnr(i))
        if bufname =~ 'term://.*//pk'
            let target_win = i
            break
        endif
    endfor
    
    if target_win > 0
        " 如果已存在终端窗口，切换到该窗口
        execute target_win . 'wincmd w'
        " 清空终端内容并重新运行pk
        call feedkeys("i\<C-u>pk -P\<CR>")
    else
        " 创建新的终端窗口
        execute 'belowright 10split term://pk -P'
        " 进入插入模式
        startinsert
    endif
endfunction

autocmd Filetype python nnoremap <F10> :w<CR>:!python3 %<CR>
autocmd Filetype python inoremap <F10> <ESC>:w<CR>:!python3 %<CR>

autocmd Filetype rust inoremap <F10> <ESC>:w<CR>:!cargo run<CR>
autocmd Filetype rust inoremap <F10> :w<CR>:!cargo run<CR>

" 确保终端支持真彩色（如果可用）
if has('termguicolors')
    set termguicolors
endif


" 编辑vimrc相关配置文件
nnoremap <leader>E :edit $MYVIMRC<cr>


" 重新加载vimrc文件
nnoremap <leader>s :source $MYVIMRC<cr>


set nocompatible         " 设置不兼容原始vi模式
filetype on              " 设置开启文件类型侦测
filetype plugin on       " 设置加载对应文件类型的插件
set noeb                 " 关闭错误的提示
syntax enable            " 开启语法高亮功能
syntax on                " 自动语法高亮
set t_Co=256             " 开启256色支持
set termguicolors
set cmdheight=1          " 设置命令行的高度
set showcmd              " select模式下显示选中的行数
set laststatus=2         " 总是显示状态栏
set number               " 开启行号显示
set whichwrap+=<,>,h,l   " 设置光标键跨行
set ttimeoutlen=0
set virtualedit=block,onemore   " 允许光标出现在最后一个字符的后面
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" 代码缩进和排版
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
set autoindent           " 设置自动缩进
set cindent              " 设置使用C/C++语言的自动缩进方式
set cinoptions=g0,:0,N-s,(0    " 设置C/C++语言的具体缩进方式
set smartindent          " 智能的选择对其方式
filetype indent on       " 自适应不同语言的智能缩进
set expandtab            " 将制表符扩展为空格
set tabstop=4            " 设置编辑时制表符占用空格数
set shiftwidth=4         " 设置格式化时制表符占用空格数
set softtabstop=4        " 设置4个空格为制表符
set smarttab             " 在行和段开始处使用制表符
set backspace=2          " 使用回车键正常处理indent,eol,start等
set sidescroll=10        " 设置向右滚动字符数
set nofoldenable
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" 代码补全
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
set wildmenu             " vim自身命名行模式智能补全
set completeopt-=preview " 补全时不显示窗口，只显示补全列表

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" 搜索设置
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
set hlsearch            " 高亮显示搜索结果
set incsearch           " 开启实时搜索功能
set ignorecase          " 搜索时大小写不敏感

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" 缓存设置
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
set noswapfile          " 禁止生成临时文件
set autoread            " 文件在vim之外修改过，自动重新读入
set autowrite           " 设置自动保存
set confirm             " 在处理未保存或只读文件的时候，弹出确认

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" 编码设置
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
set langmenu=zh_CN.UTF-8
set helplang=cn
set encoding=utf8
set fileencodings=utf8,ucs-bom,gbk,cp936,gb2312,gb18030

set number
augroup numbertoggle
    autocmd!
    autocmd BufEnter,FocusGained,InsertLeave,WinEnter * if &nu && mode() != "i" | set rnu   | endif
    autocmd BufLeave,FocusLost,InsertEnter,WinLeave   * if &nu                 | set nornu | endif
augroup END

noremap  <C-a> <Esc>gg0vG$
inoremap <C-a> <Esc>gg0vG$

" 保存文件：插入模式下保存后回到普通模式；普通/可视模式只保存
" 注意：LazyVim 也会映射 <C-s>，因为 kemil.vim 在 VeryLazy 之后再次 source，
" 所以这里的映射会覆盖 LazyVim 的版本（详见 init.lua）
nnoremap <C-s> <Cmd>write<CR>
inoremap <C-s> <Esc><Cmd>write<CR>
xnoremap <C-s> <Cmd>write<CR>
snoremap <C-s> <Cmd>write<CR>

nnoremap <C-z> u
vnoremap <C-z> <Esc>uv
inoremap <C-z> <C-o>u

nnoremap <C-y> <C-r>
vnoremap <C-y> <Esc> <C-r>v
inoremap <C-y> <C-o> <C-r>

noremap <C-x> :q<CR>
inoremap <C-x> <Esc>:q<CR>

inoremap <C-v> <C-o>"+gP
vnoremap <C-v> "+gP

vnoremap <C-c> "+y<Esc>

vnoremap <C-x> "+x
vnoremap <S-Enter> :<C-u>:'<,'>g/^$/d<CR>

xmap <Tab> >gv
xmap <S-Tab> <gv


inoremap <leader>p <C-o>p
inoremap <leader>yy <C-o>yy
inoremap <leader>dd <C-o>dd
inoremap <leader>o <C-o>o
inoremap <leader>O <C-o>O
inoremap <leader>zz <C-o>zz
inoremap <S-End> <C-o>v$
inoremap <S-Home> <C-o>v0
inoremap <S-Up> <C-o>Vk
inoremap <S-Down> <C-o>Vj
inoremap <leader>w <C-o>W
inoremap <leader>e <C-o>e
inoremap <leader>b <C-o>b




nnoremap <S-End> <C-o>v$
nnoremap <S-Home> <C-o>v0
nnoremap <S-Up> <C-o>Vk
nnoremap <S-Down> <C-o>Vj
nnoremap <leader>o o<ESC>
nnoremap <leader>O O<ESC>

set mouse=a

" 分屏窗口移动
nnoremap <C-Down> <c-w>j
nnoremap <C-Up> <c-w>k
nnoremap <C-Left> <c-w>h
nnoremap <C-Right> <c-w>l

inoremap <Leader>Down <c-w>j
inoremap <Leader>Up <c-w>k
inoremap <Leader>Left <c-w>h
inoremap <Leader>Right <c-w>l

" 窗口大小改变
nnoremap <A-Left> :vertical resize -5<CR>
nnoremap <A-Right> :vertical resize +5<CR>
nnoremap <A-Up> :resize +5<CR>
nnoremap <A-Down> :resize -5<CR>

inoremap <Leader>Left :vertical resize -5<CR>
inoremap <Leader>Right :vertical resize +5<CR>
inoremap <Leader>Up :resize +5<CR>
inoremap <Leader>Down :resize -5<CR>

nnoremap <ESC>u :nohlsearch<CR>
inoremap <ESC>u <ESC>:nohlsearch<CR>a

" 不要用 syntax：C/C++/Qt 文件用语法折叠会在打开文件和编辑时大量消耗 CPU。
" LazyVim 默认用 indent，C/C++ 有 treesitter 时会自动切到 treesitter 折叠。
set foldmethod=indent

function! ToggleAllFold()
    if &foldmethod != 'marker'
        " 设置基于{}标记的折叠
        setlocal foldmethod=marker
        setlocal foldmarker={,}
        " 创建所有折叠
        normal! zM
    else
        " 如果已经启用折叠，则切换展开/折叠
        if foldclosed('.') == -1
            " 当前在展开状态，折叠所有
            normal! zM
        else
            " 当前在折叠状态，展开所有
            normal! zR
        endif
    endif
endfunction

nnoremap <A-f> :call ToggleAllFold()<CR>

function! ToggleFold()
    " 如果当前行在闭合的折叠中，则打开它
    if foldclosed('.') != -1
        normal! zo
    " 否则，切换当前折叠（打开则关闭，关闭则打开）
    else
        normal! za
    endif
endfunction

nnoremap <silent> <C-f> :call ToggleFold()<CR>

inoremap <A-z> <C-o>zz


" 打开文件自动定位到最后编辑的位置
autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | execute "normal! g'\"" | endif

" 对于 Neovim 或支持浮动窗口的 Vim
if has('nvim') || has('popupwin')
    let g:echodoc#type = 'floating'
    let g:echodoc#floating_max_width = 0.6  " 最大宽度为窗口的60%
endif


