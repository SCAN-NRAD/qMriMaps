import pandas as pd
import numpy as np
import nibabel as nib
import argparse
import os
import sys


def roi_coverage(arr):
    return np.sum(arr > 0) / arr.shape[0] * 100


STAT_METRICS = {'mean': np.mean, 'std': np.std, 'median': np.median, 'roi_coverage': roi_coverage}
#MAPS = ['rBF', 'rBV']
MAPS = []


def get_stats(subject, anat_dir, maps_dir, maps_subdir, lut):
    all_stats = {}
    anat_data = nib.load('{}/{}/label-registered.nii.gz'.format(anat_dir, subject)).get_fdata(dtype=np.float32)
    for m in MAPS:
        all_stats[m] = {}
        maps_data = nib.load('{}/{}/{}/{}.nii.gz'.format(maps_dir, subject, maps_subdir, m)).get_fdata(dtype=np.float32)
        rois = [maps_data[np.where(np.isin(anat_data, lbl))] for lbl in lut.values()]
        
        for metric in STAT_METRICS:
            stats = ([STAT_METRICS[metric](roi) for roi in rois])
            stats_dict = {'SUBJECT': subject}
            stats_dict.update(dict(zip(lut.keys(), stats)))
            all_stats[m][metric] = stats_dict
            
    return all_stats


def main(anat_dir, maps_dir, maps_subdir, result_dir):
    subjects = sorted(os.listdir(maps_dir))
    
    if len(MAPS) == 0:
        MAPS.extend([m.split('.')[0] for m in os.listdir('{}/{}/{}'.format(maps_dir, subjects[0], maps_subdir)) if not 'RESULTS_' in m])
        
    with open('{}/maps.txt'.format(result_dir), 'w') as file:
        file.write(','.join(MAPS))
    
    lut = pd.read_csv('{}/{}/label_def.csv'.format(anat_dir, subjects[0]))
    lut =  dict(zip(list(lut.LABEL), [[s] for s in lut.ID]))
    
    lh_cortex_lbl = [lut[l][0] for l in filter(lambda x: (x.startswith('lh-')), lut.keys())]
    rh_cortex_lbl = [lut[l][0] for l in filter(lambda x: (x.startswith('rh-')), lut.keys())]
    lut['Left-Cortex'] = lh_cortex_lbl
    lut['Right-Cortex'] = rh_cortex_lbl
    lut['TotalCortex'] = lh_cortex_lbl+rh_cortex_lbl
    
    # lobar stats
    fs_anatomy = pd.read_csv('{}/fs_anatomy.csv'.format(os.path.dirname(os.path.realpath(sys.argv[0]))))
    LOBES = ['Temporal', 'Frontal', 'Parietal', 'Occipital']
    for hemi in ['lh', 'rh']:
        for lobe in LOBES:
            hemi_str = 'Left' if hemi == 'lh' else 'Right'
            lut['{}-{}-Lobe'.format(hemi_str, lobe)] = [lut['{}-{}'.format(hemi, l)][0] for l in fs_anatomy.loc[fs_anatomy.Lobe == lobe].Key]
    
    all_subj_stats = [get_stats(s, anat_dir, maps_dir, maps_subdir, lut) for s in subjects]
    
    if not os.path.exists(result_dir):
        os.mkdir(result_dir)
        
    for m in MAPS:
        for metric in STAT_METRICS:
            stats = [stats[m][metric] for stats in all_subj_stats]
            df_stats = pd.DataFrame(stats, columns=stats[0].keys())
            
            df_stats.to_csv('{}/{}_{}.csv'.format(result_dir, m, metric), sep=',', na_rep='', index=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Extract statistics from ROIs')
    
    parser.add_argument(
        '--maps_subdir',
        default='perf',
        type=str,
        help='Subdirectory with maps (e.g. perf)'
    )
    
    parser.add_argument(
        'maps_dir',
        type=str,
        help='Directory with maps'
    )
    
    parser.add_argument(
        'results_dir',
        type=str,
        help='Directory with results'
    )
    
    args = parser.parse_args()
    
    main(args.results_dir + '/subjects', args.maps_dir,args.maps_subdir,  args.results_dir)
    