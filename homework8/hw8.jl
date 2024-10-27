### A Pluto.jl notebook ###
# v0.19.45

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ c3e52bf2-ca9a-11ea-13aa-03a4335f2906
begin
	import Pkg
	Pkg.activate(mktempdir())
	Pkg.add([
			Pkg.PackageSpec(name="Plots", version="1.6-1"),
			Pkg.PackageSpec(name="PlutoUI", version="0.6.8-0.6"),
			Pkg.PackageSpec(name="ImageMagick"),
			Pkg.PackageSpec(name="Images", version="0.23"),
			])
	Pkg.add("FLoops")
	using Plots
	using PlutoUI
	using LinearAlgebra
	using Images
	using FLoops  
end

# ╔═╡ 1df32310-19c4-11eb-0824-6766cd21aaf4
md"_homework 8, version 1_"

# ╔═╡ 1e109620-19c4-11eb-013e-1bc95c14c2ba
md"""

# **Bonus homework 8**: _Raytracing in 3D_
`18.S191`, fall 2020

This week we will recreate the 3D raytracer from the lectures, building on what we wrote for the 2D case. Compared to the past weeks, you will notice that this homework is a little different! We have included fewer intermediate checks, it is up to you to decide how you:
- split up the problem is smaller functions
- check and visualize your progress

To guide you through the homework, you can follow along with this week's live coding session. Feel free to stay close to James's code, or to come up with your own solution.

With the raytracer done, we will be able to recreate an artwork by M.C. Escher, scroll down to have a sneak peek!

---

_For MIT students:_ this homework is **optional**.

Feel free to ask questions!
"""

# ╔═╡ 1e202680-19c4-11eb-29a7-99061b886b3c
# edit the code below to set your name and kerberos ID (i.e. email without @mit.edu)

student = (name = "Maaz Saeed", kerberos_id = "jazz")

# you might need to wait until all other cells in this notebook have completed running. 
# scroll around the page to see what's up

# ╔═╡ 1df82c20-19c4-11eb-0959-8543a0d5630d
md"""

Submission by: **_$(student.name)_** ($(student.kerberos_id)@mit.edu)
"""

# ╔═╡ e4d2f6f6-2089-11eb-0b4a-0d22f72f72ba
html"""
<h4>Lecture</h4>
<iframe width="100%" height="360" src="https://www.youtube.com/embed/JwyQezsQkkw" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
<h4>Live coding session</h4>
<iframe width="100%" height="360" src="https://www.youtube.com/embed/TGrqQEtudks" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>

"""

# ╔═╡ 1e2cd0b0-19c4-11eb-3583-0b82092139aa
md"_Let's create a package environment:_"

# ╔═╡ 315c6c55-4851-44b3-92d1-4cfc5b610706


# ╔═╡ e5a8efc1-312a-4069-82d3-7a353c875382
begin
	# Testing floops
    @floop for i in 1:10
        println(i)
    end
end


# ╔═╡ 4e917968-1f87-11eb-371f-e3899b76dc24
md"""
## From the last homework

Below we have included some important functions from the last homework (_Raytracing in 2D_), which we will be able to re-use for the 3D case.

There are some small changes:
1. The concept of a `Photon` now carries **color information**.
2. The `Sphere` is no longer a pure lens, it contains a `Surface` property which describes the mixture between transmission, reflection and a pure color. More on this later!
3. The `refract` function is updated to handle two edge cases, but its behaviour is generally unchanged.

Outside of these changes, all functions from the previous homework can be taken "as-is" when converting to 3D, cool!
"""

# ╔═╡ 24b0d4ba-192c-11eb-0f66-e77b544b0510
struct Photon
	"Position vector"
	p::Vector{Float64}

	"Direction vector"
	l::Vector{Float64}

	"Color associated with the photon"
	c::RGB
	
	ior::Real
end

# ╔═╡ c6e8d30e-205c-11eb-271c-6165a164073d
md"""
#### Intersections:
"""

# ╔═╡ d851a202-1ca0-11eb-3da0-51fcb656783c
abstract type Object end

# ╔═╡ 8acef4b0-1a09-11eb-068d-79a259244ed1
struct Miss end

# ╔═╡ 8018fbf0-1a05-11eb-3032-95aae07ca78f
struct Intersection{T<:Object}
	object::T
	distance::Float64
	point::Vector{Float64}
end

# ╔═╡ fcde90ca-2048-11eb-3e96-f9f47b6154e8
begin
	Base.isless(a::Miss, b::Miss) = false
	Base.isless(a::Miss, b::Intersection) = false
	Base.isless(a::Intersection, b::Miss) = true
	Base.isless(a::Intersection, b::Intersection) = a.distance < b.distance
end

# ╔═╡ dc36ceaa-205c-11eb-169c-bb4c36aaec9f
md"""
#### Reflect and refract:
"""

# ╔═╡ 43306bd4-194d-11eb-2e30-07eabb8b29ef
reflect(ℓ₁::Vector, n̂::Vector)::Vector = normalize(ℓ₁ - 2 * dot(ℓ₁, n̂) * n̂)

# ╔═╡ 14dc73d2-1a0d-11eb-1a3c-0f793e74da9b
function refract(
		ℓ₁::Vector, n̂::Vector,
		old_ior, new_ior
	)
	
	r = old_ior / new_ior
	
	n̂_oriented = if -dot(ℓ₁, n̂) < 0
		-n̂
	else
		n̂
	end
	
	c = -dot(ℓ₁, n̂_oriented)
	
	if abs(c) > 0.999
		ℓ₁
	else
		f = 1 - r^2 * (1 - c^2)
		if f < 0
			ℓ₁
		else
			normalize(r * ℓ₁ + (r*c - sqrt(f)) * n̂_oriented)
		end
	end
end

# ╔═╡ 7f0bf286-2071-11eb-0cac-6d10c93bab6c
md"""
#### Surface (new)
"""

# ╔═╡ 8a4e888c-1ef7-11eb-2a52-17db130458a5
struct Surface
	# Reflectivity
	r::Float64

	# Transmission
	t::Float64

	# Color
	c::RGBA

	# index of refraction
	ior::Float64

end

# ╔═╡ 9c3bdb62-1ef7-11eb-2204-417510bf0d72
html"""
<h4 id="sphere-defs">Sphere</h4>
<p>Aasdf</p>
"""

