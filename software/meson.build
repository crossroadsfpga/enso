inc = include_directories('include')

subdir('include')
subdir('src')

threads_dep = dependency('fastscheduler')

enso_lib = library('enso', project_sources, install: true, dependencies: [threads_dep],
                   include_directories: [inc, backend_inc])
pkg_mod = import('pkgconfig')
pkg_mod.generate(enso_lib)

subdir('examples')
subdir('test')
