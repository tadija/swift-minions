# Minions

**Meet "minions", single-file helpers written in Swift, reusable across multiple projects.**

> - each minion is a single file focused on a certain concept or utility
> - duty of every minion is to provide a simple & flexible way to solve a problem
> - minions are best suited for quick prototyping, learning, or making small apps

## Intro

Here's a simple example:

```swift
import Minions

/// Type which encapsulates current environment info.
struct Env: CustomStringConvertible {

    /// Build configuration and custom config
    @Dependency(\.buildConfig) var buildConfig

    /// A collection of information about current device
    @Dependency(\.device) var device

    /// A mechanism to track current app version state
    @Dependency(\.version) var version
    
    /// String describing custom environment
    var description: String {
        """
        + build config \n\(buildConfig)\n
        + device info \n\(device)\n
        + app version \n\(version)\n
        """
    }

}

logWrite(Env())
```

which would output something like this:

```
+ build config
product name: MyProduct
bundle id: dev.my-product.app
bundle version: 0.1.1
bundle build: 3

+ device info
model: iPhone15,2
kind: iPhone
platform: iOS
os version: 16.2.0
simulator: true

+ app version
version: 0.1.1
history: [0.1.0]
state: update(from: 0.1.0, to: 0.1.1)
```

For more examples, check out other available [Minions](Sources/Minions).

> Hint: in order to use minions (or any other types) with `@Dependency` property wrapper as shown above, you'll need to register them first, as explained in a [Dependencies](Sources/Minions/Dependencies.swift) minion. See also [swift-greenfield](https://github.com/tadija/swift-greenfield) project for more examples of the various minions in use.

---

`#done-for-fun`
