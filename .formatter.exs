# Used by "mix format"
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  export: [
    locals_without_parens: [
      prop: 1,
      prop: 2,
      state: 1,
      state: 2,
      computed: 1,
      computed: 2
    ]
  ]
]
