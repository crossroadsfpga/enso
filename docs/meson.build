cdata = configuration_data()
cdata.set('VERSION', meson.project_version())
cdata.set('TOP_SRCDIR', meson.project_source_root())
cdata.set('TOP_BUILDDIR', meson.project_build_root())

doc_sources = files([
    'assets/enso-black.svg',
    'assets/enso-white.svg',
    'javascripts/tablesort.js',
    'enso_pipe.md',
    'index.md',
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
                                depends: [norman_lib],
                                build_by_default: false)

    # markdown_target = custom_target('doxygen_markdown',
    #                                 input: [doxyfile],
    #                                 output: 'software',
    #                                 command: [generate_doc_markdown_sh,
    #                                           doxybook2_config_file],
    #                                 depends: [html_target],
    #                                 build_by_default: false,
    #                                 build_always_stale: true)
endif
