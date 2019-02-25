//---
function concat_movie_boxes(output, frames, well, site, track_id) {
	name_for_box = "cur_movie_box";
	concat_string = "";

	if (show_last_frame_only == true) {
		selectWindow(movie_box_prefix + frames);

		// save as TIFF
		saveAs("Tiff",
			output + "w" + well + "_s" + site + "_i" + track_id + ".tif");
	} else {
		for (i = 0; i <= frames; i++){
			concat_string += "image" + (i+1) + "=" + movie_box_prefix + i + " ";
		}

		run("Concatenate...", concat_string);

		// save as AVI
		run("AVI... ",
			"compression=JPEG frame=10 save=" +
			output + "w" + well + "_s" + site + "_i" + track_id + ".avi");

		if (save_tiff == true) {
			saveAs("Tiff",
				output + "w" + well + "_s" + site + "_i" + track_id + ".tif");
		}
	}
	
	close();
}

function calc_distance(x1, y1, x2, y2, factor) {
	a = abs(x1 - x2);
	b = abs(y1 - y2);

	c = sqrt(pow(a, 2) + pow(b, 2));

	// calculate factor
	c *= factor;
	
	return c;
}

function get_box_around_centre(x, y, box_size) {
	getDimensions(img_width, img_height, img_channels, img_slices, img_frames);
	
	rect = newArray(2);
	
	rect[0] = x - (0.5 * box_size);
	rect[1] = y - (0.5 * box_size);

	if (rect[0] < 0){
		rect[0] = 0;
	}
	if (rect[1] < 0){
		rect[1] = 0;
	}

	if (rect[0] + box_size > img_width){
		rect[0] = img_width - box_size;
	}
	if (rect[1] + box_size > img_height){
		rect[1] = img_height - box_size;
	}

	return rect;
}

function create_final_window(frames, min_x, min_y, max_x, max_y, box_size, box_frame, prefix){
	selectWindow("merged");
	getDimensions(img_width, img_height, img_channels, img_slices, img_frames);

	// adjust to frame
	min_x -= box_frame;
	min_y -= box_frame;

	max_x += box_frame;
	max_y += box_frame;

	if (min_x < 0) {
		min_x = 0;
	}
	if (min_y < 0) {
		min_y = 0;
	}

	if (max_x > img_width) {
		max_x = img_width;
	}
	if (max_y > img_height) {
		max_y = img_height;
	}
	
	width = max_x - min_x;
	height = max_y - min_y;

	// make a square
	if (width > height) {
		height = width;
	} else{
		width = height;
	}

	// adjust to box size
	if (width < box_size) {
		width = box_size;
	}

	if (height < box_size) {
		height = box_size;
	}

	// avoid squishing against the border
	if (min_x + width > img_width){
		min_x = img_width - width;
	}

	if (min_y + height > img_height){
		min_y = img_height - height;
	}
	
	makeRectangle(min_x, min_y, width, height);
	run("Duplicate...", "title=[" + prefix + (frames + 1) + "] ");
	
	if (show_links == true || show_start_finish_spots == true){
		rename("pre");
		Overlay.flatten;
	}
		
	rename(prefix + (frames + 1));

	if (show_links == true || show_start_finish_spots == true){
		selectWindow("pre");
		close();
	}
	
	run("Size...",
	"width=" + box_size + " height=" + box_size + " constrain average interpolation=Bilinear");
}
//---
base_path = "/Users/dominiks/Desktop/ANALYSIS/N4/";
analysis_path = "/ANALYSIS/";
input_path = "TRACKING_DC/";
output_path = "TRACKING_DC_CVC_INDV/";
//input_ext = "-spots_cvc.csv";
input_ext = "-spots.csv";
csv_separator = ",";

// experiment
experiments = newArray(
	"N4-2-13"
);
wells = newArray(
	"7", "6", "5"
);
sites = newArray(
	"0", "1", "2"
);

timepoints = 160;
time_pattern = "_t.*";

//tif_channels = newArray('GFP');
//luts = newArray(5);
//lut = "Cyan";
tif_channels = newArray('GFP', 'CVC');
luts = newArray(5, 6);

channels = (tif_channels.length);

time_interval = 360;
time_factor = 3;
pixel_size = 0.325
show_last_frame_only = false;
show_sampling_spots = false;
show_start_finish_spots = false;
show_links = false;
save_tiff = true;
show_dots = true;

// movie boxes
movie_box_prefix = "rect";
movie_box_size = 400;
movie_box_window = 300;
//movie_box_size = 150;
//movie_box_window = 50;
movie_spot_size = 10;
movie_box_frame = (movie_box_size - movie_box_window) / 2;

line_width_segment = 5;
line_colour = "Yellow";
spot_colour = "Orange";
sampling_spot_colour = "White";
sampling_spot_size = 20;
sampling_spot_width = 5;
start_spot_colour = "Orange";
start_spot_size = 10;
start_spot_width = 10;
finish_spot_colour = "Orange";
finish_spot_size = 40;
finish_spot_width = 5;

