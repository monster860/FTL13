/turf
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

var/list/triangle_images = list()

/proc/make_triangle_image(x1,y1,x2,y2,x3,y3, p = FLOAT_PLANE, l = FLOAT_LAYER)
	var/strid = "[x1],[y1],[x2],[y2],[x3],[y3],[p],[l]"
	var/image/I = triangle_images[strid]
	if(I)
		return I
	I = new(icon = 'icons/effects/triangle.dmi', icon_state = "", layer = l)
	I.transform = transform_triangle(x1,y1,x2,y2,x3,y3)
	I.plane = p
	I.color = "#000000"
	triangle_images[strid] = I
	return I

/proc/create_shadowcast_overlays(turf/locturf, atom/objatom)
	var/vrange = 7
	// Handles almost every edge case there is.
	var/moveid = rand(0,65535)
	var/list/new_overlays = list()

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

	var/list/vturfsordered = list()
	for(var/I in 1 to (vrange*2))
		for(var/J in 1 to I)
			vturfsordered += locate(locturf.x + I - J, locturf.y - J, locturf.z)
			vturfsordered += locate(locturf.x - I + J, locturf.y + J, locturf.z)
			vturfsordered += locate(locturf.x + J, locturf.y + I - J, locturf.z)
			vturfsordered += locate(locturf.x - J, locturf.y - I + J, locturf.z)
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
				var/cdir = dy>0?2:1
				var/turf/CT = get_step(T,cdir)
				if(CT && CT.has_opaque)
					continue
				cdir = dy>0?1:2
				CT = T
				while(CT && abs(CT.y - locturf.y))
					CT.shadowcast_considered = moveid
					CT = get_step(CT,cdir)
			if(zy)
				var/cdir = dx>0?8:4
				var/turf/CT = get_step(T,cdir)
				if(CT && CT.has_opaque)
					continue
				cdir = dx>0?4:8
				CT = T
				while(CT && abs(CT.x - locturf.x))
					CT.shadowcast_considered = moveid
					CT = get_step(CT,cdir)
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
			var/image/enabler = image(icon = 'icons/effects/alphacolors.dmi', icon_state = "white", layer = 18)
			enabler.transform = matrix(width,0,(width-1)*16*signx+dx,0,height,(height-1)*16*signy+dy)
			new_overlays += enabler

		var/top = dy-(signy*16)+(signy*32*height)
		var/bottom = dy-(signy*16)
		var/left = dx-(signx*16)
		var/right = dx-(signx*16)+(signx*32*width)

		var/fac = 32/L
		if(zy)
			var/turf/CT = get_step(T, 1)
			if(CT && CT.has_opaque)
				var/image/enabler = image(icon = 'icons/effects/alphacolors.dmi', icon_state = "white", layer = 18)
				enabler.transform = matrix(1,0,dx,0,1,dy+32)
				new_overlays += enabler
			CT = get_step(T, 2)
			if(CT && CT.has_opaque)
				var/image/enabler = image(icon = 'icons/effects/alphacolors.dmi', icon_state = "white", layer = 18)
				enabler.transform = matrix(1,0,dx,0,1,dy-32)
				new_overlays += enabler
			new_overlays += make_triangle_image(left, top, left, bottom, left*fac, bottom*fac, 0, 17)
			new_overlays += make_triangle_image(left*fac,top*fac,left,top,left*fac,bottom*fac, 0, 17)
		else if(zx)
			var/turf/CT = get_step(T, 4)
			if(CT && CT.has_opaque)
				var/image/enabler = image(icon = 'icons/effects/alphacolors.dmi', icon_state = "white", layer = 18)
				enabler.transform = matrix(1,0,dx+32,0,1,dy)
				new_overlays += enabler
			CT = get_step(T, 8)
			if(CT && CT.has_opaque)
				var/image/enabler = image(icon = 'icons/effects/alphacolors.dmi', icon_state = "white", layer = 18)
				enabler.transform = matrix(1,0,dx-32,0,1,dy)
				new_overlays += enabler
			new_overlays += make_triangle_image(right, bottom, left, bottom, left*fac, bottom*fac, 0, 17)
			new_overlays += make_triangle_image(left*fac,bottom*fac,right,bottom,right*fac,bottom*fac, 0, 17)
		else
			new_overlays += make_triangle_image(right,top,left,top,left*fac,top*fac, 0,19)
			new_overlays += make_triangle_image(right,top,right,bottom,right*fac,bottom*fac, 0,19)
			new_overlays += make_triangle_image(left*fac,top*fac,right,top,right*fac,bottom*fac,0,19)
	objatom.overlays = new_overlays

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