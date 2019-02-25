/*---
 * FUNCTIONS
 */
function getIntensity(window_for_roi, window_for_intensity) {
	intensity = 0;

	selectWindow(window_for_roi);
	run("Analyze Particles...", "add");
	selectWindow(window_for_intensity);
	roiManager("Measure");
	if (nResults > 0) {
		intensity = getResult("Mean", 0);
		roiManager("Delete"); run("Clear Results");
	}

	return intensity;
}

function closeWindow(window_to_close) {
	selectWindow(window_to_close);
	close();
}

//---

// define images to be opened by sequence
//experiments = newArray("N4-2-7", "N4-2-9");
experiments = newArray("N4-2-13");
wells = newArray(
	"5", "6", "7"
);
sites = newArray(
	"0", "1", "2"
);
timepoints = 160;
time_pattern = ".*";
pixel_size = 3.0769;
frame_rate = 10;

base_path = "/Users/dominiks/Desktop/ANALYSIS/N4/";
analysis_path = "/ANALYSIS/";

channel_dc = "GFP";
channel_donor = "CVC";

// parameters to detect sampling DCs
retain_ratio = newArray(1.5, 1.8);
retain_threshold = newArray(5, 20);
dc_dilation = 16;
dc_erosion = 4;

setBatchMode(true);

// go through experiments
for (cur_exp_id = 0; cur_exp_id < experiments.length; cur_exp_id++) {
	cur_exp = experiments[cur_exp_id];
	print(">> CUR EXP " + cur_exp);

	cur_base_path = base_path + cur_exp + analysis_path;
	cur_path_tif = cur_base_path + "channel-tifs/";
	cur_path_seg = cur_base_path + "CP/OUT/DC/";
	cur_path_outline = cur_base_path + "CP/OUT/outline/";
	cur_path_movies = cur_base_path + "SAMPLING_DC/";
	
	// go through images
	for (cur_well_id = 0; cur_well_id < wells.length; cur_well_id++){
		cur_well = wells[cur_well_id];
		print(">> CUR WELL " + cur_well);
		
		// go through sites
		for (cur_site_id = 0; cur_site_id < sites.length; cur_site_id++){
			cur_site = sites[cur_site_id];
			print(">> CUR SITE " + cur_site);

			cur_file_pattern = "Well" + cur_well + ".*s" + cur_site + "_t" + time_pattern;
			
			// open DCs
			run("Image Sequence...",
				"open=" + cur_path_seg + " file=(" + cur_file_pattern + "_c" + channel_dc + ") sort");
			rename("dc_seg");
			run("Duplicate...", "duplicate");
			rename("dc_morph");
			
			// open donors tif
			run("Image Sequence...",
				"open=" + cur_path_tif + " file=(" + cur_file_pattern + "_c" + channel_donor + ") sort use");
			rename("donors");
			run("8-bit");
			run("Enhance Contrast", "saturated=0.35");

			// open dc tif
			run("Image Sequence...",
				"open=" + cur_path_tif + " file=(" + cur_file_pattern + "_c" + channel_dc + ") sort use");
			rename("dc");
			run("8-bit");
			run("Enhance Contrast", "saturated=0.35");
			
			run("Set Measurements...", "mean redirect=None decimal=3");
			
			// go through slices
			for (cur_slice = 1; cur_slice <= nSlices; cur_slice++) {
				print(">> PROCESS SLICE " + cur_slice);
				selectWindow("dc_seg"); setSlice(cur_slice);
				getHistogram(dc_values, dc_counts, 256);
			
				selectWindow("donors"); setSlice(cur_slice);
			
				// exclude '0'
				for(cur_dc = 1; cur_dc < dc_counts.length; cur_dc++) {
					//					donors, dc
					inner_int = newArray(0, 0);
					outer_int = newArray(0, 0);
					cur_ratio = newArray(0, 0);
			
					// get intensity of CVC
					if (dc_counts[cur_dc] > 0) {
						// get intensity for DCs
						selectWindow("dc_seg");
						run("Duplicate...", "use");
						rename("dc_seg_" + cur_dc);
						changeValues(0, (cur_dc - 1), 0);
						changeValues((cur_dc + 1), 255, 0);
						changeValues(cur_dc, cur_dc, 1);
						setThreshold(1, 255); run("Make Binary");
						run("Morphological Filters", "operation=Erosion element=Square radius=" + dc_erosion);
						rename("dc_ero_" + cur_dc);

						inner_int[0] = getIntensity("dc_ero_" + cur_dc, "donors");
						inner_int[1] = getIntensity("dc_ero_" + cur_dc, "dc");

						// create donut
						selectWindow("dc_seg_" + cur_dc); run("Duplicate...", "use");
						rename("dc_dupl_" + cur_dc);
						run("Morphological Filters", "operation=Dilation element=Square radius=" + dc_dilation);
						rename("dc_dil_" + cur_dc);
						
						imageCalculator("XOR create", "dc_seg_" + cur_dc, "dc_dil_" + cur_dc);
						rename("dc_donut_" + cur_dc);
			
						outer_int[0] = getIntensity("dc_donut_" + cur_dc, "donors");
						outer_int[1] = getIntensity("dc_donut_" + cur_dc, "dc");

						closeWindow("dc_seg_" + cur_dc); 
						closeWindow("dc_ero_" + cur_dc);
						closeWindow("dc_dupl_" + cur_dc);
						closeWindow("dc_dil_" + cur_dc);
						closeWindow("dc_donut_" + cur_dc);
					}

					// apply thresholds
					threshold_out = newArray(false, false);

					for (i = 0; i < inner_int.length; i++) {
						if (outer_int[i] > 0) {
							cur_ratio[i] = inner_int[i] / outer_int[i];
						}
						
						if (inner_int[i] > retain_threshold[i]){
							if (cur_ratio[i] > retain_ratio[i]) {
								threshold_out[i] = true;
							}
						}
					}
					
					// then delete from DC segmentation
					if (threshold_out[0] == false) {
						selectWindow("dc_seg");
						setSlice(cur_slice);
						changeValues(cur_dc, cur_dc, 0);
					}

					// remove flat DCs
					if (threshold_out[1] == false) {
						selectWindow("dc_morph");
						setSlice(cur_slice);
						changeValues(cur_dc, cur_dc, 0);
					}
			
					//print(">> " + cur_slice + "/" + cur_dc + ":\tINNER " + inner_int[1] + "\tOUTER " + outer_int[1] + "\tRATIO " + cur_ratio[1]);
				}
			}
			
			//setBatchMode("exit & display");

			// save sampling DC segmentation separately
			selectWindow("dc_seg");
			saveAs("Tiff", cur_path_movies + "w" + cur_well + "_s" + cur_site + "_dc_sampling.tif");
			rename("dc_sampling");

			// open DCs
			run("Image Sequence...",
				"open=" + cur_path_seg + " file=(" + cur_file_pattern + "_c" + channel_dc + ") sort");
			rename("dc_seg");
			saveAs("Tiff", cur_path_movies + "w" + cur_well + "_s" + cur_site + "_dc_seg.tif");
			close();
			
			run("Merge Channels...", "c5=dc c6=donors c7=dc_sampling c1=dc_morph create");
			run("Properties...",
			"channels=4 slices=1 frames=" + timepoints + " unit=pixel pixel_width=1.0000 pixel_height=1.0000 voxel_depth=1.0000");
			run("Flatten");

			// save as movie
			run("AVI... ",
				"compression=JPEG frame=" + frame_rate + " save="
				+ cur_path_movies + "w" + cur_well + "_s" + cur_site + ".avi");

			run("Close All");
		}
	}
}