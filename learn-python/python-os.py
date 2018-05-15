import os
import shutil
import pathlib
import glob
import sys
import re



os.getcwd()
os.chdir('/tmp')
os.system('mkdir today')


shutil.copyfile('data.db', 'archive.db')
shutil.move('/build/executables', 'installdir')


glob.glob('*.py')

print(sys.argv)
sys.stderr.write('Warning, log file not found starting a new one\n')

re.findall(r'\bf[a-z]*', 'which foot or hand fell fastest')

