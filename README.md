### grapheneos-recipe

This is a GrapheneOS recipe for [ham](https://github.com/antony-jr/ham).

It can be used to build a GrapheneOS image on [Hetzner Cloud](https://www.hetzner.com/cloud/) (for cheap, without owned servers), and upload it to a Cloudflare R2 bucket for OTA consumption by client devices. This is probably a lot less secure than just using the upstream OS, and only provides a few benefits.

I am running this with a simple bash script that checks if the current upstream version is still the same as in my R2 bucket, if not, it runs the build server which uploads it for next time my devices or script checks it.

It is mostly uploaded publicly to GitHub, so I can easily access it without authentication, so don't expect any type of support or updates.
