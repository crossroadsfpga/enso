# Things

- [ ] kern perform desc read (see below)
- [ ] kern wake up thr (re-enable)
- [ ] setup for epoll (re-enable)
- [ ] app advance head ptr (re-enable)


## Sequence
- [ ] allocate kernel hugepages buffer
- [ ] mmap buffer into userspace
- [x] user does stuff with fpga, populates pci block
- [x] kernel finds pci block
- [x] kernel reads pci block to deduce head/tail offsets
