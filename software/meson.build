project('norman_app', 'c', 'cpp', meson_version: '>=0.58.0',
        default_options: [
            'prefix=/usr/local',
            'cpp_std=c++11',
            'debug=true',
            'optimization=3',
            'warning_level=3',
            'werror=true',
            'default_library=static'
        ])

add_global_arguments('-march=native', language: ['c', 'cpp'])

dsc_buf_size = get_option('dsc_buf_size')
pkt_buf_size = get_option('pkt_buf_size')
batch_size = get_option('batch_size')
latency_opt = get_option('latency_opt')

add_global_arguments(f'-D DSC_BUF_SIZE=@dsc_buf_size@', language: ['c', 'cpp'])
add_global_arguments(f'-D PKT_BUF_SIZE=@pkt_buf_size@', language: ['c', 'cpp'])
add_global_arguments(f'-D BATCH_SIZE=@batch_size@', language: ['c', 'cpp'])

if latency_opt
    add_global_arguments('-D LATENCY_OPT', language: ['c', 'cpp'])
endif

subdir('norman')
inc = include_directories('norman')

thread_dep = dependency('threads')
pcap_dep = dependency('pcap', version : '>=1.0')

executable('app', 'app.cpp', dependencies: thread_dep, link_with: norman_lib,
           include_directories: inc)
executable('app_event', 'app_event.cpp', dependencies: thread_dep,
           link_with: norman_lib)
executable('pktgen', 'pktgen.cpp', dependencies: [thread_dep, pcap_dep],
           link_with: norman_lib)
executable('capture', 'capture.cpp', dependencies: [thread_dep, pcap_dep],
           link_with: norman_lib)