# ╔═╡ cb7ed97e-1ef7-11eb-192c-abfd66238378
struct Sphere <: Object
	# Lens position
	p::Vector{Float64}

	# Lens radius
	r::Float64

	s::Surface
end

# ╔═╡ 6fdf613c-193f-11eb-0029-957541d2ed4d
function sphere_normal_at(p::Vector{Float64}, s::Sphere)
	normalize(p - s.p)
end

# ╔═╡ bbfd6954-576c-41f1-a686-8397c8618313
html"""
<h4 id="cube-defs"Cube</h4>
<p>Cube</p>
"""

# ╔═╡ 61e3a736-497a-43c3-b12a-94460d761fd0
struct Cube <: Object
	# Minimum corner.
	min::Vector{Float64}

	# Maximum corner.
	max::Vector{Float64}

	# Texture
	s::Surface
end

# ╔═╡ 516b4bb1-aaac-4b78-b984-1fbfc0566cb0
function intersection(ray::Photon, cube::Cube)
    tmin = -Inf
    tmax = Inf
    ϵ = 1e-6  
    
    for i in 1:3
        if abs(ray.l[i]) < ϵ
            if ray.p[i] < cube.min[i] || ray.p[i] > cube.max[i]
                return Miss()
            end
            continue
        end
        
        invD = 1.0 / ray.l[i]
        t0 = (cube.min[i] - ray.p[i]) * invD
        t1 = (cube.max[i] - ray.p[i]) * invD
        
        if invD < 0
            t0, t1 = t1, t0
        end
        
        tmin = max(tmin, t0)
        tmax = min(tmax, t1)
        
        if tmin > tmax + ϵ
            return Miss()
        end
    end
    
    t = tmin
    if t < ϵ 
        if tmax > ϵ
            t = tmax  
        else
            return Miss()
        end
    end
    
    intersection_point = ray.p + t * ray.l
    
    for i in 1:3
        if intersection_point[i] < cube.min[i] - ϵ || 
           intersection_point[i] > cube.max[i] + ϵ
            return Miss()
        end
    end
    
    return Intersection(cube, t, intersection_point)
end

# ╔═╡ 4ec204c2-af19-4b2f-bd89-424b69a06f66
function cube_normal_at(p::Vector{Float64}, c::Cube)
    min_corner = c.min
    max_corner = c.max
    ϵ = 1e-6  
    
    distances = [
        abs(p[1] - min_corner[1]),  
        abs(p[1] - max_corner[1]),  
        abs(p[2] - min_corner[2]),  
        abs(p[2] - max_corner[2]),  
        abs(p[3] - min_corner[3]),  
        abs(p[3] - max_corner[3])   
    ]
    
    min_dist = minimum(distances)
    if min_dist > ϵ
        return Miss()
    end
    
   
    face_idx = argmin(distances)
    return [
        [-1.0, 0.0, 0.0],  
        [1.0, 0.0, 0.0],   
        [0.0, -1.0, 0.0],  
        [0.0, 1.0, 0.0],  
        [0.0, 0.0, -1.0],  
        [0.0, 0.0, 1.0]    
    ][face_idx]
end

# ╔═╡ 452d6668-1ec7-11eb-3b0a-0b8f45b43fd5
md"""
## Camera and Skyboxes

Now we can begin looking into the 3D nature of raytracing to create visualizations similar to those in lecture.
The first step is setting up the camera and another stuct known as a *sky box* to collect all the rays of light.

Luckily, the transition from 2D to 3D for raytracing is relatively straightforward and we can use all of the functions and concepts we have built in 2D moving forward.

Firstly, the camera:

"""

# ╔═╡ 791f0bd2-1ed1-11eb-0925-13c394b901ce
md"""
### Camera

For the purposes of this homework, we will constrain ourselves to a camera pointing exclusively downward.
This is simply because camera positioning can be a bit tricky and there is no reason to make the homework more complicated than it needs to be!

So, what is the purpose of the camera?

Well, in reality, a camera is a device that collects the color information from all the rays of light that are refracting and reflecting off of various objects in some sort of scene.
Because there are a nearly infinite number of rays bouncing around the scene at any time, we will actually constrain ourselves only to rays that are entering our camera.
In poarticular, we will create a 2D screen just in front of the camera and send a ray from the camera to each pixel in the screen, as shown in the following image:

$(RemoteResource("https://upload.wikimedia.org/wikipedia/commons/thumb/8/83/Ray_trace_diagram.svg/1920px-Ray_trace_diagram.svg.png", :width=>400, :style=>"display: block; margin: auto;"))
"""

# ╔═╡ 1a446de6-1ec9-11eb-1e2f-6f4376005d24
md"""
Because we are not considering camera motion for this exercise, we will assume that the image plane is constrained to the horizontal plane, but that the camera, itself, can be some distance behind it.
This distance from the image plane to the camera is called the *focal length* and is used to determine the field of view.

From here, it's clear we need to construct:
1. A camera struct
2. A function to initialize all the rays being generated by the camera

Let's start with the struct
"""

# ╔═╡ 88576c6e-1ecb-11eb-3e34-830aeb433df1
struct Camera <: Object
	"Set of all pixels, counts as scene resolution"
	resolution::Tuple{Int64,Int64}

	"Physical size of aperture"
	aperture_width::Float64

	"Camera's distance from screen"
	focal_length::Float64

	"Camera's position"
	p::Vector{Float64}
end

# ╔═╡ e774d6a8-2058-11eb-015a-83b4b6104e6e
test_cam = Camera((400,300), 9, -10, [0,00,100])

# ╔═╡ 8f73824e-1ecb-11eb-0b28-4d1bc0eefbc3
md"""
Now we need to construct some method to create each individual ray extending from the camera to a pixel in the image plane.
"""

# ╔═╡ 4006566e-1ecd-11eb-2ce1-9d1107186784
function init_rays(cam::Camera)
	
	# Physical size of the aperture/image/grid
	aspect_ratio = cam.resolution[1] / cam.resolution[2]
	dim = (
		cam.aperture_width, 
		cam.aperture_width / aspect_ratio
	)

	# The x, y coordinates of every pixel in our image grid
	# relative to the image center
	xs = LinRange(-0.5* dim[1], 0.5 * dim[1], cam.resolution[1])
	ys = LinRange(0.5* dim[2], -0.5 * dim[2], cam.resolution[2])
	
	pixel_positions = [[x, y, cam.focal_length] for y in ys, x in xs]
	directions = normalize.(pixel_positions)
	
	Photon.([cam.p], directions, [zero(RGB)], [1.0])
