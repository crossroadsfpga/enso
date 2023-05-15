inc = include_directories('include')

subdir('include')
subdir('src')

if mock
    pcap_dep = dependency('pcap', version : '>=1.0')
    enso_lib = library('enso', project_sources, install: true,
                       include_directories: inc, dependencies: pcap_dep)

else
    enso_lib = library('enso', project_sources, install: true,
                       include_directories: inc)
endif

pkg_mod = import('pkgconfig')
pkg_mod.generate(enso_lib)

subdir('examples')
