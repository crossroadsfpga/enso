project('enso', 'c', 'cpp', version: '0.2.0', license: 'BSD-3-Clause',
        meson_version: '>=0.58.0',
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

subdir('software')
subdir('docs')

teroshdl_hdl_documenter = find_program('teroshdl-hdl-documenter',
                                       required: false)

hardware_path = join_paths(meson.project_source_root(), 'hardware/src')
hdl_doc_path = join_paths(meson.project_source_root(), 'docs/hardware/modules')

if teroshdl_hdl_documenter.found()
    teroshdl_target = custom_target('teroshdl',
            input: [doxyfile],
            output: 'doc_internal',
            command: [
                teroshdl_hdl_documenter,
                # '--recursive',
                '--dep',
                '--fsm',
                '--signals', 'only_commented',
                '--constants', 'only_commented',
                '--process', 'only_commented',
                '--functions', 'only_commented',
                '--symbol_verilog', '/',
                '--input', hardware_path,
                '--out', 'markdown',
                '--outpath', 'docs'
            ],
            build_by_default: false,
            build_always_stale: true)

    teroshdl_pcie_target = custom_target('teroshdl_pcie',
            input: [doxyfile],
            output: 'doc_internal_pcie',
            command: [
                teroshdl_hdl_documenter,
                # '--recursive',
                '--dep',
                '--fsm',
                '--signals', 'only_commented',
                '--constants', 'only_commented',
                '--process', 'only_commented',
                '--functions', 'only_commented',
                '--symbol_verilog', '/',
                '--input', join_paths(hardware_path, 'pcie'),
                '--out', 'markdown',
                '--outpath', 'docs/pcie'
            ],
            build_by_default: false,
            build_always_stale: true)

    rm_hdl_doc_path = custom_target('rm_hdl_doc_path',
            input: teroshdl_target,
            output: 'rm_hdl_doc_path',
            command: [
                'rm', '-r', '-f', hdl_doc_path
            ],
            build_by_default: false,
            build_always_stale: true)

    cp_teroshdl_target = custom_target('cp_teroshdl',
            input: teroshdl_target,
            output: 'cp_teroshdl_target',
            command: [
                'cp',
                '-r',
                '-T',
                'docs/doc_internal',
                hdl_doc_path
            ],
            depends: [rm_hdl_doc_path, teroshdl_target, teroshdl_pcie_target],
            build_by_default: false,
            build_always_stale: true)

    cp_teroshdl_pcie_target = custom_target('cp_teroshdl_pcie',
            input: teroshdl_target,
            output: 'cp_teroshdl_pcie_target',
            command: [
                'cp',
                '-r',
                '-T',
                'docs/pcie/doc_internal',
                join_paths(hdl_doc_path, 'pcie')
            ],
            depends: [rm_hdl_doc_path, teroshdl_pcie_target,
                      cp_teroshdl_target],
            build_by_default: false,
            build_always_stale: true)
endif

mkdocs = find_program('mkdocs', required: false)

if mkdocs.found()
    mkdocs_config_file = files('mkdocs.yml')
    mkdocs_docs = custom_target('mkdocs_docs',
            input: [doc_sources, mkdocs_config_file],
            output: 'site',
            command: [mkdocs, 'build', '-f', mkdocs_config_file],
            depends: [enso_lib, cp_html_target, cp_teroshdl_target,
                      cp_teroshdl_pcie_target],
            build_by_default: false)

    docs = alias_target('docs', mkdocs_docs)
endif
