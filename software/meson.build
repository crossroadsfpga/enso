inc = include_directories('include')

subdir('include')
subdir('src')

enso_lib = library('enso', project_sources, install: true,
                   include_directories: [inc, backend_inc])
pkg_mod = import('pkgconfig')
pkg_mod.generate(enso_lib)

subdir('examples')