end

# ╔═╡ 156c0d7a-2071-11eb-1551-4f2d393df6c8
tiny_resolution_camera = Camera((4,3), 16, -5, [0, 20, 100])

# ╔═╡ 2838c1e4-2071-11eb-13d8-1da955fbf544
test_rays = init_rays(tiny_resolution_camera)

# ╔═╡ 595acf48-1ef6-11eb-0b46-934d17186e7b
extract_colors(rays) = map(ray -> ray.c, rays)

# ╔═╡ b7fa4512-2089-11eb-255d-4d6de9cdfb8e
extract_colors(test_rays)

# ╔═╡ 494687f6-1ecd-11eb-3ada-6f11f45aa74f
md"""
Nothing yet... time to add some objects!
### Skybox

Now that we have the concept of a camera, we can technically do a fully 3D raytracing example; however, we want to ensure that each pixel will actually *hit* something -- preferrably something with some color gradient so we can make sure our simulation is working!

For this, we will introduce the concept of a sky box, which is standard for most gaming applications.
Here, the idea is that our entire scene is held within some additional object, just like the mirrors we used in the 2D example.
The only difference here is that we will be using some texture instead of a reflective surface.
In addition, even though we are calling it a box, we'll actually be treating it as a sphere.

Because we have already worked out how to make sure we have hit the interior of a spherical lens, we will be using a similar function here.
For this part of the exercise, we will need to construct 2 things:

1. A skybox struct
2. A function that returns some color gradient to be called whenever a ray of light interacts with a sky box

So let's start with the sky box struct
"""

# ╔═╡ 9e71183c-1ef4-11eb-1802-3fc60b51ceba
struct SkyBox <: Object
	# Skybox position
	p::Vector{Float64}

	# Skybox radius
	r::Float64
	
	# Color function
	c::Function
end

# ╔═╡ 093b9e4a-1f8a-11eb-1d32-ad1d85ddaf42
function intersection(photon::Photon, sphere::S; ϵ=1e-3) where {S <: Union{SkyBox, Sphere}}
	a = dot(photon.l, photon.l)
	b = 2 * dot(photon.l, photon.p - sphere.p)
	c = dot(photon.p - sphere.p, photon.p - sphere.p) - sphere.r^2
	
	d = b^2 - 4*a*c
	
	if d <= 0
		Miss()
	else
		t1 = (-b-sqrt(d))/2a
		t2 = (-b+sqrt(d))/2a
		
		t = if t1 > ϵ
			t1
		elseif t2 > ϵ
			t2
		else
			return Miss()
		end
		
		point = photon.p + t * photon.l
		
		Intersection(sphere, t, point)
	end
end

# ╔═╡ 89e98868-1fb2-11eb-078d-c9298d8a9970
function closest_hit(photon::Photon, objects::Vector{<:Object})
	hits = intersection.([photon], objects)
	
	minimum(hits)
end

# ╔═╡ aa9e61aa-1ef4-11eb-0b56-cd7ded52b640
md"""
Now we have the ability to create a skybox, the only thing left is to create some sort of texture function so that when the ray of light hits the sky box, we can return some form of color information.
So for this, we will basically create a function that returns back a smooth gradient in different directions depending on the position of the ray when it hits the skybox.

For the color information, we will be assigning a color to each cardinal axis.
That is to say that there will be a red gradient along $x$, a blue gradient along $y$, and a green gradient along $z$.
For this, we will need to define some extent over which the gradient will be active in 'real' units.
From there, we can say that the gradient is

$$\frac{r+D}{2D},$$

where $r$ is the ray's position when it hits the skybox, and $D$ is the extent over which the gradient is active.

So let's get to it and write the function!
"""

# ╔═╡ c947f546-1ef5-11eb-0f02-054f4e7ae871
function gradient_skybox_color(position, skybox)
	extents = skybox.r
	c = zero(RGB)
	
	if position[1] < extents && position[1] > -extents
		c += RGB((position[1]+extents)/(2.0*extents), 0, 0)
	end

	if position[2] < extents && position[2] > -extents
		c += RGB(0,0,(position[2]+extents)/(2.0*extents))
	end

	if position[3] < extents && position[3] > -extents
		c += RGB(0,(position[3]+extents)/(2.0*extents), 0)
	end

	return c
end

# ╔═╡ a919c880-206e-11eb-2796-55ccd9dbe619
sky = SkyBox([0.0, 0.0, 0.0], 1000, gradient_skybox_color)

# ╔═╡ 49651bc6-2071-11eb-1aa0-ff829f7b4350
md"""
Let's set up a basic scene and trace an image! Since our skybox is _spherical_ we can use **the same `intersect`** method as we use for `Sphere`s. Have a look at [the `intersect` method](#sphere-defs), we already added `SkyBox` as a possible type.
"""

# ╔═╡ daf80644-2070-11eb-3363-c577ae5846b3
basic_camera = Camera((300,200), 16, -5, [0,20,100])

# ╔═╡ df3f2178-1ef5-11eb-3098-b1c8c67cf136
md"""
To create this image, we used the ray tracing function bewlow, which takes in a camera and a set of objects / scene, and...
1. Initilializes all the rays
2. Propagates the rays forward
3. Converts everything into an image
"""

# ╔═╡ 04a86366-208b-11eb-1977-ff7e4ae6b714
md"""
## Writing a ray tracer

It's your turn! Below is the code needed to trace just the sky box, but we still need to add the ability to trace spheres.

**We recommend** that you start by just implementing _reflection_ - make every sphere reflect, regardless of its surface. Make sure that this is working well - can you see the reflection of one sphere in another sphere? Does our program get stuck in a loop?

Once you have reflections working, you can add _refraction_ and _colored spheres_. In the 2D example, we dealt specifically with spheres that could either 100% reflect or refract. In reality, it is possible for objects to either reflect or refract, something in-between.
That is to say, a ray of light can *split* when hitting an object surface, creating at least 2 more rays of light that will both return separate color values.
The color that we _perceive_ for that ray is the combination both of these colors - they are mixed.

A third possibility explored in the lecture is that the objects can also have a color associated with them and just return the color value instead of reflecting or refracting.

**You can choose!** After implementing reflection, you can implement three different spheres (you can modify the existing code, create new types, add functions, and so on), a purely reflective, purely refractive or opaquely colored sphere. You can also go straight for the more photorealistic option, which is that every sphere is a combination of these three - this is what we did in the lecture.
"""

