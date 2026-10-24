# RedRock

Build Minecraft mods on a Ruby foundation

## Walking skeleton: how to try it

Needs Ruby ≥ 3.2 and a JDK 21 (`JAVA_HOME`).

```sh
# 1. Build the example Ruby mod into a code-free jar
cd gem && bundle install && bundle exec exe/gemcrafter build ../examples/hello_gem
#    → examples/hello_gem/pkg/hello_gem-0.1.0.jar

# 2. Build the gemcrafter runtime mod (language loader + JRuby nested inside)
cd ../mod && ./gradlew check :runtime:jar
#    → mod/runtime/build/libs/gemcrafter-0.1.0.jar

# 3. Headless check on a NeoForge 21.1.264 dedicated server, with startup cost
cd .. && scripts/smoke-server.sh
#    → baseline=…s gemcrafter=…s delta=…s jruby_boot=…ms
```

To see the item in game, put both jars in a NeoForge 21.1.264 client's `mods/` folder. **Ruby Shard**
appears in the creative Ingredients tab.

Tests: `cd gem && bundle exec rake` (Minitest + RuboCop) and `cd mod && ./gradlew check` (JUnit and the
`checkSeams` rule: no `net.minecraft`/`net.neoforged` imports outside `dev.gemcrafter.adapter`).
