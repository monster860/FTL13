/turf // A few vars shadowcasting needs
	var/shadowcast_inview
	var/shadowcast_considered
	var/has_opaque = 1

/proc/transform_triangle(x1, y1, x2, y2, x3, y3, icon_size=32)
	// The way this works is it multiplies a matrix containing the desired list
	// of points by the inverse of the matrix containing the list of triangle
	// points on the original icon. The advantage of this method is that it
	// allows you to draw a triangle really fast, but one of the edges ends up
	// being really fuzzy.
	var/i = 1/icon_size
	var/a = (x3*i)-(x2*i)
	var/b = -(x2*i)+(x1*i)
	var/c = (x3*0.5)+(x1*0.5)
	var/d = (y1*i)-(y2*i)
	var/e = -(y2*i)+(y3*i)
	var/f = (y1*0.5)+(y3*0.5)
	return matrix(a,b,c,e,d,f)

// Datums are faster than lists
/datum/triangle
	var/x1
	var/x2
	var/x3
	var/y1
	var/y2
	var/y3

/datum/triangle/New(x1,y1,x2,y2,x3,y3)
	src.x1 = x1
	src.x2 = x2
	src.x3 = x3
	src.y1 = y1
	src.y2 = y2
	src.y3 = y3

//var/list/triangle_images = list()
var/image/shadowcast_enabler

/proc/make_triangle_image(x1,y1,x2,y2,x3,y3, l = FLOAT_LAYER)
	var/image/triangle_image = new /mutable_appearance()
	triangle_image.icon = 'icons/effects/triangle.dmi'
	triangle_image.icon_state = ""
	triangle_image.layer = l
	triangle_image.transform = transform_triangle(x1,y1,x2,y2,x3,y3)
	return triangle_image.appearance