# ╔═╡ a0b84f62-2047-11eb-348c-db83f4e6c39c
#=╠═╡
let
	scene = [sky]
	ray_trace(scene, basic_camera; num_intersections=4)
end
  ╠═╡ =#

# ╔═╡ d1970a34-1ef7-11eb-3e1f-0fd3b8e9657f
md"""
Below, we create a scene with a number of balls inside of it.
While working on your code, work in small increments, and do frequent checks to see if your code is working. Feel free to modify this test scene, or to create a simpler one.
"""

# ╔═╡ 1f66ba6e-1ef8-11eb-10ba-4594f7c5ff19
@time let
	cam = Camera((400, 400), 16, -15, [0,60,210])

	img = map(clamp01nan,ray_trace(main_scene, cam; num_intersections=20))

	save("D:\\Computational Thinking\\Computational-Thinking-18.S191\\homework8\\cubes_and_spheres.png", img)

	img
end

# ╔═╡ 16f4c8e6-2051-11eb-2f23-f7300abea642
main_scene = [
	sky,
		Sphere([0,0,-25], 20, 
		Surface(1.0, 0.0, RGBA(1,1,1,0.0), 1.5)),
	
	Sphere([0,50,-100], 25, 
		Surface(0.9, 0.1, RGBA(0,1,0,0.0), 1.8)),
	
	Sphere([-50,0,-25], 20, 
		Surface(0.0, 0.0, RGBA(0, .3, .8, 1), 1.33)),
	
	Sphere([30, 25, -60], 20,
		Surface(0.0, 0.75, RGBA(1,0,0,0.25), 1.5)),
	
	Sphere([50, 0, -25], 20,
		Surface(0.5, 0.0, RGBA(.1,.9,.1,0.5), 1.5)),
	
	Sphere([-30, 25, -60], 20,
		Surface(0.5, 0.5, RGBA(1,1,1,0), 1.5)),
	Sphere([-90, 25, -60], 20,
		Surface(0.75, 0.25, RGBA(0.1,1.0,0.1,0), 1.2)),
	
	Sphere([120, 25, -60], 25,
		Surface(0.2, 0.8, RGBA(1.0,0.1,0.0,0.8), 1.5)),
	
	Cube([-15, 80, -120],  
    [15, 110, -80],
    Surface(1.0, 0.0, RGBA(0.72, 0.72, 0.72,0.0), 1.2)),
	Cube(
	[-55, 30, -120],  
    [-35, 70, -80],
    Surface(0.1, 0.9, RGBA(1,0,0,.2), 1.33)),

Cube(
    [35, 90, -120],  
    [55, 120, -80],
    Surface(1.0, 0.0, RGBA(1.0, 0.0, 0.0, 1), 1.22)),

	Sphere([0,110,50], 17, 
			Surface(1.0, 0.0, RGBA(1,1,1,0.0), 1.5))

]

# ╔═╡ acede744-2390-4de1-ab1c-411fcc69eb4e


# ╔═╡ 67c0bd70-206a-11eb-3935-83d32c67f2eb
md"""
## **Bonus:** Escher

If you managed to get through the exercises, we have a fun bonus exercise! The goal is to recreate this self-portrait by M.C. Escher:

"""

# ╔═╡ 748cbaa2-206c-11eb-2cc9-7fa74308711b
Resource("https://www.researchgate.net/profile/Madhu_Gupta22/publication/3427377/figure/fig1/AS:663019482775553@1535087571714/A-self-portrait-of-MC-Escher-1898-1972-in-spherical-mirror-dating-from-1935-titled.png", :width=>300)

# ╔═╡ 981e6bd2-206c-11eb-116d-6fad4e04ce34
md"""
It looks like M.C. Escher is a skillful raytracer, but so are we! To recreate this image, we can simplify it by having just two objects in our scene:
- A purely reflective sphere
- A skybox, containing an image of us!

Let's start with our old skybox, and set up our scene:
"""

# ╔═╡ 7a12a99a-206d-11eb-2393-bf28b881087a
escher_sphere = Sphere([0,0,0], 20, 
			Surface(1.0, 0.0, RGBA(1,1,1,0.0), 1.5))

# ╔═╡ 373b6a26-206d-11eb-1e67-9debb032f69e
escher_cam = Camera((600,400), 30, -5, [0,00,30])

# ╔═╡ 5dfec31c-206d-11eb-23a2-259f2c205cb5
md"""
👆 You can modify `escher_cam` to increase or descrease the resolution!
"""

# ╔═╡ 6f1dbf48-206d-11eb-24d3-5154703e1753
#=╠═╡
let
	scene = [sky, escher_sphere]
	ray_trace(scene, escher_cam; num_intersections=5)
end
  ╠═╡ =#

# ╔═╡ dc786ccc-206e-11eb-29e2-99882e6613af
md"""
Awesome! Next, we want to set an _image_ as our skybox, instead of a gradient. To do so, we have written a function that converts the x,y,z coordinates of the intersection point with a skybox into a latitude/longitude pair, which we can use (after scaling, rounding & clamping) as pixel coordinates to index an image!
"""

# ╔═╡ 8ebe4cd6-2061-11eb-396b-45745bd7ec55
earth = load(download("https://upload.wikimedia.org/wikipedia/commons/thumb/8/8f/Whole_world_-_land_and_oceans_12000.jpg/1280px-Whole_world_-_land_and_oceans_12000.jpg"))

# ╔═╡ 12d3b806-2062-11eb-20a8-7d1a33e4b073
function get_index_rational(A, x, y)
	a, b = size(A)
	
	u = clamp(floor(Int, x * (a-1)) + 1, 1, a)
	v = clamp(floor(Int, y * (b-1)) + 1, 1, b)
	A[u,v]
end

# ╔═╡ cc492966-2061-11eb-1000-d90c279c4668
function image_skybox(img)
	f = function(position, skybox)
		lon = atan(-position[1], position[3])
		lat = -atan(position[2], norm(position[[1,3]]))

		get_index_rational(img, (lat/(pi)) + .5, (lon/2pi) + .5)
	end
	
	SkyBox([0.0, 0.0, 0.0], 1000, f)
end

