addpath('/opt/spm12')
addpath('$script_path')
spm('defaults', 'fmri')
spm_jobman('initcfg')
$out_script
spm_jobman('run', matlabbatch)
