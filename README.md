# RedRock

Build Minecraft mods on a Ruby foundation

## Walking skeleton: how to try it

Needs Ruby ≥ 3.2 and a JDK 21 (`JAVA_HOME`).

```sh
# 1. Build the example Ruby mod into a code-free jar
cd gem && bundle install && bundle exec exe/red_rock build ../examples/hello_gem
#    → examples/hello_gem/pkg/hello_gem-0.1.0.jar

# 2. Build the red_rock runtime mod (language loader nested inside, JRuby unpacked in)
cd ../mod && ./gradlew check :runtime:jar
#    → mod/runtime/build/libs/red_rock-0.1.0.jar

# 3. Headless check on a NeoForge 21.1.264 dedicated server, with startup cost
cd .. && scripts/smoke-server.sh
#    → baseline=…s red_rock=…s delta=…s jruby_boot=…ms
```

To see the item in game, put both jars in a NeoForge 21.1.264 client's `mods/` folder. **Ruby Shard**
appears in the creative Ingredients tab.

## Making a mod

```sh
red_rock new boom_cookies                       # a mod with one working item, Ruby Shard
cd boom_cookies
bin/red_rock generate item exploding_cookie     # add an item: file, placeholder texture, test, registration
bin/red_rock build                              # → pkg/boom_cookies-0.1.0.jar
bin/red_rock test                               # run the mod's tests
```

`examples/hello_gem` is exactly what `red_rock new hello_gem` writes; a gem test keeps the two in step.

Working on red_rock itself: `RUBYLIB=$PWD/gem/lib` points a project's `bin/red_rock` at this checkout
instead of an installed gem.

## Tests

Tests: `cd gem && bundle exec rake` (Minitest + RuboCop) and `cd mod && ./gradlew check` (JUnit and the
`checkSeams` rule: no `net.minecraft`/`net.neoforged` imports outside `dev.redrock.adapter`).