/proc/create_shadowcast_overlays(turf/locturf, atom/objatom)
	var/vrange = 7
	// Handles almost every edge case there is.
	var/moveid = rand(0,65535)
	var/list/new_overlays = list()

	var/timer = world.tick_usage

	for(var/turf/T in view(vrange))
		T.shadowcast_inview = moveid
		if(T.opacity)
			T.has_opaque = 1
		else
			T.has_opaque = 0
			if(T.contents.len)
				for(var/A in T.contents)
					var/atom/movable/AM = A
					if(AM.opacity)
						T.has_opaque = 1
						break

	to_chat(world, "View: [world.tick_usage-timer]")

	var/list/vturfsordered = list()
	for(var/I in 1 to (vrange*2))
		for(var/J in 1 to I)
			vturfsordered += locate(locturf.x + I - J, locturf.y - J, locturf.z)
			vturfsordered += locate(locturf.x - I + J, locturf.y + J, locturf.z)
			vturfsordered += locate(locturf.x + J, locturf.y + I - J, locturf.z)
			vturfsordered += locate(locturf.x - J, locturf.y - I + J, locturf.z)

	to_chat(world, "Vturfs: [world.tick_usage-timer]")

	if(shadowcast_enabler == null)
		shadowcast_enabler = image(icon = 'icons/effects/alphacolors.dmi', icon_state = "white", layer = 18)

	var/list/low_triangles = list()

	for(var/turf/T in vturfsordered)
		if(T.shadowcast_inview != moveid || T == locturf || !T.has_opaque || T.shadowcast_considered == moveid)
			continue
		var/odx = (T.x - locturf.x)
		var/ody = (T.y - locturf.y)
		var/dx = odx*32
		var/dy = ody*32
		var/signx = (dx>=0)?1:-1
		var/signy = (dy>=0)?1:-1
		var/zx = dx == 0
		var/zy = dy == 0
		var/L = abs(odx)+abs(ody)
		var/udir = (dy>=0?1:2)
		var/rdir = (dx>=0?4:8)
		var/width = 0
		var/height = 0
		if(zx || zy)
			width = 1
			height = 1
			if(zx)
				var/turf/CT = get_step(T, 4)
				while(CT && CT.has_opaque && abs(CT.x-locturf.x)<(vrange+2))
					CT.shadowcast_considered = moveid
					width++
					CT = get_step(CT, 4)
				CT = get_step(T, 8)
				while(CT && CT.has_opaque && abs(CT.x-locturf.x)<(vrange+2))
					CT.shadowcast_considered = moveid
					width++
					dx -= 32
					CT = get_step(CT, 8)
				var/cdir = dy>0?2:1
				CT = get_step(T,cdir)
				if(CT && CT.has_opaque)
					continue
				cdir = dy>0?1:2
				CT = T
				while(CT && abs(CT.y - locturf.y))
					CT.shadowcast_considered = moveid
					CT = get_step(CT,udir)
			if(zy)
				var/turf/CT = get_step(T, 1)
				while(CT && CT.has_opaque && abs(CT.y-locturf.y)<(vrange+2))
					CT.shadowcast_considered = moveid
					height++
					CT = get_step(CT, 1)
				CT = get_step(T, 2)
				while(CT && CT.has_opaque && abs(CT.y-locturf.y)<(vrange+2))
					CT.shadowcast_considered = moveid
					height++
					dy -= 32
					CT = get_step(CT, 2)
				var/cdir = dx>0?8:4
				CT = get_step(T,cdir)
				if(CT && CT.has_opaque)
					continue
				cdir = dx>0?4:8
				CT = T
				while(CT && abs(CT.x - locturf.x))
					CT.shadowcast_considered = moveid
					CT = get_step(CT,rdir)
		else
			var/turf/CT = T
			while(CT && CT.has_opaque && abs(CT.x-locturf.x)<(vrange+2))
				CT.shadowcast_considered = moveid
				width++
				CT = get_step(CT, rdir)

			CT = T
			while(CT && CT.has_opaque && abs(CT.y-locturf.y)<(vrange+2))
				CT.shadowcast_considered = moveid
				height++
				CT = get_step(CT, udir)

		if(zx || zy)
			shadowcast_enabler.transform = matrix(width,0,(width-1)*16*signx+dx,0,height,(height-1)*16*signy+dy)
			new_overlays += shadowcast_enabler.appearance

		var/top = dy-(signy*16)+(signy*32*height)
		var/bottom = dy-(signy*16)
		var/left = dx-(signx*16)
		var/right = dx-(signx*16)+(signx*32*width)

		var/fac = 32/L
		if(zy)
			low_triangles += new /datum/triangle(left, top, left, bottom, left*fac, bottom*fac)
			low_triangles += new /datum/triangle(left*fac,top*fac,left,top,left*fac,bottom*fac)
		else if(zx)
			low_triangles += new /datum/triangle(right, bottom, left, bottom, left*fac, bottom*fac)
			low_triangles += new /datum/triangle(left*fac,bottom*fac,right,bottom,right*fac,bottom*fac)
		else
			new_overlays += make_triangle_image(right,top,left,top,left*fac,top*fac,19)
			new_overlays += make_triangle_image(right,top,right,bottom,right*fac,bottom*fac,19)
			new_overlays += make_triangle_image(left*fac,top*fac,right,top,right*fac,bottom*fac,19)

	for(var/datum/triangle/T in low_triangles)
		new_overlays += make_triangle_image(T.x1,T.y1,T.x2,T.y2,T.x3,T.y3,17)

	objatom.overlays = new_overlays
	to_chat(world, "Everything else: [world.tick_usage-timer]")
	to_chat(world, "Overlay count: [objatom.overlays.len]")

/client
	var/image/opacity_image
	var/atom/movable/opacity_obj

/datum/hud/proc/create_opacity_image()
	var/client/C = mymob.client
	if(!C.opacity_image)
		C.opacity_image = image(loc = get_step(src,0))
		C.opacity_image.appearance_flags = KEEP_TOGETHER
		C.opacity_image.blend_mode = BLEND_MULTIPLY
		C.opacity_obj = new
		C.opacity_obj.animate_movement = NO_STEPS // No gliding
		C.opacity_obj.verbs.Cut()

	C.opacity_image.loc = C.opacity_obj
	C.opacity_image.overlays.Cut()
	C.images |= C.opacity_image

/datum/hud/proc/update_opacity()
	var/client/C = mymob.client
	var/mob/M = C.eye
	var/turf/T = get_turf(C.eye)
	C.opacity_obj.loc = T
	if(M.sight & (SEE_TURFS|SEE_OBJS|SEE_MOBS|BLIND)) // If you have snowflakey sight flags, then you're stuck with default byond invisibility
		C.opacity_image.overlays.Cut()
	else
		create_shadowcast_overlays(T, C.opacity_image)
