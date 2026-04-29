std = "max"
self = false
ignore = {"[Tt]est[%w_]+"}

files = {
    ["test/*.lua"] = {
        ignore = {"EXPORT_ASSERT_TO_GLOBALS", "assert[%w_]+", "v", "y"}
    },
}

