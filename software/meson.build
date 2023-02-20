project('norman_app', 'c', 'cpp', meson_version: '>=0.58.0',
        default_options: [
            'prefix=/usr/local',
            'cpp_std=c++17',
            'debug=true',
            'optimization=3',
            'warning_level=3',
            'werror=true',
            'default_library=static',
            'cpp_eh=none',  # No exceptions.
            'b_ndebug=true',  # Disable asserts.
            'b_lto=true',  # Link-time optimization.
            'cpp_rtti=false',  # No RTTI.
        ])

add_global_arguments('-march=native', language: ['c', 'cpp'])

notification_buf_size = get_option('notification_buf_size')
enso_pipe_size = get_option('enso_pipe_size')
batch_size = get_option('batch_size')
latency_opt = get_option('latency_opt')

add_global_arguments(f'-D NOTIFICATION_BUF_SIZE=@notification_buf_size@',
                     language: ['c', 'cpp'])
add_global_arguments(f'-D ENSO_PIPE_SIZE=@enso_pipe_size@',
                     language: ['c', 'cpp'])
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
