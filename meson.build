cdata = configuration_data()
cdata.set('VERSION', meson.project_version())
cdata.set('TOP_SRCDIR', meson.project_source_root())
cdata.set('TOP_BUILDDIR', meson.project_build_root())

if find_program('dot', required: false).found()
  cdata.set('HAVE_DOT', 'YES')
else
  cdata.set('HAVE_DOT', 'NO')
endif

doxygen = find_program('doxygen', required: false)

sw_doc_path = join_paths(meson.project_source_root(), 'docs/software')

if doxygen.found()
    doxyfile = configure_file(input: 'doxygen/Doxyfile.in',
                              output: 'Doxyfile',
                              configuration: cdata,
                              install: false)

    doxygen_target = custom_target('doxygen',
                                input: [doxyfile, files([
                                  'doxygen/doxygen-awesome.css',
                                  'doxygen/doxygen-awesome-sidebar-only.css',
                                  'doxygen/doxygen_header.html'
                                ])],
                                output: ['html', 'xml'],
                                command: [doxygen, doxyfile],
                                build_by_default: false)

    rm_software_doc_path = custom_target('rm_software_doc_path',
            input: doxygen_target,
            output: 'rm_software_doc_path',
            command: [
                'rm', '-r', '-f', sw_doc_path
            ],
            build_by_default: false,
            build_always_stale: true)

    cp_doxygen_target = custom_target('cp_html',
            input: doxygen_target,
            output: 'cp_doxygen_target',
            command: [
                'cp',
                '-r',
                '-T',
                'html',
                sw_doc_path
            ],
            depends: [rm_software_doc_path, doxygen_target],
            build_by_default: false,
            build_always_stale: true)
endif

teroshdl_hdl_documenter = find_program('teroshdl-hdl-documenter',
                                       required: false)
mkdocs = find_program('mkdocs', required: false)

if teroshdl_hdl_documenter.found() and mkdocs.found()
  mkdocs_docs = custom_target('mkdocs_docs',
          input: [cp_doxygen_target],
          output: 'site',
          command: ['build_docs.sh'],
          build_by_default: false,
          build_always_stale: true)

  docs = alias_target('docs', mkdocs_docs)
endif
