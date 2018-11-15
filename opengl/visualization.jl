module Visualization

using GLFW
using ModernGL
using Serialization
include("util.jl")
include("drawing.jl")
include("scene.jl")

struct Context
  window::GLFW.Window
  program::GLuint
  width::Int
  height::Int
end

global const ATTRIBUTES = Array{GLint}(undef, 4)
global const Tmat_LOCATION = Array{GLint}(undef, 1)
function make_attributes_global(program)
  positionAttribute = glGetAttribLocation(program, "position")
  colorAttribute = glGetAttribLocation(program, "color")
  usetexAttribute = glGetAttribLocation(program, "usetex")
  texcoordAttribute = glGetAttribLocation(program, "texcoord")
  ATTRIBUTES[:] = [positionAttribute, colorAttribute, 
                   usetexAttribute, texcoordAttribute]
  Tmat_LOCATION[] = glGetUniformLocation(program, "Tmat")
end

function make_shader_program(vsh::String, fsh::String)
  createcontextinfo()
  version_str = get_glsl_version_string()

  vertexShader = createShader(version_str * vsh, GL_VERTEX_SHADER)
  fragmentShader = createShader(version_str * fsh, GL_FRAGMENT_SHADER)
  program = createShaderProgram(vertexShader, fragmentShader)

  return program
end

function make_context(width, height)
  # Create a window and its OpenGL context
  GLFW.WindowHint(GLFW.SAMPLES, 4)
  GLFW.WindowHint(GLFW.CONTEXT_VERSION_MAJOR, 3)
  GLFW.WindowHint(GLFW.CONTEXT_VERSION_MINOR, 3)
  GLFW.WindowHint(GLFW.OPENGL_FORWARD_COMPAT, Cint(1)) # true, required by OS X
  GLFW.WindowHint(GLFW.OPENGL_PROFILE, GLFW.OPENGL_CORE_PROFILE)
  window = GLFW.CreateWindow(width, height, "window.jl")

  # Make the window's context current
  GLFW.MakeContextCurrent(window)

  # Compile the Shader Program
  vsh = read("shader.vert", String)
  fsh = read("shader.frag", String)
  program = make_shader_program(vsh, fsh)
  glUseProgram(program)
  make_attributes_global(program)

  return Context(window, program, width, height)
end

function print_error_if_not_empty()
  err = glErrorMessage()
  if err != ""
    println(err)
  end
end

function setup()
  # Load the Window -----------------------------------------------------------
  width = 1080
  height = round(Int, 1080 * 9 / 16)
  context = make_context(width, height)
  # ---------------------------------------------------------------------------


  # window scaling matrix -----------------------------------------------------
  W = scale_mat(context.height/context.width, 1)
  glUniformMatrix4fv(glGetUniformLocation(context.program, "Wmat"), 1, 
                     GL_FALSE, W)
  # ---------------------------------------------------------------------------

  # Load Font Texture ---------------------------------------------------------
  textureBuffer = glGenTexture()
  glActiveTexture(GL_TEXTURE0)

  fp = open("font/font.bin", "r")
  pixels = deserialize(fp)
  close(fp)
  (w, h) = size(pixels)
  w = div(w, 4)

  glEnable(GL_BLEND)
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
  glBindTexture(GL_TEXTURE_2D, textureBuffer)
  glBindTexture(GL_TEXTURE_2D, textureBuffer)                                   
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, w, h, 0, GL_RGBA, GL_FLOAT, pixels);

  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);          
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);          
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);            
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);            

  glUniform1i(glGetUniformLocation(context.program, "tex"), 0) 
  # ---------------------------------------------------------------------------

  return context 
end

