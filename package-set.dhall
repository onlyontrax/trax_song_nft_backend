let upstream = https://github.com/dfinity/vessel-package-set/releases/download/mo-0.9.7-20230718/package-set.dhall sha256:e53459a66249ed946a86dc8dd26c4988675f4500d7664c0f962ae661e03080dd
let Package =
    { name : Text, version : Text, repo : Text, dependencies : List Text }

let
  -- This is where you can add your own packages to the package-set
  additions = [
   { name = "stable-hash-map",
       repo = "https://github.com/ZhenyaUsenko/motoko-hash-map",
       version = "v8.0.0", 
       dependencies = ["base"]
   },
   {
    name = "stable-buffer",
    repo = "https://github.com/canscale/StableBuffer",
    version = "v1.2.0",
    dependencies = ["base"]
   }
  ] : List Package

let
  {- This is where you can override existing packages in the package-set

     For example, if you wanted to use version `v2.0.0` of the foo library:
     let overrides = [
         { name = "foo"
         , version = "v2.0.0"
         , repo = "https://github.com/bar/foo"
         , dependencies = [] : List Text
         }
     ]
  -}
  overrides =
    [] : List Package

in  upstream # additions # overrides
