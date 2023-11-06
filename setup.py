from setuptools import setup, find_packages

setup(name='BITGOD',
      version='6.0.0',
      description=(
          'BITGOD Framework is an Android post-exploitation framework that exploits the'
          ' Android Debug Bridge to remotely access an Android device.'
      ),
      url='http://github.com/EntySec/Ghost',
      author='EntySec',
      author_email='bitwallssec@gmail.com',
      license='MIT',
      python_requires='>=3.7.0',
      packages=find_packages(),
      include_package_data=True,
      entry_points={
          "console_scripts": [
              "BITGOD = HackGod:cli"
          ]
      },
      install_requires=[
          'adb-shell',
          'pex @ git+https://github.com/EntySec/Pex',
          'badges @ git+https://github.com/EntySec/Badges',
          'colorscript @ git+https://github.com/EntySec/ColorScript'
      ],
      zip_safe=False
      )
