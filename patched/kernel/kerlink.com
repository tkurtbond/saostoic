$ link/map=rkernel.map/notrace rkernel/options	! link the kernel
$ copy rkernel.exe head0.exe			! copy to the header prototype
