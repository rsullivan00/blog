---
layout: post
title:  "Windows `pushd` on network paths"
date:   2017-08-10 21:53:36 -0700
categories: windows pushd popd unc network *nix
---

The `pushd`/`popd` commands in Windows batch or Powershell can be used to move
around the directory stack, like in *nix systems:

```
C:\Windows> pushd .\Users\Bob
C:\Windows\Users\Bob> popd
C:\Windows> 
```

It supports moving into UNC network paths, and will automatically assign them
a drive letter, starting from `Z:` backwards.

```
C:\Windows> pushd \\myhost\networkfolder
Z:\+> echo "I'm on a network mapped drive!"
```

**However**, running out of drive letters will lead to the cryptic error

```
C:\Windows> pushd \\anotherhost\ponies
CMD does not support UNC paths as current directories
```

So don't forget to run `popd` after you are done with your tasks on your 23 
network drives--it will free the drive letter that was allocated by `pushd`.
