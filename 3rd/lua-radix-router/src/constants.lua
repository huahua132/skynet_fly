--- Constants constants values
--
--

return {
  -- The type of TrieNode
  node_types = {
    literal = 0,
    variable = 1,
    catchall = 2,
  },
  node_indexs = {
    type = 1,
    path = 2,
    pathn = 3,
    children = 4,
    value = 5,
  },
  -- The type of token
  token_types = {
    literal = 0,
    variable = 1,
    catchall = 2,
  },
}
