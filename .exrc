set mp=build.bat
nnoremap <leader>b :Make build<cr>
nnoremap <leader>r :Make run<cr>
tnoremap <leader>w <C-\><C-n><C-w>

" odin efm
set efm+=,%f(%l:%c)\ %m
set efm+=,%f(%l:%c)\ %t%.%#:\ %m
set efm+=,%f:%c(%l)\ %m
set efm+=,%f:%c:%l:\ %m
