# RubyNDS
Write DSi/DS Homebrew apps in pure Ruby!

<img width="235" height="360" alt="video" src="https://github.com/user-attachments/assets/0fa1c674-4b7e-43a6-96b7-38bbc3ca556a" />

## What's the purpose?
I wanted to write homebrew apps for DSi using a favorable language. And since I don't really know C, I wanted to avoid having an LLM create an entire framework for me. Not only is that pretty lame, but I learn nothing in the process as the majority of the hard work is done.

So the goal is to have the C side of this project be as thin as possible. Not only does this make the inner workings more legible for me, but it also ensures practically all of the logic is pure self-written Ruby (excluding the [pre-existing mrbgems](./gems/) of course). 

This is only possible thanks to all of the DS native libraries and SDK components available like [libnds](https://github.com/devkitPro/libnds), [DSWiFi](https://github.com/devkitPro/dswifi), [Maxmod](https://github.com/devkitPro/maxmod). And obviously [devkitPro](https://github.com/devkitPro) for even providing the cross-compilation tools and whatnot in the first place.
