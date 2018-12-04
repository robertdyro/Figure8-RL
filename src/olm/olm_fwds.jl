mutable struct FwdsNode
  x::AbstractArray{Float64, 1}
  r::Float64
  u::AbstractArray{Float64, 1}

  FwdsNode(x) = new(x, 0.0, Float64[])
  FwdsNode() = new(Float64[], 0.0, Float64[])
end

function replan(x::AbstractArray{Float64, 1}, agent::Agent, world::World, 
                reward::Function, ctrl_d::Discretization, depth::Int)
  root = Tree(FwdsNode(x))
  plan = root

  fwds_select_action(x, agent, world, reward, ctrl_d, root, depth)

  return plan
end

function fwds_select_action(x::AbstractArray{Float64, 1}, agent::Agent, 
                            world::World, reward::Function, 
                            ctrl_d::Discretization, node::Tree, depth::Int)
  if depth <= 0
    return 0.0
  end

  max_r = -Inf
  las = -1
  us = Float64[]

  x[1] = mod(x[1], world.road.path.S[end])

  la_len = ctrl_d.thr[end] * ctrl_d.pt[end] # number of actions to survey
  node.next = Array{Tree, 1}(undef, la_len)
  for la in 0:(la_len - 1)
    u = dis.ls2x(ctrl_d, la)
    agent.custom = u
    nx = copy(x)
    sim.advance!(sim.default_dynamics!, nx, Pair(agent, world), 0.0, olm_dt, 
                 olm_h)

    value = FwdsNode(nx)
    node.next[la + 1] = Tree(value)

    next_r = fwds_select_action(nx, agent, world, reward, ctrl_d, 
                                node.next[la + 1], depth - 1)

    r = reward(world, agent, x, u, nx) + olm_gamma * next_r
    if r > max_r
      max_r = r
      las = la
      us = u
    end
  end

  node.value.r = max_r
  node.value.u = us

  return max_r
end

function controller_fwds!(u::AbstractArray{Float64}, 
                          x::AbstractArray{Float64}, 
                          dx::AbstractArray{Float64}, 
                          agent_world::Pair{Agent, World}, t::Float64)
  agent = agent_world.first
  u[1] = agent.custom[1]
  u[2] = agent.custom[2]
end