# ╔═╡ 137834d4-206d-11eb-0082-7b87bf222808
earth_skybox = image_skybox(earth)

# ╔═╡ bff27890-206e-11eb-2e40-696424a0b8be
#=╠═╡
let
	scene = [earth_skybox, escher_sphere]
	ray_trace(scene, escher_cam; num_intersections=3)
end
  ╠═╡ =#

# ╔═╡ b0bc76f8-206d-11eb-0cad-4bde96565fed
md"""
Great! It's like the Earth, but distorted. Notice that the continents are mirrored, and that you can see both poles at the same time. 

Okay, self portrait time! Let's take a picture using your webcam, and we will use it as the skybox texture:
"""

# ╔═╡ 48166866-2070-11eb-2722-556a6719c2a2
md"""
👀 wow! It's _Planet $(student.name)_, surrounded by even more $(student.name). 

When you look at the drawing by Escher, you see that he only occupies a small section of the 'skybox'. Behind Escher, you can see his cozy house, and in _front_ of him (i.e. _behind_ the glass sphere, from his persective), you see a gray background. 

What we need is a 360° panoramic image of our room. One option is that you make one! There are great tutorials online, and maybe you can use an app to do this with your phone.

Another option is that we approximate the panaroma by _padding_ the image of your face. You can pad the image with a solid color, you can use a gradient, you can use the earth satellite image, you can add noise, and so on. [Here](https://user-images.githubusercontent.com/6933510/98426463-31a64f00-2099-11eb-96dd-9f0f065e0da4.png) is an example of what I made.
"""

# ╔═╡ 6480b85c-2067-11eb-0262-f752d306d8ae
function padded(img)
	
	return missing
end

# ╔═╡ 3de614da-2091-11eb-361a-83bcf357c394
md"""
Let's put it all together!
"""

# ╔═╡ ebd05bf0-19c3-11eb-2559-7d0745a84025
if student.name == "Jazzy Doe" || student.kerberos_id == "jazz"
	md"""
	!!! danger "Before you submit"
	    Remember to fill in your **name** and **Kerberos ID** at the top of this notebook.
	"""
end

# ╔═╡ ec275590-19c3-11eb-23d0-cb3d9f62ba92
md"## Function library

Just some helper functions used in the notebook."

# ╔═╡ 2c36d3e8-2065-11eb-3a12-8382f8539ea6

function process_raw_camera_data(raw_camera_data)
	# the raw image data is a long byte array, we need to transform it into something
	# more "Julian" - something with more _structure_.
	
	# The encoding of the raw byte stream is:
	# every 4 bytes is a single pixel
	# every pixel has 4 values: Red, Green, Blue, Alpha
	# (we ignore alpha for this notebook)
	
	# So to get the red values for each pixel, we take every 4th value, starting at 
	# the 1st:
	reds_flat = UInt8.(raw_camera_data["data"][1:4:end])
	greens_flat = UInt8.(raw_camera_data["data"][2:4:end])
	blues_flat = UInt8.(raw_camera_data["data"][3:4:end])
	
	# but these are still 1-dimensional arrays, nicknamed 'flat' arrays
	# We will 'reshape' this into 2D arrays:
	
	width = raw_camera_data["width"]
	height = raw_camera_data["height"]
	
	# shuffle and flip to get it in the right shape
	reds = reshape(reds_flat, (width, height))' / 255.0
	greens = reshape(greens_flat, (width, height))' / 255.0
	blues = reshape(blues_flat, (width, height))' / 255.0
	
	# we have our 2D array for each color
	# Let's create a single 2D array, where each value contains the R, G and B value of 
	# that pixel
	
	RGB.(reds, greens, blues)
end

# ╔═╡ f7b5ff68-2064-11eb-3be3-554519ca4847
function camera_input(;max_size=200, default_url="https://i.imgur.com/SUmi94P.png")
"""
<span class="pl-image waiting-for-permission">
<style>
	
	.pl-image.popped-out {
		position: fixed;
		top: 0;
		right: 0;
		z-index: 5;
	}

	.pl-image #video-container {
		width: 250px;
	}

	.pl-image video {
		border-radius: 1rem 1rem 0 0;
	}
	.pl-image.waiting-for-permission #video-container {
		display: none;
	}
	.pl-image #prompt {
		display: none;
	}
	.pl-image.waiting-for-permission #prompt {
		width: 250px;
		height: 200px;
		display: grid;
		place-items: center;
		font-family: monospace;
		font-weight: bold;
		text-decoration: underline;
		cursor: pointer;
		border: 5px dashed rgba(0,0,0,.5);
	}

	.pl-image video {
		display: block;
	}
	.pl-image .bar {
		width: inherit;
		display: flex;
		z-index: 6;
	}
	.pl-image .bar#top {
		position: absolute;
		flex-direction: column;
	}
	
	.pl-image .bar#bottom {
		background: black;
		border-radius: 0 0 1rem 1rem;
	}
	.pl-image .bar button {
		flex: 0 0 auto;
		background: rgba(255,255,255,.8);
		border: none;
		width: 2rem;
		height: 2rem;
		border-radius: 100%;
		cursor: pointer;
		z-index: 7;
	}
	.pl-image .bar button#shutter {
		width: 3rem;
		height: 3rem;
		margin: -1.5rem auto .2rem auto;
	}

	.pl-image video.takepicture {
		animation: pictureflash 200ms linear;
	}

	@keyframes pictureflash {
		0% {
			filter: grayscale(1.0) contrast(2.0);
		}

		100% {
			filter: grayscale(0.0) contrast(1.0);
		}
	}
</style>

	<div id="video-container">
		<div id="top" class="bar">
			<button id="stop" title="Stop video">✖</button>
			<button id="pop-out" title="Pop out/pop in">⏏</button>
		</div>
		<video playsinline autoplay></video>
		<div id="bottom" class="bar">
		<button id="shutter" title="Click to take a picture">📷</button>
		</div>
	</div>
		
	<div id="prompt">
		<span>
		Enable webcam
		</span>
	</div>

<script>
	// based on https://github.com/fonsp/printi-static (by the same author)

	const span = currentScript.parentElement
	const video = span.querySelector("video")
	const popout = span.querySelector("button#pop-out")
	const stop = span.querySelector("button#stop")
	const shutter = span.querySelector("button#shutter")
	const prompt = span.querySelector(".pl-image #prompt")

	const maxsize = $(max_size)

	const send_source = (source, src_width, src_height) => {
		const scale = Math.min(1.0, maxsize / src_width, maxsize / src_height)

		const width = Math.floor(src_width * scale)
		const height = Math.floor(src_height * scale)

		const canvas = html`<canvas width=\${width} height=\${height}>`
		const ctx = canvas.getContext("2d")
		ctx.drawImage(source, 0, 0, width, height)

		span.value = {
			width: width,
			height: height,
			data: ctx.getImageData(0, 0, width, height).data,
		}
		span.dispatchEvent(new CustomEvent("input"))
	}
	
	const clear_camera = () => {
		window.stream.getTracks().forEach(s => s.stop());
		video.srcObject = null;

		span.classList.add("waiting-for-permission");
	}

	prompt.onclick = () => {
		navigator.mediaDevices.getUserMedia({
			audio: false,
			video: {
				facingMode: "environment",
			},
		}).then(function(stream) {

			stream.onend = console.log

			window.stream = stream
			video.srcObject = stream
			window.cameraConnected = true
			video.controls = false
			video.play()
			video.controls = false

			span.classList.remove("waiting-for-permission");

		}).catch(function(error) {
			console.log(error)
		});
	}
	stop.onclick = () => {
		clear_camera()
	}
	popout.onclick = () => {
		span.classList.toggle("popped-out")
	}

	shutter.onclick = () => {
		const cl = video.classList
		cl.remove("takepicture")
		void video.offsetHeight
		cl.add("takepicture")
		video.play()
		video.controls = false
		console.log(video)
		send_source(video, video.videoWidth, video.videoHeight)
	}
	
	
	document.addEventListener("visibilitychange", () => {
		if (document.visibilityState != "visible") {
			clear_camera()
		}
	})


	// Set a default image

	const img = html`<img crossOrigin="anonymous">`

	img.onload = () => {
	console.log("helloo")
		send_source(img, img.width, img.height)
	}
	img.src = "$(default_url)"
	console.log(img)
</script>
</span>
""" |> HTML
end

