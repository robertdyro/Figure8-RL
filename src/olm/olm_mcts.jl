mutable struct MctsNode
  ls::Int
  x::AbstractArray{Float64, 1}
  la::Int
  u::AbstractArray{Float64, 1}
  q::Float64
  N::Int

  MctsNode() = new(-1, Float64[], -1, Float64[], 0.0, 1)
  MctsNode(ls, x, la, u, r) = new(ls, x, la, u, r, 1)
end

function plan_mcts(x::AbstractArray{Float64, 1}, agent::Agent, world::World, 
                   reward::Function, state_d::Discretization, 
                   ctrl_d::Discretization, depth::Int)
  x = copy(x)
  x[1] = mod(x[1], world.road.path.S[end])
  dis.clamp_x!(state_d, x)
  ls = dis.x2ls(state_d, x)
  x = copy(x)
  value = MctsNode()
  value.ls = ls
  value.x = x
  node = Tree(value)

  visited = Set{MctsNode}()
  for i in 1:10^4
    simulate_mcts(agent, world, reward, 
                  state_d, ctrl_d, 
                  visited, node, depth)
  end
  
  us = Float64[]
  qs = -Inf
  for a in 1:length(node.next)
    if node.next[a].value.q > qs
      qs = node.next[a].value.q
      us = node.next[a].value.u
    end
  end

  return us
end

function simulate_mcts(agent::Agent, world::World, reward::Function, 
                       state_d::Discretization, ctrl_d::Discretization, 
                       visited::Set{MctsNode}, node::Tree, depth::Int)
  if depth <= 0
    return 0.0
  end

  if !(node.value in visited)
    push!(visited, node.value)

    la_len = ctrl_d.thr[end] * ctrl_d.pt[end] # number of actions to survey
    node.next = Array{Tree, 1}(undef, la_len)
    for la in 0:(la_len - 1)
      u = dis.ls2x(ctrl_d, la)
      agent.custom = u
      nx = copy(node.value.x)
      sim.advance!(sim.default_dynamics!, nx, Pair(agent, world), 0.0, olm_dt, 
                   olm_h)
      nx[1] = mod(nx[1], world.road.path.S[end])
      dis.clamp_x!(state_d, nx)
      nls = dis.x2ls(state_d, nx)

      r = reward(node.value.x, u, nx, agent, world)

      value = MctsNode(nls, nx, la, u, r)
      node.next[la + 1] = Tree(value)
    end

    return rollout(node.value.x, agent, world, reward, ctrl_d, depth)
  end

  # find the best action for value and exploration
  as = -1
  vs = -Inf
  for a in 1:length(node.next)
    v = node.next[a].value.q + olm_mcts_c * sqrt(log(node.value.N) / 
                                                 node.next[a].value.N)
    if v > vs
      vs = v
      as = a
    end
  end

  las = node.next[as].value.la
  q = simulate_mcts(agent, world, reward, state_d, ctrl_d, visited, 
                    node.next[as], depth - 1)
  node.next[as].value.N += 1
  node.next[as].value.q -= (q - node.next[as].value.q) / node.next[as].value.N

  return q
end

function rollout(x::AbstractArray{Float64, 1}, agent::Agent, 
                 world::World, reward::Function, 
                 ctrl_d::Discretization, depth::Int)
  if depth <= 0
    return 0.0
  end

  # choose middle action, generally reasonable
  ad = fill(0, ctrl_d.dim)
  for i in 1:length(ad)
    ad[i] = div(ctrl_d.pt[i], 2)
  end
  u = dis.xd2x(ctrl_d, ad)
  agent.custom = u
  nx = copy(x)
  sim.advance!(sim.default_dynamics!, nx, Pair(agent, world), 0.0, olm_dt, 
               olm_h)
  q = reward(x, u, nx, agent, world)

  return q + olm_gamma * rollout(nx, agent, world, reward, ctrl_d, depth - 1)
end

function controller_mcts!(u::AbstractArray{Float64}, 
                          x::AbstractArray{Float64}, 
                          dx::AbstractArray{Float64}, 
                          agent_world::Pair{Agent, World}, t::Float64)
  agent = agent_world.first
  u[1] = agent.custom[1]
  u[2] = agent.custom[2]
end