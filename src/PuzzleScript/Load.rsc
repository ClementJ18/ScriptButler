module PuzzleScript::Load

import PuzzleScript::Syntax;
import PuzzleScript::AST;
import ParseTree;
import List;
import String;

PSGAME load(loc path) {
	return ps_implode(ps_parse(path));
}

PSGAME load(str src) {
	return ps_implode(ps_parse(src));
}

PSGame ps_parse(loc path){
	return annotate(parse(#PSGame, path));
}

PSGame ps_parse(str src){
	return annotate(parse(#PSGame, src));
}

PSGame ps_parse(str psString, loc psFile) { 
	return annotate(parse(#PSGame, psString, psFile));
}

PSGAME ps_implode(PSGame tree) {
	return post(implode(#PSGAME, tree));
}

PSGame annotate(PSGame tree) {
	return tree;
}

LEGENDDATA process_legend(LEGENDDATA l) {
	str legend = l.legend;
	list[str] values = [l.first];
	list[str] aliases = [];
	list[str] combined = [];
	
	for (LEGENDOPERATION other <- l.others) {
		switch(other){
			case legend_or(id): aliases += id;
			case legend_and(id): combined += id;
		}
	}
	
	LEGENDDATA new_l = legend_alias(legend, values + aliases);
	if (size(aliases) > 0 && size(combined) > 0) {
		new_l = legend_error(legend, values + aliases + combined);
	} else if (size(combined) > 0) {
		new_l = legend_combined(legend, values + combined);
	}
	new_l @ location = l@location;
	new_l @ label = "Legend: <l.legend>";
	return new_l;
}

OBJECTDATA process_object(OBJECTDATA obj){
	list[list[PIXEL]] sprite_line = [];
	
	if (size(obj.spr) > 0) {;
		sprite_line += [
			[pixel(x) | x <- split("", obj.spr[0].line0)],
			[pixel(x) | x <- split("", obj.spr[0].line1)],
			[pixel(x) | x <- split("", obj.spr[0].line2)],
			[pixel(x) | x <- split("", obj.spr[0].line3)],
			[pixel(x) | x <- split("", obj.spr[0].line4)]
		];
		
		for (int i <- [0..size(sprite_line)]){
			for (int j <- [0..size(sprite_line[i])]){
				try
					sprite_line[i][j] @ color = toLowerCase(obj.colors[toInt(sprite_line[i][j].pixel)]);
				catch: sprite_line[i][j] @ color = "unknown";
			}
		}
	}
	
	OBJECTDATA new_obj = object_data(obj.id, obj.legend, obj.colors, sprite_line);
	new_obj @ location = obj@location;
	new_obj @ label = "Object <obj.id>";
	return new_obj;
}

LAYERDATA process_layer(LAYERDATA l) {
	LAYERDATA new_l = layer_data(l.layer);
	new_l @ location = l@location;
	new_l @ label = "Layer";
	return new_l;
}

LEVELDATA process_level(LEVELDATA l) {
	switch(l) {
		case message(_): {
			l @ label = "Message";
			return l;
		}
		case level_data_raw(list[tuple[str, str]] lines): {
			LEVELDATA new_l = level_data([x[0] | x <- lines]);
			new_l @ location = l@location;
			new_l @ label = "Level";
			return new_l;
		}
	}
	
	return l;
}

PSGAME post(PSGAME game) {
	// do post processing here
	list[OBJECTDATA] objects = [];
	list[LEGENDDATA] legends = [];
	list[tuple[SOUNDDATA sound, str lines]] sounds = [];
	list[LAYERDATA] layers = [];
	list[RULEDATA] rules = [];
	list[CONDITIONDATA] conditions = [];
	list[LEVELDATA] levels = [];
	list[PRELUDEDATA] pr = [];
	
	// assign to correct section
	for (SECTION section <- game.sections) {
		switch(section) {
			case SECTION::objects(objs): objects = objs.objects;
			case SECTION::legend(lgd): legends = lgd.legend;
			case SECTION::sounds(snd): sounds = snd.sounds;
			case SECTION::layers(lyrs): layers = lyrs.layers;
			case SECTION::rules(rls): rules = rls.rules;
			case SECTION::conditions(cnd): conditions = cnd.conditions;
			case SECTION::levels(lvl): levels = lvl.levels;
		
		}
	}
	
	//fix sprite
	processed_objects = [];
	for (OBJECTDATA obj <- objects){
		switch(obj){
			case object_data(_, _, _, _, _, _): 
				processed_objects += process_object(obj);
		}
	}
	
	// validate legends and process
	processed_legends = [process_legend(l) | LEGENDDATA l <- legends];
	
	//untuple sounds
	processed_sounds = [s.sound | tuple[SOUNDDATA sound, str lines] s <- sounds];
	
	//unnest layers
	processed_layers = [process_layer(l) | LAYERDATA l <- layers];
	
	//unest levels
	processed_levels = [process_level(l) | LEVELDATA l <- levels];
	
	if (!isEmpty(game.pr)) pr = game.pr[0].datas;
	
	PSGAME new_game = PSGAME::game(
		pr, 
		processed_objects, 
		processed_legends, 
		processed_sounds, 
		processed_layers, 
		rules, 
		conditions, 
		processed_levels, 
		game.sections
	);
	
	return new_game[@location = game@location];
}