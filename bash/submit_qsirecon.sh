#!/bin/bash
#SBATCH --job-name=qsiprep_recon
#SBATCH --time=24:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=8G
#SBATCH --mail-user=ethanroy@stanford.edu
#SBATCH --mail-type=ALL
#SBATCH --partition=normal
#SBATCH --output=array_%x_%A_%a.out
#SBATCH --array=3-704%50

# should be array=1-704%50
echo “RUNNING QSIPREP on a single subjects”
SUBJECTS_FILE='/home/users/ethanroy/vanderbilt_colab/bash_scripts/revisions/subjects.txt'
subject=$( sed "${SLURM_ARRAY_TASK_ID}q;d" ${SUBJECTS_FILE} )
echo ${PWD}
echo $subject
# Make sure FS_LICENSE is defined in the container
# /home/groups/jyeatman/software/singularity_images/qsiprep-19unstable.simg
# /scratch/users/ethanroy/singularity_images/qsiprep-0.16.1.sif

export SINGULARITYENV_FS_LICENSE=/home/groups/jyeatman/software/freesurfer_license.txt
export SINGULARITYENV_QSIRECON_ATLAS=/home/users/ethanroy/vanderbilt_colab/Atlas_ROIs

singularity run --cleanenv /home/groups/jyeatman/software/singularity_images/qsiprep-0.22.0.simg \
/scratch/users/ethanroy/longitudinal_vanderbilt_colab/input_fmap_rev \
/scratch/users/ethanroy/longitudinal_vanderbilt_colab/input_fmap_rev/derivatives  participant --participant-label $subject \
--recon_input  /scratch/users/ethanroy/longitudinal_vanderbilt_colab/input_fmap_rev/derivatives/qsiprep \
-w /scratch/groups/jyeatman/ethan/work_test \
--nthreads 3 \
--recon_only \
--skip-odf-reports \
--recon_spec /home/users/ethanroy/vanderbilt_colab/bash_scripts/revisions/pyafq_tractometry.json \
--output-resolution 2.5 \