// csv positions
csv_track_id = 2;
csv_pos_x = 4;
csv_pos_y = 5;
csv_frame = 8;
csv_is_cvc_pos = 21;

setBatchMode(true);

// go through experiments
for (cur_exp_id = 0; cur_exp_id < experiments.length; cur_exp_id++) {
	cur_exp = experiments[cur_exp_id];
	print(">> CUR EXP " + cur_exp);

	cur_base_path = base_path + cur_exp + analysis_path;
	cur_path_tif = cur_base_path + "channel-tifs/";
	cur_path_seg = cur_base_path + "CP/OUT/DC/";
	cur_path_input = cur_base_path + input_path;
	cur_path_output = cur_base_path + output_path;
	
	// go through images
	for (cur_well_id = 0; cur_well_id < wells.length; cur_well_id++){
		cur_well = wells[cur_well_id];
		print(">> CUR WELL " + cur_well_id + "/" + wells.length);
		
		// go through sites
		for (cur_site_id = 0; cur_site_id < sites.length; cur_site_id++){
			cur_site = sites[cur_site_id];
			print(">> CUR SITE " + cur_site_id + "/" + sites.length);

			cur_image_pattern = "Well" + cur_well + ".*s" + cur_site + time_pattern + ".*";
			
			merge_channels = "";
	
			// open tifs
			for (cur_tif_id = 0; cur_tif_id < tif_channels.length; cur_tif_id++){
				cur_tif_channel = tif_channels[cur_tif_id];
				
				run("Image Sequence...",
				"open=" + cur_path_tif + " file=(" + cur_image_pattern + "_c" + cur_tif_channel + ") sort use");
	
				run("Enhance Contrast", "saturated=0.35");
				
				// change bit
				run("8-bit");
				
				// add to merge		
				rename(cur_tif_id + ".tif");
				merge_channels += "c" + luts[cur_tif_id] + "=" + cur_tif_id + ".tif ";
			}
	
			// merge channels
			if (tif_channels.length > 1) {
				run("Merge Channels...", merge_channels + "create ignore");
			} else {
				run(lut);
			}
			
			// adjust properties
			run("Properties...",
			"channels=" + channels + " slices=1 frames=" + timepoints + " unit=pixel"
			+ " pixel_width=" + pixel_size + " pixel_height=" + pixel_size + " voxel_depth=" + pixel_size);
	
			// flatten
			if (tif_channels.length > 1) {
				run("Flatten");
			}
			rename("merged");

			// open tracks
			cur_tracks_file = cur_path_input + "w" + cur_well + "_s" + cur_site + input_ext;
			
			// open file
			filestring = File.openAsString(cur_tracks_file);

			// split rows
			rows = split(filestring, "\n");

			// go through tracks, duplicate box and create image stack
			last_track_id = -1;
			last_pos_x = -1;
			last_pos_y = -1;
			last_rect = newArray(2);
			frame_counter = 0;

			// init min and max for final window
			getDimensions(img_width, img_height, img_channels, img_slices, img_frames);
			fw_min_x = img_width;
			fw_min_y = img_height;
			fw_max_x = 0;
			fw_max_y = 0;
			
			for(i = 1; i < rows.length; i++){
				// split into columns
				columns = split(rows[i], csv_separator);

				// extract columns
				cur_track_id = parseInt(columns[csv_track_id]);
				cur_pos_x = parseInt(columns[csv_pos_x]) / pixel_size;
				cur_pos_y = parseInt(columns[csv_pos_y]) / pixel_size;
				cur_frame = parseInt(columns[csv_frame]) + 1;

				if (show_sampling_spots == true) {
					cur_is_cvc_ps = parseInt(columns[csv_is_cvc_pos]);
				}
				
				if (cur_track_id > last_track_id) {
					if (frame_counter > 0){
						if (show_start_finish_spots == true) {
							setColor(finish_spot_colour);
							setLineWidth(finish_spot_width);
							Overlay.drawEllipse(
								last_pos_x - (0.5*finish_spot_size),
								last_pos_y - (0.5*finish_spot_size),
								finish_spot_size, finish_spot_size);
							Overlay.add;
							Overlay.show;
						}
						
						// create final window
						create_final_window(
							frame_counter, fw_min_x, fw_min_y, fw_max_x, fw_max_y,
							movie_box_size, movie_box_frame, movie_box_prefix);
						frame_counter += 1;
						
						concat_movie_boxes(cur_path_output,
							frame_counter, cur_well, cur_site, last_track_id);

						// delete overlay
						selectWindow("merged");
						Overlay.remove;
					}
					
					frame_counter = 0;

					// reset final window
					fw_min_x = img_width;
					fw_min_y = img_height;
					fw_max_x = 0;
					fw_max_y = 0;
				} else {
					frame_counter++;
				}

				// set final window
				if (cur_pos_x < fw_min_x) {
					fw_min_x = cur_pos_x;
				}
				if (cur_pos_y < fw_min_y) {
					fw_min_y = cur_pos_y;
				}

				if (cur_pos_x > fw_max_x) {
					fw_max_x = cur_pos_x;
				}
				if (cur_pos_y > fw_max_y) {
					fw_max_y = cur_pos_y;
				}
				
				// select merged image
				selectWindow("merged");
				setSlice(cur_frame);

				// draw line to previous cell
				if (frame_counter > 0) {
					if (show_links == true){
						setColor(line_colour);
						// get distance
						cur_dist = calc_distance(
							last_pos_x, last_pos_y, cur_pos_x, cur_pos_y, pixel_size);
						setLineWidth(floor(cur_dist/line_width_segment));
						Overlay.drawLine(last_pos_x, last_pos_y, cur_pos_x, cur_pos_y);
						Overlay.add;
					}
					
					// show sampling spot
					if (show_sampling_spots == true) {
						if (cur_is_cvc_ps > 0) {
							setColor(sampling_spot_colour);
							setLineWidth(sampling_spot_width);
							Overlay.drawEllipse(
								cur_pos_x - (0.5*sampling_spot_size),
								cur_pos_y - (0.5*sampling_spot_size),
								sampling_spot_size, sampling_spot_size);
							Overlay.add;
						}
					}

					Overlay.show;
				} else {
					if (show_start_finish_spots == true) {
						setColor(start_spot_colour);
						setLineWidth(start_spot_width);
						Overlay.drawEllipse(
							cur_pos_x - (0.5*start_spot_size),
							cur_pos_y - (0.5*start_spot_size),
							start_spot_size, start_spot_size);
						Overlay.add;

						Overlay.show;
					}
				}

				// check if the window needs to be repositioned
				cur_rect = newArray(last_rect[0], last_rect[1]);
				if (frame_counter > 0){
					if (cur_pos_x < (last_rect[0] + movie_box_frame)) {
						cur_rect[0] = cur_pos_x - movie_box_frame;
					}
					if (cur_pos_y < (last_rect[1] + movie_box_frame)) {
						cur_rect[1] = cur_pos_y - movie_box_frame;
					}
					if (cur_pos_x > (last_rect[0] + movie_box_frame + movie_box_window)) {
						cur_rect[0] = cur_pos_x - (movie_box_window + movie_box_frame);
					}
					if (cur_pos_y > (last_rect[1] + movie_box_frame + movie_box_window)) {
						cur_rect[1] = cur_pos_y - (movie_box_window + movie_box_frame);
					}
				}
				
				// get rectangle coordinates around centre
				if (frame_counter == 0) {
					cur_rect = get_box_around_centre(cur_pos_x, cur_pos_y, movie_box_size);
				}

				if (show_last_frame_only != true) {
					// draw rectangle and duplicate
					makeRectangle(cur_rect[0], cur_rect[1], movie_box_size, movie_box_size);
					run("Duplicate...", "title=[pre" + frame_counter + "] ");
	
					// flatten tracks
					if (frame_counter > 0) {
						if (show_links == true || show_start_finish_spots == true){
							rename("pre");
							Overlay.flatten;
						}
						rename("pre" + frame_counter);
						if (show_links == true || show_start_finish_spots == true){
							selectWindow("pre");
							close();
						}
					}

					if (show_dots == true){
						// add spot
						setColor(spot_colour);
						fillOval(
							cur_pos_x - cur_rect[0] - (0.5*movie_spot_size),
							cur_pos_y - cur_rect[1] - (0.5*movie_spot_size),
							movie_spot_size, movie_spot_size);
					}		
					run("Flatten");
					rename(movie_box_prefix + frame_counter);
	
					// close window
					selectWindow("pre" + frame_counter);
					close();
				}
				
				// reset params for next round
				last_track_id = cur_track_id;
				last_pos_x = cur_pos_x;
				last_pos_y = cur_pos_y;
				last_rect = cur_rect;
			}

			if (frame_counter > 0){
				if (show_start_finish_spots == true) {
					setColor(finish_spot_colour);
					setLineWidth(finish_spot_width);
					Overlay.drawEllipse(
						cur_pos_x - (0.5*finish_spot_size),
						cur_pos_y - (0.5*finish_spot_size),
						finish_spot_size, finish_spot_size);
					Overlay.add;
					Overlay.show;
				}
				
				// create final window
				create_final_window(
					frame_counter, fw_min_x, fw_min_y, fw_max_x, fw_max_y,
					movie_box_size, movie_box_frame, movie_box_prefix);
				frame_counter += 1;
				
				concat_movie_boxes(
					cur_path_output, frame_counter, cur_well,
					cur_site, cur_track_id);
			}

			run("Close All");
		}
	}
}