# Threema Web Container Compress

An "oneshot" container to download and compress [Threema Web](https://github.com/threema-ch/threema-web) statically with these compression algorithms:
* [gzip](https://en.wikipedia.org/wiki/Gzip) (via [gzipper](https://github.com/gios/gzipper))
* [brotli](https://en.wikipedia.org/wiki/Brotli) (via [gzipper](https://github.com/gios/gzipper))
* [zstd](https://facebook.github.io/zstd/) (via the official CLI client)

Always using the highest and best compression (that does not affect the decompression too badly).
It also downloads Threema Web from the GitHub releases and verifies the GPG signature. It does not rebuilt Threema Web.

After everything is done, the output is written to `/output`. Please use a webserver of your choice (ideally of course one that supports the static file delivery, like [caddy](https://caddyserver.com/docs/caddyfile/directives/file_server)) to serve these files.

## Arguments

* `RELEASE_VERSION` – use `latest` (default) or `tag/vX.Y.Z` to specify the Threema Web version to use.

## Example usage

You should pass the volume `/output` in order to let it save the output files somewhere:
```
mkdir ./output
podman build . -t threema-web-container-compress -v $PWD/output:/output:Z
```

This example uses [`podman`](https://podman.io/), but you can replace the command with `docker` and that should work, too.