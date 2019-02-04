// paths
base_path = "/Users/dominiks/Desktop/ANALYSIS/N4/";
analysis_path = "/ANALYSIS/";
stats_file = "stats.csv";
output_path = "DC_WITH_TCELL/";

// define images to be opened by sequence
experiments = newArray(
	"N4-2-15"
);
wells = newArray(
	"1", "2", "3", "4",
	"5", "6", "7"
);
sites = newArray(
	"0","1","2",
	"3","4"
);

timepoints = 160;
//time_pattern = "_t10[0-9]";
time_pattern = "_t.*";
time_interval = "6 min";
pixel_size = 0.325;

channel_dc = "GFP";
channel_tcell = "OT-I";

lut_dc = 5;
lut_tcell = 7;
lut_overlap = 6;

// filtering parameters
filt_gauss_size = 5;
filt_med_size = 5;
filt_dil_size = 0; // size of a T cell

// overlap
min_overlap = 0.50;

setBatchMode(true);

// go through experiments
for (cur_exp_id = 0; cur_exp_id < experiments.length; cur_exp_id++) {
	cur_exp = experiments[cur_exp_id];
	print(">> CUR EXP " + cur_exp);

	cur_base_path = base_path + cur_exp + analysis_path;
	cur_path_tif = cur_base_path + "channel-tifs/";
	cur_path_seg = cur_base_path + "CP/OUT/DC/";
	cur_path_output = cur_base_path + output_path;
	cur_file_output = cur_path_output + stats_file;

	// save stats
	stats_length = experiments.length * wells.length * sites.length * timepoints;
	stats_dc = newArray(stats_length);
	stats_dc_overlap = newArray(stats_length);
	stats_tcell_area = newArray(stats_length);
	stats_tcell_area_on_dc = newArray(stats_length);
	stats_tcell_area_on_dc_overlap = newArray(stats_length);
		
	// go through images
	for (cur_well_id = 0; cur_well_id < wells.length; cur_well_id++){
		cur_well = wells[cur_well_id];
		print(">> CUR WELL " + cur_well);
		
		// go through sites
		for (cur_site_id = 0; cur_site_id < sites.length; cur_site_id++){
			cur_site = sites[cur_site_id];
			print(">> CUR SITE " + cur_site);

			cur_image_pattern =
				"Well" + cur_well +
				".*_s" + cur_site +
				time_pattern + ".*";

			cur_output_part =
				"e" + cur_exp
				+ "_w" + cur_well
				+ "_s" + cur_site;
			
			// open T cells
			run("Image Sequence...",
				"open=" + cur_path_tif + " file=(" + cur_image_pattern + "_c" + channel_tcell + ") sort");
			rename("tcell_seg");
			run("Enhance Contrast", "saturated=0.35");
			run("8-bit");
	
			// segment
			run("Gaussian Blur...", "sigma=" + filt_gauss_size + " stack");
			run("Convert to Mask", "method=Triangle background=Dark calculate black");
	
			for(i = 1; i <= nSlices; i++){
				setSlice(i);
				changeValues(1, 255, 1);
			}
			setMinAndMax(0, 4);
	
			// open dc
			run("Image Sequence...",
				"open=" + cur_path_seg + " file=(" + cur_image_pattern + "_c" + channel_dc + ") sort use");
			rename("dc_seg");
			run("Enhance Contrast", "saturated=0.35");
			run("8-bit");
	
			// apply donor mask to DCs
			imageCalculator("Multiply create stack", "tcell_seg", "dc_seg");
			rename("calc_overlap");

			// create image for overlapping DCs
			selectWindow("dc_seg");
			run("Duplicate...", "duplicate");
			rename("dc_overlap");

			// calculate area covered by T cells
			for (cur_frame = 1; cur_frame <= timepoints; cur_frame++) {
				selectWindow("tcell_seg");
				setSlice(cur_frame);
				getHistogram(tcell_values, tcell_counts, 256);
				
				selectWindow("calc_overlap");
				setSlice(cur_frame);
				getHistogram(overlap_values, overlap_counts, 256);

				selectWindow("dc_seg");
				setSlice(cur_frame);
				getHistogram(dc_values, dc_counts, 256);

				selectWindow("dc_overlap");
				setSlice(cur_frame);

				dc_counter = 0;
				dc_overlap_counter = 0;
				tcell_area_on_dc = 0;
				tcell_area_on_dc_overlap = 0;
				for (i = 1; i < dc_counts.length; i++){
					if (dc_counts[i] > 0) {
						dc_counter++;
						
						cur_overlap = overlap_counts[i]/dc_counts[i];
	
						// set DCs with no overlap to '1'
						if (cur_overlap < min_overlap) {
							changeValues(i, i, 1);
						} else {
							dc_overlap_counter++;
							tcell_area_on_dc_overlap += overlap_counts[i];
						}

						tcell_area_on_dc += overlap_counts[i];
					}
				}
	
				// make binary
				changeValues(2, 255, 5);
				setMinAndMax(0, 5);
				run("Enhance Contrast", "saturated=0.35");
	
				// save stats
				cur_stats_id = 
					(cur_well_id * sites.length * timepoints)
					+ (cur_site_id * timepoints)
					+ (cur_frame - 1);
				stats_dc[cur_stats_id] = dc_counter;
				stats_dc_overlap[cur_stats_id] = dc_overlap_counter;
				stats_tcell_area[cur_stats_id] = tcell_counts[1];
				stats_tcell_area_on_dc[cur_stats_id] = tcell_area_on_dc;
				stats_tcell_area_on_dc_overlap[cur_stats_id] = tcell_area_on_dc_overlap;
			}

			// close windows
			selectWindow("dc_seg"); close();
			selectWindow("tcell_seg"); close();
			selectWindow("calc_overlap"); close();
	
			// open tifs
			run("Image Sequence...",
				"open=" + cur_path_tif + " file=(" + cur_image_pattern + "_c" + channel_dc + ") sort use");
			rename("dc_tif");
			run("Enhance Contrast", "saturated=0.35");
			run("8-bit");
			
			run("Image Sequence...",
				"open=" + cur_path_tif + " file=(" + cur_image_pattern + "_c" + channel_tcell + ") sort use");
			rename("tcell_tif");
			run("Enhance Contrast", "saturated=0.35");
			run("8-bit");
	
			// save as movie
			run("Merge Channels...", 
			"c" + lut_dc + "=dc_tif" +
			" c" + lut_overlap + "=dc_overlap" +
			" c" + lut_tcell + "=tcell_tif" +
			" create");
			run("Flatten");
	
			run("AVI... ",
			"compression=JPEG frame=10 save=" + cur_path_output + cur_output_part + ".avi");

			run("Close All");
		}
	}

	// delete file
	File.delete(cur_file_output);
	
	// create new file
	output_file = File.open(cur_file_output);
	
	print(output_file, "well,site,time,dc_count,dc_overlapping_count,tcell_area,tcell_area_on_dc,tcell_area_on_dc_overlap");
	
	// save values
	for (cur_well_id = 0; cur_well_id < wells.length; cur_well_id++){
		cur_well = wells[cur_well_id];
	
		for (cur_site_id = 0; cur_site_id < sites.length; cur_site_id++){
			cur_site = sites[cur_site_id];
	
			for (cur_frame = 1; cur_frame <= timepoints; cur_frame++) {
				cur_stats_id = 
					(cur_well_id * sites.length * timepoints)
					+ (cur_site_id * timepoints)
					+ (cur_frame - 1);
	
				print(output_file, cur_well + "," + cur_site + "," + cur_frame
						+ "," + stats_dc[cur_stats_id]
						+ "," + stats_dc_overlap[cur_stats_id]
						+ "," + stats_tcell_area[cur_stats_id]
						+ "," + stats_tcell_area_on_dc[cur_stats_id]
						+ "," + stats_tcell_area_on_dc_overlap[cur_stats_id]
						);
			}
		}
	}
	
	File.close(output_file);
}