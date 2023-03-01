from setuptools import setup, find_packages
import pathlib

here = pathlib.Path(__file__).parent.resolve()
long_description = (here / 'README.md').read_text(encoding='utf-8')

setup(
    name='qMriMaps',
    version='1.0',
    description='qMriMaps',
    long_description=long_description,
    long_description_content_type='text/markdown',
    url='https://github.com/SCAN-NRAD/qMriMaps',
    classifiers=[
        'Development Status :: 5 - Production/Stable',
        'Intended Audience :: Science/Research',
        'Topic :: Scientific/Engineering',
        'Programming Language :: Python :: 3',
    ],
    keywords='MRI, morphometry, quantitative evaluation, perfusion',
    package_dir={'': 'src'},
    packages=find_packages(where='src'),
    python_requires='>=3.7',
    install_requires=['DL-DiReCT @ https://github.com/SCAN-NRAD/DL-DiReCT/archive/refs/heads/main.zip',
                      'nibabel>=3.2.1',
                      'numpy>=1.17.4',
                      'pandas>=0.25.3'],
    dependency_links=['https://github.com/SCAN-NRAD/DL-DiReCT/archive/refs/heads/main.zip'],

    entry_points={'console_scripts': ['qmrimaps=runner:run']},
    project_urls={  # Optional
        #'Bug Reports': 'https://github.com/SCAN-NRAD/qMriMaps/issues',
        'Source': 'https://github.com/SCAN-NRAD/qMriMaps'
    },
)
