# Cerastes
Less of an engine and more of a toolchain to complete an engine, Cerastes is built on top of [Heaps](http://heaps.io/), to improve development workflows and generally make development a more comfy experience. Internally we often refer to this as "comfy engine", as it's designed entirely around our desired workflows. This means it's comfy *for us*, not necessarily for you; but the hope is that some of these design patterns will inspire you to improve your own workflow, either with our tools or by showing you what you really want to make.

## What does it add?
Heaps by default doesn't contain any built-in tooling. There is [HIDE](https://github.com/HeapsIO/hide), though when I started this project, it was almost entirely undocumented and couldn't figure out what workflows were expected to make it actually function. Additionally, I was fairly unhappy with their model of separating the editor from the game process, as this makes certain types of workflow impossible.

Most of Cerastes uses ImGui. This allows tools to be rapidly produced, and since they operate in-process, we can inspect and edit live data or have tools interact with and/or control the game itself. As an example, right clicking on a flow node and jumping straight to it, which makes script debugging significantly faster.

## What tools are included?
This is not a complete list.
* [Asset Browser](asset_browser.md)
* [Flow Editor](flow_editor.md)
* [UI Editor](ui_editor.md)
* [Atlas Builder](atlas_builder.md)
* [Scene Inspector](inspector.md)

### Should I use this?
No. Cerastes is not developed with external usage in mind, and I make braking changes regularly. You certainly *can* use it, but the optimal workflow is probably to immediately fork it and make it your own.

### How do I get started?
Clone the [Template project](https://github.com/nspitko/CerastesTemplate). You will likely need to use the nightly release of Hashlink, and latest if not nightly haxe.

### I fixed a bug/made it better, do you accept PRs?
*Maybe*. For bug fixes generally yes. For non-breaking improvements to existing tools probably yes. For new features, design changes, or major refactors you should open an issue first and discuss it with me first.
