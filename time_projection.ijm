// paths
base_path = "/Users/dominiks/Desktop/ANALYSIS/N4/N4-2-13/ANALYSIS/";
output_path = base_path + "TIME_PROJECTION_MERGE/";

// define images to be opened by sequence
images = newArray(
	"Well1_Seq0000",
	"Well2_Seq0001",
	"Well3_Seq0002",
	"Well4_Seq0003",
	"Well5_Seq0007",
	"Well6_Seq0006",
	"Well7_Seq0005",
	"Well8_Seq0004"
);
sites = newArray(
	"0", "1", "2"
);
timepoints = 160;
process_paths = newArray(
	"CP/OUT/DC/"
	//"channel-tifs/"
);
timepoints = 160;
max_time = 10;
time_cutoff = 5;

//channels = newArray("GFP", "CVC");
//luts = newArray("Cyan", "Magenta");
//merge_lut = newArray(5, 6);
//segment_image = newArray(false, true);
//make_binary = newArray(true, true);

channels = newArray("GFP");
luts = newArray("Grays");
merge_lut = newArray(5, 6);
segment_image = newArray(false, true);
make_binary = newArray(true, false);
pixel_size = 3.0769;

// save histogram values
hist_length = images.length * sites.length;
hist_dc = newArray(hist_length);
hist_dc_foci = newArray(hist_length);
hist_donor = newArray(hist_length);
hist_donor_foci = newArray(hist_length);
hist_dc_on_donor = newArray(hist_length);

// prepare
output_file = "hist";
if (process_paths.length > 1){
	output_file += "_with_donor";
}

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

		// go through process paths
		for (cur_process_path_id = 0; cur_process_path_id < process_paths.length; cur_process_path_id++){
			cur_process_path = base_path + process_paths[cur_process_path_id];
			cur_channel = channels[cur_process_path_id];
			
			cur_process_image =
				cur_image
				+ "_s" + cur_site
				+ "_t[0-9]*"
				+ "_c" + cur_channel;

			cur_output_file =
				cur_output_part
				+ "_n" + cur_process_path_id
				+ ".tif";

			// open sequence
			run("Image Sequence...",
				"open=" + cur_process_path + " file=(" + cur_process_image + ") sort use");

			// segment images
			if (segment_image[cur_process_path_id] == true) {
				// segment images
				run("Enhance Contrast", "saturated=0.35");
				run("8-bit");
				run("Gaussian Blur...", "sigma=5 stack");
				run("Convert to Mask", "method=Triangle background=Dark calculate black");
			}
			
			// make binary
			if (make_binary[cur_process_path_id] == true) {
				// duplicate, otherwise the value change does not work
				run("Duplicate...", "duplicate");
				
				for (i = 1; i <= nSlices; i++) {
					setSlice(i);
					changeValues(1, 255, 1);
				}

				run("Z Project...", "projection=[Sum Slices]");
				//run("8-bit");
				//setMinAndMax(0, max_time);

				// change values according to time cutoff
				changeValues(1, (time_cutoff - 1), 1);
				changeValues(time_cutoff, 255, 2);

				// smooth image
				run("Median...", "radius=5");
			} else {
			}
			
			// save image
			setMinAndMax(0, 255);
			call("ij.ImagePlus.setDefault16bitRange", 8);
			run("8-bit");
			saveAs("Tiff", output_path + cur_output_file);
			
			// close images
			run("Close All");
		}
		
		// calc histogram id
		cur_hist_id = (cur_image_id * sites.length) + cur_site_id;
		
		// prepare images for display
		merge_channels = "";
		for (cur_process_path_id = 0; cur_process_path_id < process_paths.length; cur_process_path_id++){
			// get image
			cur_file =
				cur_output_part
				+ "_n" + cur_process_path_id
				+ ".tif";

			cur_output_file =
				cur_output_part
				+ "_n" + cur_process_path_id
				+ "_disp.tif";
			
			open(output_path + cur_file);

			setMinAndMax(0, 2);
			call("ij.ImagePlus.setDefault16bitRange", 8);
			
			// create lut
			cur_lut = luts[cur_process_path_id];
			run(cur_lut);

			// save image
			run("Flatten");
			setMinAndMax(0, 2);
			saveAs("Tiff", output_path + cur_output_file);
			close();

			// save histogram values
			getHistogram(hist_values, hist_counts, 256);
			
			if (cur_process_path_id == 0) {
				hist_dc[cur_hist_id] = hist_counts[1] + hist_counts[2];
				hist_dc_foci[cur_hist_id] = hist_counts[2];
			} else {
				hist_donor[cur_hist_id] = hist_counts[1] + hist_counts[2];
				hist_donor_foci[cur_hist_id] = hist_counts[2];
			}
			
			// show only foci
			changeValues(1, 1, 0);
			changeValues(2, 2, 1);
			setMinAndMax(0, 1);
			call("ij.ImagePlus.setDefault16bitRange", 8);

			// rename
			rename(cur_process_path_id + ".tif");
			
			// add to merge
			merge_channels += "c" + merge_lut[cur_process_path_id] + "=" + cur_process_path_id + ".tif ";
		}

		if (process_paths.length > 1) {
			// calculate overlap
			imageCalculator("Multiply create", "0.tif", "1.tif");
			getHistogram(hist_values, hist_counts, 256);
			hist_dc_on_donor[cur_hist_id] = hist_counts[1];
			close();
			
			// merge and save
			run("Merge Channels...", merge_channels + "create");
			run("Flatten");
			saveAs("Tiff", output_path + cur_output_part + "_merge.tif");
		}

		run("Close All");
	}
}

// save histogram values
// open file
hist_out_path = output_path + output_file + ".csv";

// delete file
File.delete(hist_out_path);

// create new file
output_file = File.open(hist_out_path);

if (process_paths.length > 1) {
	print(output_file, "image,site,dc,dc_foci,donor,donor_foci,dc_on_donor");
} else {
	print(output_file, "image,site,dc,dc_foci");
}

// save values
for (cur_image_id = 0; cur_image_id < images.length; cur_image_id++){
	cur_image = images[cur_image_id];

	for (cur_site_id = 0; cur_site_id < sites.length; cur_site_id++){
		cur_site = sites[cur_site_id];
		cur_hist_id = (cur_image_id * sites.length) + cur_site_id;

		if (process_paths.length > 1) {
			print(output_file, cur_image + "," + cur_site
					+ "," + hist_dc[cur_hist_id]
					+ "," + hist_dc_foci[cur_hist_id]
					+ "," + hist_donor[cur_hist_id]
					+ "," + hist_donor_foci[cur_hist_id]
					+ "," + hist_dc_on_donor[cur_hist_id]
					);
		} else {
			print(output_file, cur_image + "," + cur_site
					+ "," + hist_dc[cur_hist_id]
					+ "," + hist_dc_foci[cur_hist_id]
					);
		}
	}
}

File.close(output_file);