
thread_dep = dependency('threads')
pcap_dep = dependency('pcap', version : '>=1.0')

executable('app', 'app.cpp', dependencies: thread_dep, link_with: norman_lib,
           include_directories: inc)
executable('app_event', 'app_event.cpp', dependencies: thread_dep,
           link_with: norman_lib, include_directories: inc)
executable('app_copy', 'app_copy.cpp', dependencies: thread_dep,
           link_with: norman_lib, include_directories: inc)
executable('pktgen', 'pktgen.cpp', dependencies: [thread_dep, pcap_dep],
           link_with: norman_lib, include_directories: inc)
executable('capture', 'capture.cpp', dependencies: [thread_dep, pcap_dep],
           link_with: norman_lib, include_directories: inc)
