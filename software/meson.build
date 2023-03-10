inc = include_directories('include')

subdir('include')
subdir('src')

pcap_dep = dependency('pcap', version : '>=1.0')

enso_lib = library('enso', project_sources, install: true,
                   dependencies: pcap_dep, include_directories: inc)

subdir('examples')
