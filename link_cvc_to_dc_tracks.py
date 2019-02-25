###
# THU 13/12/2018
###
# Take the result of extracting DCs with CVC from 'extract_sampling_dc_v6.ijm'
# and link this to the identified tracks

import skimage.io as io
import csv
import os
import pandas as pd
import glob2

# go through experiments, wells and sites
df_stats_base_dir = "/Users/dominiks/Desktop/ANALYSIS/N4/"
experiments = ["N4-2-13"]
wells = range(5, 8)
sites = range(0, 3)
analysis_dir = "/ANALYSIS/TRACKING_DC/"
clips_dir = "/ANALYSIS/TRACKING_DC_INDV/"
examples_dir = "/ANALYSIS/TRACKING_DC_EXAMPLES/"
sampling_dir = "/ANALYSIS/SAMPLING_DC/"
cp_dir = "/ANALYSIS/CP/OUT/stats/"
overlap_dir = "/ANALYSIS/OVERLAPPING_DC/"

seg_suffix = "_dc_seg.tif"
sampling_suffix = "_dc_sampling.tif"
overlap_suffix = "_dc_overlap.tif"
spots_suffix = "-spots.csv"
tracks_suffix = "-tracks.csv"
cvc_suffix = "-cvc.csv"
spots_cvc_suffix = "-spots_cvc.csv"
cp_stats_file = "DC_DC.csv"

pixel_size = 0.325

keys_spots = {
    "TRACK_ID": -1, "POSITION_X": -1, "POSITION_Y": -1, "FRAME": -1
}

keys_tracks = {
    "TRACK_ID": -1
}

cvc_key = "IS_CVC_POS"
seg_key = "NO_DC_SEG"
cp_key = "CP_SEG_ID"
overlap_key = "ON_DONOR"

for cur_exp in experiments:
    for cur_well in wells:
        for cur_site in sites:
            # define file paths
            cur_spots_file = df_stats_base_dir + cur_exp + analysis_dir +\
                             "w" + str(cur_well) + "_s" + str(cur_site) + spots_suffix
            cur_tracks_file = df_stats_base_dir + cur_exp + analysis_dir +\
                              "w" + str(cur_well) + "_s" + str(cur_site) + tracks_suffix
            cur_seg_file = df_stats_base_dir + cur_exp + sampling_dir +\
                                "w" + str(cur_well) + "_s" + str(cur_site) + seg_suffix
            cur_sampling_file = df_stats_base_dir + cur_exp + sampling_dir +\
                                "w" + str(cur_well) + "_s" + str(cur_site) + sampling_suffix
            cur_cvc_file = df_stats_base_dir + cur_exp + analysis_dir +\
                                "w" + str(cur_well) + "_s" + str(cur_site) + cvc_suffix
            cur_spots_cvc_file = df_stats_base_dir + cur_exp + analysis_dir + \
                           "w" + str(cur_well) + "_s" + str(cur_site) + spots_cvc_suffix
            cur_overlap_file = df_stats_base_dir + cur_exp + overlap_dir +\
                                "Well" + str(cur_well) + "*_s" + str(cur_site) + overlap_suffix
            cur_overlap_file = glob2.glob(cur_overlap_file)
            if len(cur_overlap_file) > 0:
                cur_overlap_file = cur_overlap_file[0]
            else:
                cur_overlap_file = ""

            # init dict of tracks to count CVC+ spots
            track_info = dict()

            # read segmentation image
            cur_seg_img = io.imread(cur_seg_file, plugin='tifffile')

            # read overlapping file
            cur_overlap_img = None
            if os.path.isfile(cur_overlap_file):
                cur_overlap_img = io.imread(cur_overlap_file, plugin='tifffile')

            # read sampling image
            cur_sampling_img = io.imread(cur_sampling_file, plugin='tifffile')

            # read spots
            with open(cur_spots_file, 'r') as cur_read:
                reader = csv.reader(cur_read)

                counter = 0
                for cur_row in reader:
                    # get indices of keys
                    if counter == 0:
                        for key, value in keys_spots.items():
                            keys_spots[key] = cur_row.index(key)
                    else:
                        cur_track_id = cur_row[keys_spots['TRACK_ID']]

                        # check if track is already in list
                        if cur_track_id not in track_info.keys():
                            track_info[cur_track_id] = dict()

                        cur_t = int(cur_row[keys_spots['FRAME']])
                        cur_y = int(float(cur_row[keys_spots['POSITION_Y']]) * (1 / pixel_size))
                        cur_x = int(float(cur_row[keys_spots['POSITION_X']]) * (1 / pixel_size))

                        # lookup position for segmentation
                        cur_seg_val = cur_seg_img[cur_t, cur_y, cur_x]

                        # lookup position for CVC signal
                        cur_cvc_val = cur_sampling_img[cur_t, cur_y, cur_x]

                        # lookup position for overlap
                        cur_overlap_val = -1

                        if cur_overlap_img is not None:
                            cur_overlap_val = cur_overlap_img[cur_t, cur_y, cur_x]

                        no_dc_seg = 1
                        is_cvc_pos = 0
                        cp_seg_id = -1
                        on_donor = -1

                        # save segmentation id
                        if cur_seg_val > 0:
                            no_dc_seg = 0
                            on_donor = 0
                            cp_seg_id = cur_seg_val

                            if cur_overlap_val > 1:
                                on_donor = 1

                        if cur_cvc_val > 0:
                            is_cvc_pos = 1

                        track_info[cur_track_id][cur_t] = [is_cvc_pos, no_dc_seg, cp_seg_id, on_donor]

                    counter += 1

            # read and write tracks
            with open(cur_tracks_file, 'r') as csv_read, open(cur_cvc_file, 'w') as csv_write:
                reader = csv.reader(csv_read)
                writer = csv.writer(csv_write)

                # go through tracks and add cvc count information
                counter = 0
                for cur_row in reader:
                    # get indices of keys
                    if counter == 0:
                        for key, value in keys_tracks.items():
                            keys_tracks[key] = cur_row.index(key)

                        # add keys to new file
                        cur_new_row = ['TRACK_ID', 'FRAME', cvc_key, seg_key, cp_key, overlap_key]

                        # write to cvc file
                        writer.writerow(cur_new_row)
                    else:
                        # go through track timepoints
                        for cur_frame, cur_value in track_info[cur_row[keys_tracks['TRACK_ID']]].items():
                            # add cvc information
                            cur_new_row = [
                                cur_row[keys_tracks['TRACK_ID']],
                                cur_frame,
                                cur_value[0],
                                cur_value[1],
                                cur_value[2],
                                cur_value[3]
                            ]

                            # write to cvc file
                            writer.writerow(cur_new_row)

                    counter += 1

            # merge with spots
            csv_spots = pd.read_csv(cur_spots_file)
            csv_cvc = pd.read_csv(cur_cvc_file)

            csv_merged = csv_spots.merge(csv_cvc, on=['TRACK_ID', 'FRAME'])

            # save back as merged
            csv_merged.to_csv(cur_spots_cvc_file, index=False)
