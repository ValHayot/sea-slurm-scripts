#!/usr/bin/env python
from string import Template
import nibabel as nib
import sys
import os

dataset = sys.argv[1]
epi = sys.argv[2]
anat = sys.argv[3]
out_script = sys.argv[4]
seasource=sys.argv[5]
seamount=sys.argv[6]

header = nib.load(epi).header
nslices = header["dim"][3]
nvols = header["dim"][4]
tr = header["pixdim"][4]
ta = tr - (tr / nslices)
so_odd = [str(i) for i in range(1, nslices+1, 2)]
so_even = [str(i) for i in range(2, nslices+1, 2)]
so = so_odd + so_even if nslices % 2 else so_even + so_odd
so=" ".join(so)

epi = epi.replace(seasource, seamount)
anat = anat.replace(seasource, seamount)
fmriscans = " ;".join([f"'{epi},{i}'" for i in range(1, nslices + 1)])
refslice = int(nslices/2)
print("ANAT file", anat)
print("EPI file", epi)
print("Number of volumes", nvols)
print("Number of slices", nslices)
print("TR", tr)
print("TA", ta)
print("Slice order interleaved", so)
print("Reference slice", refslice)
print("Output script", out_script)

with open(os.path.join(os.path.dirname(__file__), "preprocess_template_job.m"), "r") as t:
    with open(out_script, "w+") as f:
        d = { 
              "fmriscans": fmriscans, 
              "anat": anat,
              "nslices": nslices,
              "tr": tr,
              "ta": ta,
              "so": so,
              "refslice": refslice
            }
        src = Template(t.read())
        f.write(src.substitute(d))

script_dn = os.path.dirname(out_script)
script_bn = os.path.basename(out_script)

launch_script = os.path.join(script_dn, f"launch_{script_bn}")
with open(os.path.join(os.path.dirname(__file__), "launch_preprocess.m"), "r") as t:
    with open(launch_script, "w+") as f:
        d = { "out_script": script_bn.replace(".m", ""), "script_path": script_dn }
        src = Template(t.read())
        f.write(src.substitute(d))

