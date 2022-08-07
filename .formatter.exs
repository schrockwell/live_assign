# Used by "mix format"
[
  import_deps: [:phoenix_live_view],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: [
    prop: 1,
    prop: 2,
    state: 1,
    state: 2,
    computed: 1,
    slot: 1,
    slot: 2,
    event: 1
  ],
  export: [
    locals_without_parens: [
      prop: 1,
      prop: 2,
      state: 1,
      state: 2,
      computed: 1,
      slot: 1,
      slot: 2,
      event: 1
    ]
  ]
]
