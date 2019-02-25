// paths
base_path = "/Users/dominiks/Desktop/ANALYSIS/N4/N4-2-13/ANALYSIS/";
output_path = base_path + "OVERLAPPING_DC/";

// define images to be opened by sequence
images = newArray(
	//"Well1_Seq0000",
	//"Well2_Seq0001",
	//"Well3_Seq0002",
	//"Well4_Seq0003",
	//"Well5_Seq0007",
	//"Well6_Seq0006"
	"Well7_Seq0005"
	//"Well8_Seq0004"
);
sites = newArray(
	//"0", "1", "2"
	"0"
);

timepoints = 160;

path_seg = base_path + "CP/OUT/DC/";
path_tif = base_path + "channel-tifs/";

channel_dc = "GFP";
channel_donor = "CVC";
save_tifs = true;
save_stats = false;
save_dc_overlap = false;

lut_dc = 5;
lut_donor = 6;
lut_donor_dil = 4;
lut_overlap = 7;

// filtering parameters
filt_gauss_size = 5;
filt_med_size = 5;
filt_dil_size = 33;

// overlapping parameters
min_overlap = 0.50;

// save stats
stats_length = images.length * sites.length * timepoints;
stats_dc = newArray(stats_length);
stats_dc_overlap = newArray(stats_length);
stats_area = newArray(stats_length);
stats_donor_area = newArray(stats_length);
stats_donor_dil_area = newArray(stats_length);

output_file_path = output_path + "stats.csv";

setBatchMode(true);