# ╔═╡ 27d64432-2065-11eb-3795-e99b1d6718d2
@bind wow camera_input()

# ╔═╡ 64ce8106-2065-11eb-226c-0bcaf7e3f871
face = process_raw_camera_data(wow)

# ╔═╡ 06ac2efc-206f-11eb-1a73-9306bf5f7a9c
#=╠═╡
let
	face_skybox = image_skybox(face)
	scene = [face_skybox, escher_sphere]
	ray_trace(scene, escher_cam; num_intersections=3)
end
  ╠═╡ =#

# ╔═╡ 7d03b258-2067-11eb-3070-1168e282b2ea
padded(face)

# ╔═╡ aa597a16-2066-11eb-35ae-3170468a90ed
@bind escher_face_data camera_input()

# ╔═╡ c68dbe1c-2066-11eb-048d-038df2c68a8b
#=╠═╡
let
	img = process_raw_camera_data(escher_face_data)
	img_padded = padded(img)
	
	scene = [
		image_skybox(padded(img)),

		escher_sphere,
	]
	
	ray_trace(scene, escher_cam; num_intersections=20)
end
  ╠═╡ =#

# ╔═╡ ec31dce0-19c3-11eb-1487-23cc20cd5277
hint(text) = Markdown.MD(Markdown.Admonition("hint", "Hint", [text]))

# ╔═╡ 7c804c30-208d-11eb-307c-076f2086ae73
hint(md"""If you are getting a _"Circular Defintions"_ error - this could be because of a Pluto limitation. If two functions call each other, they need to be contained in a single cell, using a `begin end` block.""")

# ╔═╡ ec3ed530-19c3-11eb-10bb-a55e77550d1f
almost(text) = Markdown.MD(Markdown.Admonition("warning", "Almost there!", [text]))

# ╔═╡ ec4abc12-19c3-11eb-1ca4-b5e9d3cd100b
still_missing(text=md"Replace `missing` with your answer.") = Markdown.MD(Markdown.Admonition("warning", "Here we go!", [text]))

# ╔═╡ ec57b460-19c3-11eb-2142-07cf28dcf02b
keep_working(text=md"The answer is not quite right.") = Markdown.MD(Markdown.Admonition("danger", "Keep working on it!", [text]))

# ╔═╡ ec5d59b0-19c3-11eb-0206-cbd1a5415c28
yays = [md"Fantastic!", md"Splendid!", md"Great!", md"Yay ❤", md"Great! 🎉", md"Well done!", md"Keep it up!", md"Good job!", md"Awesome!", md"You got the right answer!", md"Let's move on to the next section."]

# ╔═╡ ec698eb0-19c3-11eb-340a-e319abb8ebb5
correct(text=rand(yays)) = Markdown.MD(Markdown.Admonition("correct", "Got it!", [text]))

# ╔═╡ ec7638e0-19c3-11eb-1ca1-0b3aa3b40240
not_defined(variable_name) = Markdown.MD(Markdown.Admonition("danger", "Oopsie!", [md"Make sure that you define a variable called **$(Markdown.Code(string(variable_name)))**"]))

# ╔═╡ ec85c940-19c3-11eb-3375-a90735beaec1
TODO = html"<span style='display: inline; font-size: 2em; color: purple; font-weight: 900;'>TODO</span>"

# ╔═╡ 8cfa4902-1ad3-11eb-03a1-736898ff9cef
TODO_note(text) = Markdown.MD(Markdown.Admonition("warning", "TODO note", [text]))

# ╔═╡ 96f51f86-264e-4a4f-a9e1-40c9b444c043
# ╠═╡ disabled = true
#=╠═╡
function ray_trace(objects::Vector{O}, cam::Camera;
				   num_intersections = 10) where {O <: Object}
	rays = init_rays(cam)
	new_rays = step_ray.(rays, [objects], [num_intersections])
	
	extract_colors(new_rays)
end
  ╠═╡ =#

# ╔═╡ a9754410-204d-11eb-123e-e5c5f87ae1c5
# ╠═╡ disabled = true
#=╠═╡
function interact(ray::Photon, hit::Intersection{SkyBox})
	ray_color = hit.object.c(hit.point, hit.object)
	Photon(hit.point, ray.l, ray_color, ray.ior)
end
  ╠═╡ =#

