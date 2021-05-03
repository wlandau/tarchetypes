targets::tar_test("tar_hook_before() inserts code", {
  targets::tar_script({
    targets <- list(
      list(
        targets::tar_target(x1, task1()),
        targets::tar_target(x2, task2(x1))
      ),
      targets::tar_target(x3, task3(x2)),
      targets::tar_target(y1, task4(x3))
    )
    tarchetypes::tar_hook_before(
      targets = targets,
      hook = print("Running hook."),
      names = NULL
    )
    targets
  })
  out <- targets::tar_manifest(callr_function = NULL)
  expect_equal(sort(out$name), sort(c("x1", "x2", "x3", "y1")))
  expect_true(all(grepl("Running hook", out$command)))
})

targets::tar_test("tar_hook_before() with tidyselect", {
  targets::tar_script({
    targets <- list(
      list(
        targets::tar_target(x1, task1()),
        targets::tar_target(x2, task2(x1))
      ),
      targets::tar_target(x3, task3(x2)),
      targets::tar_target(y1, task4(x3))
    )
    tarchetypes::tar_hook_before(
      targets = targets,
      hook = print("Running hook."),
      names = starts_with("x")
    )
    targets
  })
  out <- targets::tar_manifest(callr_function = NULL)
  expect_equal(sort(out$name), sort(c("x1", "x2", "x3", "y1")))
  expect_equal(
    grepl("Running hook", out$command),
    grepl("^x", out$name)
  )
})

targets::tar_test("tar_hook_before() changes internals properly", {
  x <- targets::tar_target(
    "a",
    b,
    pattern = map(c),
    format = "file",
    resources = list(x = 1)
  )
  y <- targets::tar_target(
    "a",
    b,
    pattern = map(c),
    format = "file",
    resources = list(x = 1)
  )
  for (field in c("packages", "library", "deps", "seed", "string", "hash")) {
    expect_equal(x$command[[field]], y$command[[field]])
  }
  for (field in setdiff(names(x$settings), "pattern")) {
    expect_equal(x$settings[[field]], y$settings[[field]])
  }
  expect_equal(deparse(x$settings$pattern), deparse(y$settings$pattern))
  for (field in names(x$cue)) {
    expect_equal(x$cue[[field]], y$cue[[field]])
  }
  expect_equal(x$store$resources, y$store$resources)
  # Apply the hook.
  tar_hook_before(y, f())
  # Most elements should stay the same
  for (field in c("packages", "library", "seed")) {
    expect_equal(x$command[[field]], y$command[[field]])
  }
  for (field in setdiff(names(x$settings), "pattern")) {
    expect_equal(x$settings[[field]], y$settings[[field]])
  }
  expect_equal(deparse(x$settings$pattern), deparse(y$settings$pattern))
  for (field in names(x$cue)) {
    expect_equal(x$cue[[field]], y$cue[[field]])
  }
  expect_equal(x$store$resources, y$store$resources)
  # Some elements should be different.
  for (field in c("string", "hash")) {
    expect_equal(length(y$command[[field]]), 1L)
    expect_false(x$command[[field]] == y$command[[field]])
  }
  expect_true("b" %in% x$command$deps)
  expect_false("f" %in% x$command$deps)
  expect_true(all(c("b", "f") %in% y$command$deps))
})

targets::tar_test("dep removed when global turns local", {
  x <- targets::tar_target("a", b)
  y <- targets::tar_target("a", b)
  tar_hook_before(y, b <- 1)
  y$command$expr
  expect_true("b" %in% x$command$deps)
  expect_false("b" %in% y$command$deps)
})