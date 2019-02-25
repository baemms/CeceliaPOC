###
# Load images from nd2 files,
# export single channels as maximum projection
###

from skimage import io
import numpy as np
import math
import os

# set java version for bioformats
os.environ['JAVA_HOME'] = "/Library/Java/JavaVirtualMachines/jdk1.8.0_181.jdk/Contents/Home/"

### BIOFORMATS
import javabridge
import bioformats
javabridge.start_vm(class_path=bioformats.JARS)

path_image_data = '/Volumes/DOM1/IMAGE/JOBS/N4-2 Projects/DC-donor/DC_TCELL/20181218_192811_042/'
path_image_tifs = '/Users/dominiks/Desktop/ANALYSIS/N4/N4-2-15/ANALYSIS/channel-tifs/'
file_image_data = (
    'Well1_Seq0000',
    'Well2_Seq0001',
    'Well3_Seq0002',
    'Well4_Seq0003',
    'Well5_Seq0007',
    'Well6_Seq0006',
    'Well7_Seq0005',
    'Well8_Seq0004'
)
file_ext_nd2 = ".nd2"
file_ext_tif = ".tif"
sites = range(0, 5)
timepoints = 160
has_series = False
required_channels = (
    (0, 1),
    (0, 1),
    (0, 1),
    (0, 1),
    (0, 1),
    (0, 1),
    (0, 1),
    (0,)
)
channel_names = (
    ("GFP", "OT-I"),
    ("GFP", "OT-I"),
    ("GFP", "OT-I"),
    ("GFP", "OT-I"),
    ("GFP", "OT-I"),
    ("GFP", "OT-I"),
    ("GFP", "OT-I"),
    ("OT-I",)
)

# read images
for cur_image_id in range(0, len(file_image_data)):
    cur_image_file = file_image_data[cur_image_id]
    cur_file = path_image_data + cur_image_file + file_ext_nd2

    # go through sites
    for cur_site in sites:
        # go through timeseries
        for cur_time in range(0, timepoints):
            # read image
            # does the file has a series?
            if has_series is True:
                cur_image = bioformats.load_image(cur_file, series=cur_site, t=cur_time, wants_max_intensity=False)
            else:
                next_t = (cur_time * len(sites)) + cur_site
                next_series = math.floor(next_t / timepoints)
                next_t = next_t - (next_series * timepoints)
                cur_image = bioformats.load_image(cur_file, series=next_series, t=next_t, wants_max_intensity=False)

            # go through channels and timepoint and save tifs
            for i, cur_channel in enumerate(required_channels[cur_image_id]):
                # calc path and new image size
                cur_out_path = cur_image_file \
                               + "_s" + str(cur_site) \
                               + "_t" + str(cur_time)\
                               + "_c" + channel_names[cur_image_id][i]\
                               + file_ext_tif
                # the image is in float32, ie/ transform it
                cur_out_image_16 = (10**6*cur_image[:, :, cur_channel]).astype('uint16')
                cur_out_image = cur_out_image_16

                # save image
                io.imsave(path_image_tifs + cur_out_path, cur_out_image, plugin='tifffile')

javabridge.kill_vm()