# ╔═╡ 95ca879a-204d-11eb-3473-959811aa8320
#=╠═╡
begin
    function interact_r(photon::Photon, hit::Intersection{Sphere}, num_intersections::Int64, objects::Vector{Object})
        if hit.object.s.r < 0.01
            return photon
        end
        reflection_dir = reflect(photon.l, sphere_normal_at(hit.point, hit.object))
        reflected_photon = Photon(hit.point, reflection_dir, photon.c, photon.ior)
        return step_ray(reflected_photon, objects, num_intersections - 1)
    end
    
    function interact(photon::Photon, hit::Intersection{Sphere}, num_intersections::Int64, objects::Vector{Object})
        if hit.object.s.t < 0.01
            return photon
        end
        refraction_dir = refract(photon.l, sphere_normal_at(hit.point, hit.object), photon.ior, hit.object.s.ior)
        refracted_photon = Photon(hit.point, refraction_dir, photon.c, hit.object.s.ior)
        return step_ray(refracted_photon, objects, num_intersections - 1)
    end
    
    interact(photon::Photon, ::Miss, ::Any, ::Any) = photon
    
    function interact(ray::Photon, hit::Intersection{SkyBox})
        ray_color = hit.object.c(hit.point, hit.object)
        Photon(hit.point, ray.l, ray_color, ray.ior)
    end
    
    function interact(photon::Photon, hit::Intersection{Cube}, num_intersections::Int64, objects::Vector{Object})
        n_c = cube_normal_at(hit.point, hit.object)
        if n_c isa Miss
            return photon
        end
        refraction_dir = refract(photon.l, normalize(n_c), photon.ior, hit.object.s.ior)
        refracted_photon = Photon(hit.point, refraction_dir, photon.c, hit.object.s.ior)
        return step_ray(refracted_photon, objects, num_intersections - 1)
    end
    
    function interact_r(photon::Photon, hit::Intersection{Cube}, num_intersections::Int64, objects::Vector{Object})
        n_c = cube_normal_at(hit.point, hit.object)
        if n_c isa Miss
            return photon
        end
        reflection_dir = reflect(photon.l, normalize(n_c))
        reflected_photon = Photon(hit.point, reflection_dir, photon.c, photon.ior)
        return step_ray(reflected_photon, objects, num_intersections - 1)
    end
    
    function step_ray(ray::Photon, objects::Vector{O}, num_intersections) where {O <: Object}
        if num_intersections <= 0
            return ray
        end
        
        hit = closest_hit(ray, objects)
        if hit isa Miss 
            return ray
        end
        
        if hit.object isa SkyBox
            return interact(ray, hit)
        end
        
        refracted_ray = interact(ray, hit, num_intersections - 1, objects)
        reflected_ray = interact_r(ray, hit, num_intersections - 1, objects)
        
        final_color = reflected_ray.c * hit.object.s.r +  
                     refracted_ray.c * hit.object.s.t +   
                     hit.object.s.c * hit.object.s.c.alpha 
        
        return Photon(hit.point, ray.l, final_color, ray.ior)
    end
end
  ╠═╡ =#

# ╔═╡ 086e1956-204e-11eb-2524-f719504fb95b
# ╠═╡ disabled = true
#=╠═╡
interact(photon::Photon, ::Miss, ::Any, ::Any) = photon
  ╠═╡ =#

# ╔═╡ 2899d5c0-cceb-4a08-8317-e2a2ddc1ccbb
# ╠═╡ disabled = true
#=╠═╡
function interact_r(photon::Photon, hit::Intersection{Sphere}, num_intersections::Int64, objects::Vector{Object})
    reflection_dir = reflect(photon.l, sphere_normal_at(hit.point, hit.object))
    reflected_photon = Photon(hit.point, reflection_dir, photon.c, photon.ior)
    return step_ray(reflected_photon, objects, num_intersections - 1)
end

  ╠═╡ =#

# ╔═╡ 6b91a58a-1ef6-11eb-1c36-2f44713905e1
#=╠═╡
function ray_trace(objects::Vector{O}, cam::Camera;
				   num_intersections = 10) where {O <: Object}
	rays = init_rays(cam)
	@floop ThreadedEx(basesize=length(rays)÷8) for i=1:length(rays)
		rays[i] = step_ray(rays[i], objects, num_intersections)
	#new_rays = step_ray.(rays, [objects], [num_intersections])
	end

	extract_colors(rays)
end
  ╠═╡ =#

# ╔═╡ 7f788a7a-1293-410b-b52c-44789c8b539c
# ╠═╡ disabled = true
#=╠═╡
function interact(photon::Photon, hit::Intersection{Sphere}, num_intersections::Int64, objects::Vector{Object})
    reflection_dir = refract(photon.l, sphere_normal_at(hit.point, hit.object), photon.ior, hit.object.s.ior)
    reflected_photon = Photon(hit.point, reflection_dir, photon.c, photon.ior)
    return step_ray(reflected_photon, objects, num_intersections - 1)
end

  ╠═╡ =#