// go through images
for (cur_image_id = 0; cur_image_id < images.length; cur_image_id++){
	cur_image = images[cur_image_id];

	// extract well
	cur_well = replace(cur_image, "Well","");
	cur_well = replace(cur_well, "_Seq.*", "");
	cur_well = parseInt(cur_well);

	// go through sites
	for (cur_site_id = 0; cur_site_id < sites.length; cur_site_id++){
		cur_site = sites[cur_site_id];

		// set output
		cur_output_part =
			cur_image
			+ "_s" + cur_site;

		cur_image_pattern =
			cur_image
			+ "_s" + cur_site
			+ "_t[0-9]*";

		// open DCs
		run("Image Sequence...",
			"open=" + path_seg + " file=(" + cur_image_pattern + "_c" + channel_dc + ") sort use");
		rename("dc_seg");
		
		// open donors
		run("Image Sequence...",
			"open=" + path_tif + " file=(" + cur_image_pattern + "_c" + channel_donor + ") sort use");
		rename("donor_tif");
		run("Enhance Contrast", "saturated=0.35");
		run("8-bit");
		
		// segment donors
		run("Duplicate...", "duplicate");
		rename("donor_seg");
		
		// close donors
		selectWindow("donor_tif");
		close();
		selectWindow("donor_seg");

		// segment
		run("Gaussian Blur...", "sigma=" + filt_gauss_size + " stack");
		run("Convert to Mask", "method=Triangle background=Dark calculate black");
		
		run("Duplicate...", "duplicate");
		// dilate donors
		for (i = 0; i < filt_dil_size; i++){
			run("Dilate", "stack");
		}
		rename("donor_dil");

		for(i = 1; i <= nSlices; i++){
			setSlice(i);
			changeValues(1, 255, 1);
		}
		setMinAndMax(0, 4);

		selectWindow("donor_seg");
		for(i = 1; i <= nSlices; i++){
			setSlice(i);
			changeValues(1, 255, 1);
		}

		// calculate overlap
		imageCalculator("Multiply create stack", "dc_seg", "donor_dil");
		rename("calc_overlap");

		// smooth
		run("Median...", "radius=" + filt_med_size + " stack");

		// create image for overlapping DCs
		selectWindow("dc_seg");
		run("Duplicate...", "duplicate");
		rename("dc_overlap");

		// determine overlap for each frame
		for (cur_frame = 1; cur_frame <= timepoints; cur_frame++) {
			selectWindow("dc_seg");
			setSlice(cur_frame);
			getHistogram(dc_values, dc_counts, 256);
			
			selectWindow("donor_seg");
			setSlice(cur_frame);
			getHistogram(donor_values, donor_counts, 256);

			selectWindow("donor_dil");
			setSlice(cur_frame);
			getHistogram(donor_dil_values, donor_dil_counts, 256);
			
			selectWindow("calc_overlap");
			setSlice(cur_frame);
			getHistogram(overlap_values, overlap_counts, 256);
	
			selectWindow("dc_overlap");
			setSlice(cur_frame);

			dc_counter = 0;
			dc_overlap_counter = 0;
			for (i = 1; i < dc_counts.length; i++){
				if (dc_counts[i] > 0) {
					dc_counter++;
					
					cur_overlap = overlap_counts[i]/dc_counts[i];

					// set DCs with no overlap to '1'
					if (cur_overlap < min_overlap) {
						changeValues(i, i, 1);
					} else {
						dc_overlap_counter++;
					}
				}
			}

			// make binary
			changeValues(2, 255, 5);
			setMinAndMax(0, 5);
			run("Enhance Contrast", "saturated=0.35");

			// save stats
			cur_stats_id = 
				(cur_image_id * (sites.length * timepoints))
				+ (cur_site_id * timepoints)
				+ (cur_frame - 1);
			stats_dc[cur_stats_id] = dc_counter;
			stats_dc_overlap[cur_stats_id] = dc_overlap_counter;
			stats_area[cur_stats_id] = donor_counts[0] + donor_counts[1];
			stats_donor_area[cur_stats_id] = donor_counts[1];
			stats_donor_dil_area[cur_stats_id] = donor_dil_counts[1];
		}

		// close windows
		selectWindow("dc_seg"); close();
		selectWindow("donor_seg"); close();
		selectWindow("calc_overlap"); close();

		// open tifs
		run("Image Sequence...",
			"open=" + path_tif + " file=(" + cur_image_pattern + "_c" + channel_dc + ") sort use");
		rename("dc_tif");
		run("Enhance Contrast", "saturated=0.35");
		run("8-bit");
		
		run("Image Sequence...",
			"open=" + path_tif + " file=(" + cur_image_pattern + "_c" + channel_donor + ") sort use");
		rename("donor_tif");
		run("Enhance Contrast", "saturated=0.35");
		run("8-bit");

		if (save_dc_overlap == true) {
			selectWindow("dc_overlap");
			saveAs("Tiff", output_path + cur_output_part + "_dc_overlap.tif");
			rename("dc_overlap");
		}

		// save as movie
		run("Merge Channels...", 
		"c" + lut_dc + "=dc_tif" +
		" c" + lut_donor + "=donor_tif" +
		" c" + lut_overlap + "=dc_overlap" +
		" c" + lut_donor_dil + "=donor_dil" +
		" create");
		run("Flatten");

		run("AVI... ",
		"compression=JPEG frame=10 save=" + output_path + cur_output_part + ".avi");

		if (save_tifs == true) {
			saveAs("Tiff", output_path + cur_output_part + ".tif");
		}
		
		run("Close All");
	}
}

if (save_stats == true) {
	// delete file
	File.delete(output_file_path);
	
	// create new file
	output_file = File.open(output_file_path);
	
	print(output_file, "image,site,frame,dc_count,dc_overlapping_count,total_area,donor_area,donor_dil_area");
	
	// save values
	for (cur_image_id = 0; cur_image_id < images.length; cur_image_id++){
		cur_image = images[cur_image_id];
	
		for (cur_site_id = 0; cur_site_id < sites.length; cur_site_id++){
			cur_site = sites[cur_site_id];
	
			for (cur_frame = 1; cur_frame <= timepoints; cur_frame++) {
				cur_stats_id = 
					(cur_image_id * (sites.length * timepoints))
					+ (cur_site_id * timepoints)
					+ (cur_frame - 1);
	
				print(output_file, cur_image + "," + cur_site + "," + cur_frame
						+ "," + stats_dc[cur_stats_id]
						+ "," + stats_dc_overlap[cur_stats_id]
						+ "," + stats_area[cur_stats_id]
						+ "," + stats_donor_area[cur_stats_id]
						+ "," + stats_donor_dil_area[cur_stats_id]
						);
			}
		}
	}
	
	File.close(output_file);
}