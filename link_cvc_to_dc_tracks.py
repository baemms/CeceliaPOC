###
# THU 13/12/2018
###
# Take the result of extracting DCs with CVC from 'extract_sampling_dc_v6.ijm'
# and link this to the identified tracks

import skimage.io as io
import csv
import os

# go through experiments, wells and sites
df_stats_base_dir = "/Users/dominiks/Desktop/ANALYSIS/N4/"
experiments = ["N4-2-13"]
wells = range(5, 8)
sites = range(0, 3)
analysis_dir = "/ANALYSIS/TRACKING_DC/"
clips_dir = "/ANALYSIS/TRACKING_DC_INDV/"
examples_dir = "/ANALYSIS/TRACKING_DC_EXAMPLES/"
sampling_dir = "/ANALYSIS/SAMPLING_DC/"
sampling_suffix = "_dc_seg.tif"
spots_suffix = "-spots.csv"
tracks_suffix = "-tracks.csv"
cvc_suffix = "-cvc.csv"
pixel_size = 0.325

keys_spots = {
    "TRACK_ID": -1, "POSITION_X": -1, "POSITION_Y": -1, "FRAME": -1
}

keys_tracks = {
    "TRACK_INDEX": -1
}

cvc_key = "CVC_COUNT"

for cur_exp in experiments:
    for cur_well in wells:
        for cur_site in sites:
            # define file paths
            cur_spots_file = df_stats_base_dir + cur_exp + analysis_dir +\
                             "w" + str(cur_well) + "_s" + str(cur_site) + spots_suffix
            cur_tracks_file = df_stats_base_dir + cur_exp + analysis_dir +\
                              "w" + str(cur_well) + "_s" + str(cur_site) + tracks_suffix
            cur_sampling_file = df_stats_base_dir + cur_exp + sampling_dir +\
                                "w" + str(cur_well) + "_s" + str(cur_site) + sampling_suffix
            cur_cvc_file = df_stats_base_dir + cur_exp + analysis_dir +\
                                "w" + str(cur_well) + "_s" + str(cur_site) + cvc_suffix

            # init dict of tracks to count CVC+ spots
            cvc_track_count = dict()

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
                        if cur_track_id not in cvc_track_count.keys():
                            cvc_track_count[cur_track_id] = 0

                        cur_t = int(cur_row[keys_spots['FRAME']])
                        cur_y = int(float(cur_row[keys_spots['POSITION_Y']]) * (1 / pixel_size))
                        cur_x = int(float(cur_row[keys_spots['POSITION_X']]) * (1 / pixel_size))

                        # lookup position for CVC signal
                        cur_cvc_val = cur_sampling_img[cur_t, cur_y, cur_x]

                        if cur_cvc_val > 0:
                            cvc_track_count[cur_track_id] += 1

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
                        cur_new_row = ['TRACK_INDEX', cvc_key]
                    else:
                        # add cvc information
                        cur_new_row = [
                            cur_row[keys_tracks['TRACK_INDEX']],
                            cvc_track_count[cur_row[keys_tracks['TRACK_INDEX']]]
                        ]

                    # write to cvc file
                    writer.writerow(cur_new_row)

                    counter += 1