# ╔═╡ Cell order:
# ╟─1df32310-19c4-11eb-0824-6766cd21aaf4
# ╟─1df82c20-19c4-11eb-0959-8543a0d5630d
# ╟─1e109620-19c4-11eb-013e-1bc95c14c2ba
# ╟─1e202680-19c4-11eb-29a7-99061b886b3c
# ╟─e4d2f6f6-2089-11eb-0b4a-0d22f72f72ba
# ╟─1e2cd0b0-19c4-11eb-3583-0b82092139aa
# ╠═c3e52bf2-ca9a-11ea-13aa-03a4335f2906
# ╠═315c6c55-4851-44b3-92d1-4cfc5b610706
# ╠═e5a8efc1-312a-4069-82d3-7a353c875382
# ╟─4e917968-1f87-11eb-371f-e3899b76dc24
# ╠═24b0d4ba-192c-11eb-0f66-e77b544b0510
# ╟─c6e8d30e-205c-11eb-271c-6165a164073d
# ╠═d851a202-1ca0-11eb-3da0-51fcb656783c
# ╠═8acef4b0-1a09-11eb-068d-79a259244ed1
# ╠═8018fbf0-1a05-11eb-3032-95aae07ca78f
# ╠═fcde90ca-2048-11eb-3e96-f9f47b6154e8
# ╠═89e98868-1fb2-11eb-078d-c9298d8a9970
# ╟─dc36ceaa-205c-11eb-169c-bb4c36aaec9f
# ╠═43306bd4-194d-11eb-2e30-07eabb8b29ef
# ╠═14dc73d2-1a0d-11eb-1a3c-0f793e74da9b
# ╟─7f0bf286-2071-11eb-0cac-6d10c93bab6c
# ╠═8a4e888c-1ef7-11eb-2a52-17db130458a5
# ╠═9c3bdb62-1ef7-11eb-2204-417510bf0d72
# ╠═cb7ed97e-1ef7-11eb-192c-abfd66238378
# ╠═093b9e4a-1f8a-11eb-1d32-ad1d85ddaf42
# ╠═6fdf613c-193f-11eb-0029-957541d2ed4d
# ╟─bbfd6954-576c-41f1-a686-8397c8618313
# ╠═61e3a736-497a-43c3-b12a-94460d761fd0
# ╠═516b4bb1-aaac-4b78-b984-1fbfc0566cb0
# ╠═4ec204c2-af19-4b2f-bd89-424b69a06f66
# ╟─452d6668-1ec7-11eb-3b0a-0b8f45b43fd5
# ╟─791f0bd2-1ed1-11eb-0925-13c394b901ce
# ╟─1a446de6-1ec9-11eb-1e2f-6f4376005d24
# ╠═88576c6e-1ecb-11eb-3e34-830aeb433df1
# ╠═e774d6a8-2058-11eb-015a-83b4b6104e6e
# ╟─8f73824e-1ecb-11eb-0b28-4d1bc0eefbc3
# ╠═4006566e-1ecd-11eb-2ce1-9d1107186784
# ╠═156c0d7a-2071-11eb-1551-4f2d393df6c8
# ╠═2838c1e4-2071-11eb-13d8-1da955fbf544
# ╠═595acf48-1ef6-11eb-0b46-934d17186e7b
# ╠═b7fa4512-2089-11eb-255d-4d6de9cdfb8e
# ╟─494687f6-1ecd-11eb-3ada-6f11f45aa74f
# ╠═9e71183c-1ef4-11eb-1802-3fc60b51ceba
# ╟─aa9e61aa-1ef4-11eb-0b56-cd7ded52b640
# ╠═c947f546-1ef5-11eb-0f02-054f4e7ae871
# ╠═a919c880-206e-11eb-2796-55ccd9dbe619
# ╟─49651bc6-2071-11eb-1aa0-ff829f7b4350
# ╠═daf80644-2070-11eb-3363-c577ae5846b3
# ╠═a0b84f62-2047-11eb-348c-db83f4e6c39c
# ╟─df3f2178-1ef5-11eb-3098-b1c8c67cf136
# ╠═96f51f86-264e-4a4f-a9e1-40c9b444c043
# ╠═6b91a58a-1ef6-11eb-1c36-2f44713905e1
# ╟─04a86366-208b-11eb-1977-ff7e4ae6b714
# ╠═a9754410-204d-11eb-123e-e5c5f87ae1c5
# ╠═086e1956-204e-11eb-2524-f719504fb95b
# ╠═7f788a7a-1293-410b-b52c-44789c8b539c
# ╠═2899d5c0-cceb-4a08-8317-e2a2ddc1ccbb
# ╠═95ca879a-204d-11eb-3473-959811aa8320
# ╟─d1970a34-1ef7-11eb-3e1f-0fd3b8e9657f
# ╠═1f66ba6e-1ef8-11eb-10ba-4594f7c5ff19
# ╠═16f4c8e6-2051-11eb-2f23-f7300abea642
# ╠═acede744-2390-4de1-ab1c-411fcc69eb4e
# ╟─7c804c30-208d-11eb-307c-076f2086ae73
# ╟─67c0bd70-206a-11eb-3935-83d32c67f2eb
# ╟─748cbaa2-206c-11eb-2cc9-7fa74308711b
# ╟─981e6bd2-206c-11eb-116d-6fad4e04ce34
# ╠═7a12a99a-206d-11eb-2393-bf28b881087a
# ╠═373b6a26-206d-11eb-1e67-9debb032f69e
# ╟─5dfec31c-206d-11eb-23a2-259f2c205cb5
# ╠═6f1dbf48-206d-11eb-24d3-5154703e1753
# ╟─dc786ccc-206e-11eb-29e2-99882e6613af
# ╟─8ebe4cd6-2061-11eb-396b-45745bd7ec55
# ╠═cc492966-2061-11eb-1000-d90c279c4668
# ╠═12d3b806-2062-11eb-20a8-7d1a33e4b073
# ╠═137834d4-206d-11eb-0082-7b87bf222808
# ╠═bff27890-206e-11eb-2e40-696424a0b8be
# ╟─b0bc76f8-206d-11eb-0cad-4bde96565fed
# ╠═27d64432-2065-11eb-3795-e99b1d6718d2
# ╟─64ce8106-2065-11eb-226c-0bcaf7e3f871
# ╠═06ac2efc-206f-11eb-1a73-9306bf5f7a9c
# ╟─48166866-2070-11eb-2722-556a6719c2a2
# ╠═6480b85c-2067-11eb-0262-f752d306d8ae
# ╠═7d03b258-2067-11eb-3070-1168e282b2ea
# ╟─3de614da-2091-11eb-361a-83bcf357c394
# ╟─aa597a16-2066-11eb-35ae-3170468a90ed
# ╠═c68dbe1c-2066-11eb-048d-038df2c68a8b
# ╟─ebd05bf0-19c3-11eb-2559-7d0745a84025
# ╟─ec275590-19c3-11eb-23d0-cb3d9f62ba92
# ╟─2c36d3e8-2065-11eb-3a12-8382f8539ea6
# ╟─f7b5ff68-2064-11eb-3be3-554519ca4847
# ╟─ec31dce0-19c3-11eb-1487-23cc20cd5277
# ╟─ec3ed530-19c3-11eb-10bb-a55e77550d1f
# ╟─ec4abc12-19c3-11eb-1ca4-b5e9d3cd100b
# ╟─ec57b460-19c3-11eb-2142-07cf28dcf02b
# ╟─ec5d59b0-19c3-11eb-0206-cbd1a5415c28
# ╠═ec698eb0-19c3-11eb-340a-e319abb8ebb5
# ╟─ec7638e0-19c3-11eb-1ca1-0b3aa3b40240
# ╟─ec85c940-19c3-11eb-3375-a90735beaec1
# ╠═8cfa4902-1ad3-11eb-03a1-736898ff9cef
