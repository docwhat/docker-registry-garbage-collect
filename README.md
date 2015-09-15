# docker-registry-garbage-collect

> The new home page is [docwhat/docker-registry-garbage-collect on
github](https://github.com/docwhat/docker-registry-garbage-collect).

Docker Registery version 1 has one huge glaring problem:  It doesn't clean up
"dangling" or "orphaned" images.

This happens when you push up "foobar:latest" and it clobbers a previous
"foobar:latest".  The images that made up the previous versions are now
orphaned and left floating in limbo.

## Notes

For maximum paranoia, the script will not remove images from the last hour.
This is in case you're uploading something that hasn't been tagged yet.

## License

Public domain.  This stuff is trivial and it is needed.

## Credits

* The [original shell
  script](https://gist.github.com/shepmaster/53939af82a51e3aa0cd6) was done by
  [shepmaster](https://gist.github.com/shepmaster).
* [bjaglin](https://gist.github.com/bjaglin) created a [second version shell
  script](https://gist.github.com/bjaglin/1ff66c20c4bc4d9de522).
* The [final shell script](https://gist.github.com/kwk/c5443f2a1abcf0eb1eaa),
  which I ported here, was by [kwk](https://gist.github.com/kwk).
