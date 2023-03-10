cdata = configuration_data()
cdata.set('VERSION', meson.project_version())
cdata.set('TOP_SRCDIR', meson.project_source_root())
cdata.set('TOP_BUILDDIR', meson.project_build_root())

doc_sources = files([
    'assets/enso-black.svg',
    'assets/enso-white.svg',
    'assets/tx_pipe_partial_sent.svg',
    'javascripts/tablesort.js',
    'primitives/device.md',
    'primitives/rx_enso_pipe.md',
    'primitives/tx_enso_pipe.md',
    'primitives/rx_tx_enso_pipe.md',
    'examples/echo.md',
    'hardware/counters.md',
    'getting_started.md',
    'index.md',
    'tuning.md'
])

if find_program('dot', required: false).found()
  cdata.set('HAVE_DOT', 'YES')
else
  cdata.set('HAVE_DOT', 'NO')
endif

doxygen = find_program('doxygen', required: false)

generate_doc_markdown_sh = find_program(files('generate_doc_markdown.sh'),
                                        required: true)

doxybook2_config_file = files('config-doxybook2.json')

sw_doc_path = join_paths(meson.source_root(), 'docs/software')

if doxygen.found()
    doxyfile = configure_file(input: 'doxygen/Doxyfile.in',
                              output: 'Doxyfile',
                              configuration: cdata,
                              install: false)

    html_target = custom_target('doxygen',
                                input: [doxyfile, files([
                                  'doxygen/doxygen-awesome.css',
                                  'doxygen/doxygen-awesome-sidebar-only.css',
                                  'doxygen/doxygen_header.html'
                                ])],
                                output: ['html', 'xml'],
                                command: [doxygen, doxyfile],
                                depends: [enso_lib],
                                build_by_default: false)

    rm_software_doc_path = custom_target('rm_software_doc_path',
            input: html_target,
            output: 'rm_software_doc_path',
            command: [
                'rm', '-r', '-f', sw_doc_path
            ],
            build_by_default: false,
            build_always_stale: true)

    cp_html_target = custom_target('cp_html',
            input: html_target,
            output: 'cp_html_target',
            command: [
                'cp',
                '-r',
                '-T',
                'html',
                sw_doc_path
            ],
            depends: [rm_software_doc_path, html_target],
            build_by_default: false,
            build_always_stale: true)

    # markdown_target = custom_target('doxygen_markdown',
    #                                 input: [doxyfile],
    #                                 output: 'software',
    #                                 command: [generate_doc_markdown_sh,
    #                                           doxybook2_config_file],
    #                                 depends: [html_target],
    #                                 build_by_default: false,
    #                                 build_always_stale: true)
endif