function test()
  context = setup()

  # Make a Bunch of Test Objects ----------------------------------------------
  # triangle
  position_data = GLfloat[-1.0, 1.0, 
                          -1.0, -1.0, 
                          -0.1, 0.0]
  position = RenderData(position_data, 2, GL_STATIC_DRAW)

  color_data = GLfloat[0.0, 0.0, 1.0, 
                       1.0, 0.0, 0.0, 
                       0.0, 1.0, 0.0]
  color = RenderData(color_data, 3, GL_STATIC_DRAW)
  usetex = RenderData(fill(GLfloat(0), 3), 1, GL_STATIC_DRAW)
  texcoord = RenderData(fill(GLfloat(0), 6), 2, GL_STATIC_DRAW)
  idx = GLuint[0, 1, 2]
  object2 = RenderObject([position, color, usetex, texcoord], idx)


  # road
  th = range(0, stop=(2 * pi), length=30)
  r = 0.6
  x = fill(0.0, length(th))
  y = fill(0.0, length(th))
  for i in 1:length(th)
    x[i] = r * cos(th[i])
    y[i] = r * sin(th[i])
  end
  object3 = make_road(x, y, 0.1)


  # font square
  position_data = GLfloat[-1.0, 0.5,
                          -1.0, 1.0,
                          0.0, 1.0,
                          0.0, 0.5]
  position = RenderData(position_data, 2, GL_STATIC_DRAW)
  color = RenderData(repeat(GLfloat[1.0, 0.0, 0.0], 4), 3, GL_STATIC_DRAW)
  usetex = RenderData(fill(GLfloat(1.0), 4), 1, GL_STATIC_DRAW)
  texcoord_data = GLfloat[0.0, 1.0,
                          0.0, 0.0,
                          1.0, 0.0,
                          1.0, 1.0]
  texcoord = RenderData(texcoord_data, 2, GL_STATIC_DRAW)
  idx = GLuint[0, 1, 2, 
               0, 2, 3]
  object4 = RenderObject([position, color, usetex, texcoord], idx)

  # line
  color = [0.0, 0.0, 0.0]
  l1 = make_line(0.0, 0.0, 0.5, -0.5, color)
  s1 = make_text(string(time_ns()), 0.0, 0.0)

  # Main Render Loop ----------------------------------------------------------
  k = 0
  text = ""

  car1 = make_car()

  println("Set run to false")
  t0 = time_ns() / 1e9
  window_status = true

  k = 0
  t = 0
  while window_status && time_ns() / 1e9 - t0 < 10.0
    println(1e3 * (time_ns() / 1e9 - t))
    t = time_ns() / 1e9
    points = GLfloat[0.0, 0.0, cos(t), sin(t)]
    update_buffer!(l1, points, ATTRIBUTES[1])
    if k == 60
      #text = string(rand(1:100))
      #update_text!(s1, text, 0.0, 0.0)
      car_lights!(car1)
      k = 0
    end
    update_text!(s1, string(time_ns()), 0.0, 0.0)
    car1.T = translate_mat(0, (t - t0) * 0.1)

    k += 1

    window_status = visualize(context, [object2, object3, object4, l1, 
                                        s1, car1])
  end

  if window_status == true
    GLFW.DestroyWindow(context.window)
  end

  #=
  while !GLFW.WindowShouldClose(context.window)
    glClearColor(1.0, 1.0, 1.0, 1.0)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

    render(object2)
    render(object3)
    render(object4)

    t = time_ns() / 1e9
    points = GLfloat[0.0, 0.0, cos(t), sin(t)]
    update_buffer!(l1, points, ATTRIBUTES[1])
    render(l1)

    if k == 60
      #text = string(rand(1:100))
      #update_text!(s1, text, 0.0, 0.0)
      car_lights!(car1)
      k = 0
    end
    update_text!(s1, string(time_ns()), 0.0, 0.0)
    render(s1)

    car1.T = translate_mat(0, (t - t0) * 0.1)
    render(car1)

    k += 1

    GLFW.SwapBuffers(context.window)
    GLFW.PollEvents()
  end
  =#

  # ---------------------------------------------------------------------------

  return
end

function visualize(context::Context, objects::Array{RenderObject})
  if GLFW.WindowShouldClose(context.window)
    GLFW.DestroyWindow(context.window)

    return false
  end

  #=
  while run[] && !GLFW.WindowShouldClose(context.window)
    glClearColor(1.0, 1.0, 1.0, 1.0)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

    for obj in objects
      render(obj)
    end

    GLFW.SwapBuffers(context.window)
    GLFW.PollEvents()
  end
  =#

  glClearColor(1.0, 1.0, 1.0, 1.0)
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

  for obj in objects
    render(obj)
  end

  GLFW.SwapBuffers(context.window)
  GLFW.PollEvents()

  return true
end

#test()

end