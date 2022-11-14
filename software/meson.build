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

inc = include_directories('include')

subdir('include')
subdir('src')

norman_lib = library('norman', project_sources, install: true,
                     include_directories: inc)

subdir('examples')
